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

/// A short banner shown in the strip under the score, away from the falling word.
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
    /// The answer to the word that was just missed, shown at the danger line.
    private(set) var revealedWord: String?
    /// The game-over screen appears a moment after the game ends, so the
    /// player can see the final word they missed.
    private(set) var showGameOver = false
    /// "Out of lives: watch an ad for an extra heart?" is on screen.
    private(set) var showExtraHeartOffer = false
    /// A rewarded or interstitial ad is on screen.
    private(set) var isShowingAd = false
    private(set) var recorded: RecordedGame?

    @ObservationIgnored private let services: AppServices
    @ObservationIgnored private var displayLink: DisplayLink?
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var bannerTask: Task<Void, Never>?
    @ObservationIgnored private var demoTask: Task<Void, Never>?

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
            startRun()
        }
        startClock()
        #if DEBUG
        if DemoMode.autoplay, demoTask == nil {
            demoTask = Task { [weak self] in
                guard let self else { return }
                await DemoMode.play(self)
            }
        }
        #endif
    }

    func end() {
        // A full-screen ad over the game also triggers onDisappear; the game isn't over.
        guard !isShowingAd else { return }
        stopClock()
        bannerTask?.cancel()
        demoTask?.cancel()
        demoTask = nil
        // Leaving while the extra-heart offer is up still counts the game.
        if engine.status == .gameOver {
            recordIfNeeded()
        }
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

    /// The game-over screen can offer Play Again: always in endless, and for
    /// the daily only in development builds.
    var canPlayAgain: Bool { !isDaily || DevOptions.allowsDailyReplay }

    /// Starts a fresh game with the same settings on the same screen.
    func playAgain() {
        guard canPlayAgain else { return }
        if case .daily(let challenge) = configuration.mode, let modelContext {
            DevOptions.forgetDailyResult(dateKey: challenge.dateKey, in: modelContext)
        }
        engine.onEvent = nil
        engine = GameEngine(database: services.database, configuration: configuration)
        attach(engine)
        bursts = []
        banner = nil
        recorded = nil
        missFlash = false
        revealedWord = nil
        showGameOver = false
        showExtraHeartOffer = false
        startRun()
        startClock()
    }

    private func startRun() {
        services.adPolicy.gameStarted(isDaily: isDaily)
        services.ads.preload()
        Analytics.log(.gameStarted, ["mode": isDaily ? "daily" : "endless", "difficulty": engine.difficulty.rawValue])
        engine.start()
    }

    // MARK: Leaving the results

    /// Runs `action` (home or play again), first showing an interstitial if
    /// the ad policy allows one and it's loaded.
    func leaveResults(then action: @escaping () -> Void) {
        guard !isShowingAd else { return }
        let policy = services.adPolicy
        guard policy.shouldShowInterstitial(), services.ads.isInterstitialReady else {
            action()
            return
        }
        Analytics.log(.interstitialAvailable)
        isShowingAd = true
        services.sound.isEnabled = false
        services.ads.showInterstitial { [weak self] shown in
            guard let self else { return }
            self.isShowingAd = false
            self.services.sound.isEnabled = self.services.settings.soundEnabled
            if shown {
                policy.interstitialShown()
                Analytics.log(.interstitialShown)
            } else {
                Analytics.log(.interstitialFailed)
            }
            action()
        }
    }

    // MARK: Extra heart

    /// Out of lives: an extra heart is offered only if the rules allow one
    /// and an ad is already loaded, so the player never waits for an ad.
    private var canOfferExtraHeart: Bool {
        engine.canGrantExtraHeart && services.adPolicy.canUseRewardedForExtraLife && services.ads.isRewardedAdReady
    }

    /// Plays the rewarded ad; if it's watched to the end, play resumes with one heart.
    func watchAdForExtraHeart() {
        guard showExtraHeartOffer, !isShowingAd else { return }
        Analytics.log(.rewardedAdStarted)
        isShowingAd = true
        services.sound.isEnabled = false
        services.ads.showRewarded { [weak self] outcome in
            guard let self else { return }
            self.isShowingAd = false
            self.services.sound.isEnabled = self.services.settings.soundEnabled
            if outcome != .failed {
                self.services.adPolicy.rewardedAdShown()
            }
            switch outcome {
            case .earned:
                Analytics.log(.rewardedAdCompleted)
                guard self.engine.grantExtraHeart() else { return self.finishWithResults() }
                Analytics.log(.rewardedExtraLifeGranted)
                self.showExtraHeartOffer = false
                self.startClock()
            case .closedEarly:
                self.finishWithResults()
            case .failed:
                Analytics.log(.rewardedAdFailed)
                self.finishWithResults()
            }
        }
    }

    /// Turns the offer down and shows the normal game-over screen.
    func declineExtraHeart() {
        guard showExtraHeartOffer, !isShowingAd else { return }
        finishWithResults()
    }

    private func finishWithResults() {
        showExtraHeartOffer = false
        revealedWord = nil
        recordIfNeeded()
        showGameOver = true
    }

    /// The run is over for good: save it once, and count it for the ad policy.
    private func recordIfNeeded() {
        guard let modelContext, recorded == nil else { return }
        recorded = StatsRecorder.record(engine, in: modelContext)
        services.adPolicy.gameEnded()
        let finishedDaily = isDaily && engine.lives > 0
        Analytics.log(finishedDaily ? .gameCompleted : .gameOver, ["score": "\(engine.score)"])
        if services.adPolicy.rewardedAdsUsedThisRun > 0 {
            Analytics.log(.gameOverAfterRewarded, ["score": "\(engine.score)"])
        }
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

    // MARK: Events → feedback

    private func handle(_ event: GameEvent) {
        let haptics = services.haptics
        let sound = services.sound
        switch event {
        case .started:
            break

        case .spawned:
            revealedWord = nil

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
            revealedWord = word
            show(Banner(text: "✕ MISS", style: .miss))
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
            let endedOnMiss = engine.history.last?.outcome == .missed
            let engineAtEnd = engine
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(endedOnMiss ? 2000 : 700))
                guard let self, self.engine === engineAtEnd, self.engine.status == .gameOver else { return }
                if self.canOfferExtraHeart {
                    Analytics.log(.rewardedAdAvailable)
                    self.revealedWord = nil
                    self.showExtraHeartOffer = true
                } else {
                    self.finishWithResults()
                }
            }

        case .extraHeart:
            revealedWord = nil
            sound.play(.levelUp)
            haptics.milestone()
            show(Banner(text: "+1 ❤️  KEEP GOING", style: .level))
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
