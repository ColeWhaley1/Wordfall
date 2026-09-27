import Foundation

/// The player's chosen difficulty for endless mode. Daily puzzles pick their
/// own difficulty from the date instead (see `DailyChallengeGenerator`).
///
/// Easier modes give more time and friendlier words but pay far fewer points,
/// so a high score (and the coins it earns) always means a harder game.
enum GameDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy
    case normal
    case hard
    case expert

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: "EASY"
        case .normal: "NORMAL"
        case .hard: "HARD"
        case .expert: "EXPERT"
        }
    }

    var summary: String {
        switch self {
        case .easy: "Lots of time, everyday words up to 6 letters"
        case .normal: "The standard climb"
        case .hard: "Longer words from the start, less time"
        case .expert: "Rare, long words and very little time"
        }
    }

    /// Multiplier on every fall time. Above 1 means more time.
    var timeScale: Double {
        switch self {
        case .easy: 1.45
        case .normal: 1.0
        case .hard: 0.82
        case .expert: 0.68
        }
    }

    /// How quickly the fall speed ramps up per level, relative to normal.
    var rampScale: Double {
        switch self {
        case .easy: 0.6
        case .normal: 1.0
        case .hard: 1.15
        case .expert: 1.3
        }
    }

    /// Words are picked as if the player were this many levels further on.
    var wordLevelOffset: Int {
        switch self {
        case .easy, .normal: 0
        case .hard: 3
        case .expert: 6
        }
    }

    /// Longest word this difficulty will drop.
    var maxLength: Int {
        self == .easy ? 6 : 9
    }

    /// Multiplier on every solve's points.
    var pointsMultiplier: Double {
        switch self {
        case .easy: 0.35
        case .normal: 1.0
        case .hard: 1.6
        case .expert: 2.4
        }
    }

    var pointsLabel: String {
        pointsMultiplier == pointsMultiplier.rounded()
            ? "×\(Int(pointsMultiplier)) pts"
            : String(format: "×%.2g pts", pointsMultiplier)
    }
}
