import Foundation

/// Everything that changes as the player levels up, in one place so the curve
/// can be tuned by playtesting.
struct DifficultyProfile: Equatable, Sendable {
    let level: Int
    /// Allowed word lengths.
    let lengths: ClosedRange<Int>
    /// Preferred maximum word difficulty (1...5). Relaxed if nothing matches.
    let maxDifficulty: Int
    /// Minimum normalised frequency; keeps less familiar words out of early levels.
    let minFrequency: Double
    /// Multiplier on every fall time: 1 at level 1, smaller (faster) later.
    let speed: Double
    /// The chosen difficulty's multiplier on fall time (see `GameDifficulty`).
    var timeScale: Double = 1
    /// Words on screen at once. Always 1 in v1; multi-lane play comes later.
    let maxActiveWords: Int

    /// Seconds a word of this length takes to reach the danger line.
    func fallDuration(forLength length: Int) -> TimeInterval {
        DifficultyService.fallDuration(length: length, speed: speed, timeScale: timeScale)
    }
}

enum DifficultyService {
    /// Correct words needed to advance one level.
    static let wordsPerLevel = 5

    /// Fall time = ((base + perLetter × length) × speed + thinking time) × timeScale.
    ///
    /// Unscrambling gets much harder with every extra letter, so words longer
    /// than 3 letters also get "thinking time" that grows faster than their
    /// length and is never sped up by levelling. At level 1 a 3-letter word
    /// falls in 6.5s, a 6-letter word in 15.1s and a 9-letter word in 28.1s;
    /// at top speed a 7-letter word still gets 12.7s.
    static let baseFallTime: TimeInterval = 2.0
    static let fallTimePerLetter: TimeInterval = 1.5
    static let thinkingTimePerExtraLetter: TimeInterval = 0.6
    static let thinkingTimeGrowth: TimeInterval = 0.25
    /// Speed stops increasing at this multiplier.
    static let fastestSpeed = 0.5
    static let speedIncreasePerLevel = 0.035

    static func fallDuration(length: Int, speed: Double, timeScale: Double = 1) -> TimeInterval {
        let extra = Double(max(0, length - 3))
        let thinking = thinkingTimePerExtraLetter * extra + thinkingTimeGrowth * extra * extra
        return ((baseFallTime + fallTimePerLetter * Double(length)) * speed + thinking) * timeScale
    }

    static func level(forWordsSolved solved: Int) -> Int {
        1 + max(0, solved) / wordsPerLevel
    }

    static func speed(for level: Int, difficulty: GameDifficulty = .normal) -> Double {
        let ramp = speedIncreasePerLevel * difficulty.rampScale
        return max(fastestSpeed, 1.0 - ramp * Double(max(level, 1) - 1))
    }

    /// Word lengths and difficulty by level. Length grows in steps while
    /// speed creeps up every level, so the two don't jump together.
    private static let table: [(lengths: ClosedRange<Int>, maxDifficulty: Int)] = [
        (3...3, 1),   // 1
        (3...4, 2),   // 2
        (3...4, 2),   // 3
        (4...4, 2),   // 4
        (4...5, 3),   // 5
        (4...5, 3),   // 6
        (5...5, 3),   // 7
        (5...5, 3),   // 8
        (5...6, 3),   // 9
        (5...6, 4),   // 10
        (6...6, 4),   // 11
        (6...6, 4),   // 12
    ]

    static func profile(for level: Int, difficulty: GameDifficulty = .normal) -> DifficultyProfile {
        let level = max(1, level)
        let wordLevel = level + difficulty.wordLevelOffset
        var (lengths, maxDifficulty, minFrequency) = words(forLevel: wordLevel)
        if difficulty == .easy {
            // Friendlier words: one step easier, never obscure, and capped in length.
            let cap = difficulty.maxLength
            lengths = min(lengths.lowerBound, cap)...min(lengths.upperBound, cap)
            maxDifficulty = max(1, maxDifficulty - 1)
            minFrequency = max(minFrequency, 3.9 / 7.0)
        }

        return DifficultyProfile(
            level: level,
            lengths: lengths,
            maxDifficulty: maxDifficulty,
            minFrequency: minFrequency,
            speed: speed(for: level, difficulty: difficulty),
            timeScale: difficulty.timeScale,
            maxActiveWords: 1
        )
    }

    /// Which words appear at a level on normal difficulty.
    private static func words(forLevel level: Int) -> (lengths: ClosedRange<Int>, maxDifficulty: Int, minFrequency: Double) {
        let minFrequency: Double
        switch level {
        case ...5: minFrequency = 4.3 / 7.0       // everyday words only
        case ...15: minFrequency = 3.9 / 7.0      // common words
        default: minFrequency = 0                  // anything playable
        }

        let lengths: ClosedRange<Int>
        let maxDifficulty: Int
        if level <= table.count {
            (lengths, maxDifficulty) = table[level - 1]
        } else {
            // Past the table: grow length every 4 levels.
            let extra = level - table.count
            lengths = min(6 + extra / 8, 7)...min(7 + extra / 4, 9)
            maxDifficulty = min(5, 4 + extra / 6)
        }
        return (lengths, maxDifficulty, minFrequency)
    }
}
