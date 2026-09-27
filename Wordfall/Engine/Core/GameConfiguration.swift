import Foundation

enum GameMode: Equatable, Sendable {
    case endless
    case daily(DailyChallenge)

    var isDaily: Bool {
        if case .daily = self { return true }
        return false
    }
}

enum GameStatus: Equatable, Sendable {
    case ready
    case playing
    case paused
    case gameOver
}

struct GameConfiguration: Equatable, Sendable {
    var mode: GameMode = .endless
    var startingLives = 3
    /// Pause after a solve before the next word spawns; covers the burst animation.
    var delayAfterSolve: TimeInterval = 0.35
    /// Pause after a miss, long enough to register the crash.
    var delayAfterMiss: TimeInterval = 0.7
    /// Pause before the very first word.
    var initialDelay: TimeInterval = 0.6
    /// Progress at which the word enters the danger zone.
    var dangerThreshold = 0.75

    static let endless = GameConfiguration()

    static func daily(_ challenge: DailyChallenge) -> GameConfiguration {
        GameConfiguration(mode: .daily(challenge), startingLives: challenge.lives)
    }
}
