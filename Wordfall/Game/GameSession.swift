import Foundation
import Observation
import SwiftData

/// A solved word's burst animation, shown where the word was.
struct SolveBurst: Identifiable, Equatable {
    let id = UUID()
    let word: String
    let points: Int
    let combo: Int
    let isPerfect: Bool
    /// Fall progress when solved, to place the burst.
    let progress: Double
}

/// A short banner in the middle of the board.
struct Banner: Identifiable, Equatable {
    enum Style { case milestone, level, perfect, miss }
    let id = UUID()
    let text: String
    let style: Style
}

/// Connects one game to the screen: runs the clock, turns engine events into
/// sound, haptics and animations, and saves the result at the end.
@MainActor
@Observable
final class GameSession {
    private(set) var engine: GameEngine
    let configuration: GameConfiguration

    private(set) var bursts: [SolveBurst] = []
    private(set) var banner: Banner?
    /// Incremented to shake the whole board (miss).
    private(set) var boardShake = 0
    /// Incremented to shake the answer area (wrong answer).
    private(set) var answerShake = 0
    /// Incremented on every selection, for small tile pops.
    private(set) var selectionPulse = 0
    private(set) var missFlash = false
    private(set) var recorded: RecordedGame?

    @ObservationIgnored private let services: AppServices
    @ObservationIgnored private var displayLink: DisplayLink?
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?

    init(configuration: GameConfiguration, services: AppServices) {
        self.configuration = configuration
        self.services = services
        self.engine = GameEngine(database: services.database, configuration: configuration)
        attach(engine)
    }

    var isDaily: Bool { configuration.mode.isDaily }

    // MARK: Lifecycle

    func begin(modelContext: ModelContext) {
        self.modelContext = modelContext
        services.haptics.isEnabled = services.settings.hapticsEnabled
        services.sound.isEnabled = services.settings.soundEnabled
        services.haptics.prepare()
        if engine.status == .ready {
            engine.start()
        }
        startClock()
    }

    func end() {
        stopClock()
        bannerTask?.cancel()
    }

    func pause() {
        engine.pause()
    }

    func resume() {
        engine.resume()
    }

    func togglePause() {
        engine.status == .paused ? resume() : pause()
    }

    /// Starts a fresh endless game on the same screen.
    func playAgain() {
        guard !isDaily else { return }
        engine.onEvent = nil
        engine = GameEngine(database: services.database, configuration: configuration)
        attach(engine)
        bursts = []
        banner = nil
        recorded = nil
        missFlash = false
        engine.start()
        startClock()
    }

    private func attach(_ engine: GameEngine) {
        engine.onEvent = { [weak self] event in
            self?.handle(event)
        }
    }

    private func startClock() {
        guard displayLink == nil else { return }
        let link = DisplayLink { [weak self] delta in
            self?.engine.tick(delta)
        }
        displayLink = link
        link.start()
    }

    private func stopClock() {
        displayLink?.stop()
        displayLink = nil
    }

    // MARK: Input

    func type(_ text: String) {
        for character in text where character.isLetter {
            engine.type(character)
        }
    }

    func deleteBackward() {
        engine.deleteLast()
    }

    // MARK: Events → feedback

    private func handle(_ event: GameEvent) {
        let haptics = services.haptics
        let sound = services.sound
        switch event {
        case .started, .spawned:
            break

        case .letterSelected:
            selectionPulse += 1
            haptics.letterSelected()
            sound.tick(step: engine.selection.count - 1)

        case .letterRemoved:
            haptics.letterRemoved()

        case .rejected:
            answerShake += 1
            haptics.rejected()
            sound.play(.buzz)

        case .invalidKey:
            answerShake += 1
            sound.play(.buzz)

        case .solved(let result):
            let progress = result.fraction
            bursts.append(SolveBurst(word: result.answer, points: result.points, combo: result.combo, isPerfect: result.isPerfect, progress: progress))
            let id = bursts.last?.id
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(900))
                self?.bursts.removeAll { $0.id == id }
            }
            haptics.solved(length: result.word.count)
            sound.play(.pop)
            if let milestone = result.milestone {
                haptics.milestone()
                sound.play(.rise)
                show(Banner(text: milestone.title, style: .milestone))
            } else if result.isPerfect {
                if result.word.count >= 6 { sound.play(.chime) }
                show(Banner(text: "PERFECT", style: .perfect))
            } else if result.word.count >= 7 {
                sound.play(.chime)
            }

        case .dangerEntered:
            haptics.danger()
            sound.play(.warning)

        case .missed(let word):
            boardShake += 1
            haptics.missed()
            sound.play(.thud)
            show(Banner(text: "✕ MISS · \(word)", style: .miss))
            missFlash = true
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                self?.missFlash = false
            }

        case .levelUp(let level):
            sound.play(.levelUp)
            show(Banner(text: "LEVEL \(level)", style: .level))

        case .gameOver:
            stopClock()
            haptics.missed()
            if let modelContext, recorded == nil {
                recorded = StatsRecorder.record(engine, in: modelContext)
            }
        }
    }

    private func show(_ banner: Banner) {
        self.banner = banner
        bannerTask?.cancel()
        bannerTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            self?.banner = nil
        }
    }
}
