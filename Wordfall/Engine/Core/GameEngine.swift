import Foundation
import Observation

/// Runs one game: spawning, falling, input, validation, scoring, lives and
/// game over. It never touches SwiftUI; views observe its state and react to
/// the events it emits.
///
/// The engine doesn't own a clock. The app calls `tick(_:)` with elapsed time
/// every frame, which keeps the logic frame-rate independent and testable.
@Observable
final class GameEngine {
    // MARK: Observed state

    private(set) var status: GameStatus = .ready
    private(set) var score = 0
    private(set) var level = 1
    private(set) var lives: Int
    private(set) var activeWord: FallingWord?
    private(set) var selection = LetterSelection()
    private(set) var wordsSolved = 0
    private(set) var wordsMissed = 0
    private(set) var elapsedTime: TimeInterval = 0
    private(set) var lastSolve: SolveResult?
    /// Every word played so far, in order.
    private(set) var history: [WordRecord] = []
    private(set) var solveTimes: [TimeInterval] = []
    private(set) var longestWord = ""
    private(set) var perfectCount = 0
    private(set) var inputCounts: [InputMethod: Int] = [:]

    var outcomes: [WordOutcome] { history.map(\.outcome) }
    var combo: Int { comboEngine.count }
    var bestCombo: Int { comboEngine.best }
    var mode: GameMode { configuration.mode }

    /// Letters currently spelled, in order.
    var currentInput: String {
        guard let activeWord else { return "" }
        return selection.text(in: activeWord.tiles)
    }

    var averageSolveTime: TimeInterval? {
        solveTimes.isEmpty ? nil : solveTimes.reduce(0, +) / Double(solveTimes.count)
    }

    /// Words in the daily challenge that have been played (solved or missed).
    var dailyProgress: (played: Int, total: Int)? {
        guard case .daily(let challenge) = configuration.mode else { return nil }
        return (history.count, challenge.words.count)
    }

    // MARK: Collaborators

    let configuration: GameConfiguration
    @ObservationIgnored let database: WordDatabase
    @ObservationIgnored private let validator: WordValidator
    @ObservationIgnored private var generator: WordGenerator
    @ObservationIgnored private var rng: SeededRandom
    @ObservationIgnored private var comboEngine = ComboEngine()
    @ObservationIgnored private var spawnCountdown: TimeInterval = 0
    @ObservationIgnored private var dangerAnnounced = false
    @ObservationIgnored private var lastInputMethod: InputMethod?
    @ObservationIgnored private var dailyIndex = 0

    /// Called synchronously for every event. Set by the UI layer.
    @ObservationIgnored var onEvent: ((GameEvent) -> Void)?

    init(database: WordDatabase, configuration: GameConfiguration = .endless, seed: UInt64? = nil) {
        self.database = database
        self.configuration = configuration
        self.validator = WordValidator(database: database)
        self.generator = WordGenerator(database: database)
        self.rng = SeededRandom(seed: seed ?? UInt64.random(in: .min ... .max))
        self.lives = configuration.startingLives
    }

    // MARK: Lifecycle

    func start() {
        guard status == .ready else { return }
        status = .playing
        spawnCountdown = configuration.initialDelay
        emit(.started)
    }

    func pause() {
        guard status == .playing else { return }
        status = .paused
    }

    func resume() {
        guard status == .paused else { return }
        status = .playing
    }

    /// Advances the game by `deltaTime` seconds.
    func tick(_ deltaTime: TimeInterval) {
        guard status == .playing, deltaTime > 0 else { return }
        // Clamp huge gaps (app backgrounded, debugger) so a word can't teleport.
        let dt = min(deltaTime, 0.25)
        elapsedTime += dt

        if var word = activeWord {
            word.elapsed += dt
            activeWord = word
            if !dangerAnnounced, word.progress >= configuration.dangerThreshold {
                dangerAnnounced = true
                emit(.dangerEntered)
            }
            if word.elapsed >= word.fallDuration {
                miss()
            }
        } else {
            spawnCountdown -= dt
            if spawnCountdown <= 0 {
                spawnNext()
            }
        }
    }

    // MARK: Input

    /// Keyboard input: picks the first free tile showing that letter.
    @discardableResult
    func type(_ character: Character) -> Bool {
        guard status == .playing, let word = activeWord else { return false }
        let letter = Character(character.uppercased())
        guard let tile = word.tiles.first(where: { $0.letter == letter && !selection.contains($0.id) }) else {
            emit(.invalidKey(letter))
            return false
        }
        return select(tileID: tile.id, via: .keyboard)
    }

    /// Adds a tile to the answer. Used by keyboard, tap and swipe alike.
    @discardableResult
    func select(tileID: Int, via method: InputMethod) -> Bool {
        guard status == .playing, let word = activeWord,
              let tile = word.tiles.first(where: { $0.id == tileID }),
              !selection.contains(tileID)
        else { return false }
        selection.append(tileID)
        lastInputMethod = method
        inputCounts[method, default: 0] += 1
        emit(.letterSelected(tile, method))
        evaluateSelection()
        return true
    }

    /// Tapping a tile toggles it: free tiles are added, selected tiles removed.
    func toggle(tileID: Int) {
        if selection.contains(tileID) {
            deselect(tileID: tileID)
        } else {
            select(tileID: tileID, via: .tap)
        }
    }

    /// Removes one tile from the answer, e.g. when a swipe backtracks.
    func deselect(tileID: Int) {
        guard status == .playing, selection.contains(tileID) else { return }
        selection.remove(tileID)
        emit(.letterRemoved)
    }

    func deleteLast() {
        guard status == .playing, selection.removeLast() != nil else { return }
        emit(.letterRemoved)
    }

    func clearSelection() {
        guard !selection.isEmpty else { return }
        selection.removeAll()
        emit(.letterRemoved)
    }

    // MARK: Rules

    private func evaluateSelection() {
        guard let word = activeWord, selection.count == word.tiles.count else { return }
        let answer = selection.text(in: word.tiles)
        if validator.isCorrect(answer, for: word.word) {
            solve(word, answer: answer)
        } else {
            selection.removeAll()
            emit(.rejected(answer))
        }
    }

    private func solve(_ word: FallingWord, answer: String) {
        let milestone = comboEngine.registerSolve()
        let fraction = word.progress
        let breakdown = ScoreEngine.score(length: word.word.count, fraction: fraction, combo: comboEngine.count, level: level)
        let result = SolveResult(
            word: word.word,
            answer: answer,
            score: breakdown,
            combo: comboEngine.count,
            milestone: milestone,
            solveTime: word.elapsed,
            fraction: fraction,
            lastMethod: lastInputMethod
        )

        score += breakdown.total
        wordsSolved += 1
        solveTimes.append(word.elapsed)
        history.append(WordRecord(id: word.id, word: word.word, answer: answer, outcome: breakdown.isPerfect ? .perfect : .solved, points: breakdown.total, time: word.elapsed))
        if breakdown.isPerfect { perfectCount += 1 }
        if answer.count > longestWord.count { longestWord = answer }
        lastSolve = result

        activeWord = nil
        selection.removeAll()
        emit(.solved(result))

        if !mode.isDaily {
            let newLevel = DifficultyService.level(forWordsSolved: wordsSolved)
            if newLevel > level {
                level = newLevel
                emit(.levelUp(newLevel))
            }
        }
        scheduleNext(after: configuration.delayAfterSolve)
    }

    private func miss() {
        guard let word = activeWord else { return }
        activeWord = nil
        selection.removeAll()
        comboEngine.reset()
        lives -= 1
        wordsMissed += 1
        history.append(WordRecord(id: word.id, word: word.word, answer: nil, outcome: .missed, points: 0, time: word.elapsed))
        emit(.missed(word.word))

        if lives <= 0 {
            endGame()
        } else {
            scheduleNext(after: configuration.delayAfterMiss)
        }
    }

    private func scheduleNext(after delay: TimeInterval) {
        if case .daily(let challenge) = mode, dailyIndex >= challenge.words.count {
            endGame()
            return
        }
        spawnCountdown = delay
    }

    private func spawnNext() {
        let word: FallingWord
        switch mode {
        case .endless:
            let profile = DifficultyService.profile(for: level)
            let entry = generator.nextWord(for: profile, using: &rng)
            let scrambled = WordGenerator.scramble(entry.text, database: database, using: &rng)
            word = FallingWord(word: entry.text, scrambled: scrambled, fallDuration: profile.fallDuration(forLength: entry.length))
        case .daily(let challenge):
            guard dailyIndex < challenge.words.count else {
                endGame()
                return
            }
            let daily = challenge.words[dailyIndex]
            dailyIndex += 1
            word = FallingWord(word: daily.word, scrambled: daily.scrambled, fallDuration: challenge.fallDuration(forWordAt: dailyIndex - 1))
        }
        activeWord = word
        selection.removeAll()
        dangerAnnounced = false
        lastInputMethod = nil
        emit(.spawned(word))
    }

    private func endGame() {
        guard status != .gameOver else { return }
        activeWord = nil
        status = .gameOver
        emit(.gameOver)
    }

    private func emit(_ event: GameEvent) {
        onEvent?(event)
    }
}
