import Foundation

/// How the points for one solved word were made up.
struct ScoreBreakdown: Equatable, Sendable {
    let base: Int
    let speedMultiplier: Double
    let comboMultiplier: Double
    let levelMultiplier: Double
    let difficultyMultiplier: Double
    let isPerfect: Bool
    let total: Int
}

/// Every scoring rule lives here so the numbers can be tuned in one place.
enum ScoreEngine {
    /// Solving before this fraction of the fall counts as PERFECT.
    static let perfectThreshold = 0.4
    static let perfectBonus = 1.25

    /// Longer words are worth substantially more.
    static func baseScore(length: Int) -> Int {
        switch length {
        case ..<3: return 20
        case 3: return 30
        case 4: return 50
        case 5: return 80
        case 6: return 120
        case 7: return 180
        case 8: return 260
        case 9: return 350
        default: return 350 + (length - 9) * 100
        }
    }

    /// Rewards solving quickly. `fraction` is how far the word had fallen (0...1).
    static func speedMultiplier(fraction: Double) -> Double {
        switch fraction {
        case ..<0.15: return 2.0
        case ..<0.3: return 1.6
        case ..<0.5: return 1.3
        case ..<0.75: return 1.1
        default: return 1.0
        }
    }

    /// 1× for the first word, +0.2× per consecutive word, capped at 3×.
    static func comboMultiplier(combo: Int) -> Double {
        1.0 + Double(min(max(combo, 1), 11) - 1) * 0.2
    }

    static func levelMultiplier(level: Int) -> Double {
        min(3.0, 1.0 + Double(max(level, 1) - 1) * 0.05)
    }

    static func isPerfect(fraction: Double) -> Bool {
        fraction < perfectThreshold
    }

    /// - Parameter combo: the combo count including this word.
    static func score(length: Int, fraction: Double, combo: Int, level: Int, difficulty: GameDifficulty = .normal) -> ScoreBreakdown {
        let base = baseScore(length: length)
        let speed = speedMultiplier(fraction: fraction)
        let comboMultiplier = comboMultiplier(combo: combo)
        let levelMultiplier = levelMultiplier(level: level)
        let perfect = isPerfect(fraction: fraction)
        var total = Double(base) * speed * comboMultiplier * levelMultiplier * difficulty.pointsMultiplier
        if perfect { total *= perfectBonus }
        return ScoreBreakdown(
            base: base,
            speedMultiplier: speed,
            comboMultiplier: comboMultiplier,
            levelMultiplier: levelMultiplier,
            difficultyMultiplier: difficulty.pointsMultiplier,
            isPerfect: perfect,
            total: Int(total.rounded())
        )
    }
}
