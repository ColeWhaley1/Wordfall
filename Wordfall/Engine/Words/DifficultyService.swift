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
    /// Words on screen at once. Always 1 in v1; multi-lane play comes later.
    let maxActiveWords: Int

    /// Seconds a word of this length takes to reach the danger line.
    func fallDuration(forLength length: Int) -> TimeInterval {
        DifficultyService.fallDuration(length: length, speed: speed)
    }
}

enum DifficultyService {
    /// Correct words needed to advance one level.
    static let wordsPerLevel = 5

    /// Fall time = (base + perLetter × length) × speed. Longer words get
    /// proportionally more time: at level 1 a 3-letter word falls in 6.5s and
    /// a 9-letter word in 15.5s.
    static let baseFallTime: TimeInterval = 2.0
    static let fallTimePerLetter: TimeInterval = 1.5
    /// Speed stops increasing at this multiplier.
    static let fastestSpeed = 0.5
    static let speedIncreasePerLevel = 0.035

    static func fallDuration(length: Int, speed: Double) -> TimeInterval {
        (baseFallTime + fallTimePerLetter * Double(length)) * speed
    }

    static func level(forWordsSolved solved: Int) -> Int {
        1 + max(0, solved) / wordsPerLevel
    }

    static func speed(for level: Int) -> Double {
        max(fastestSpeed, 1.0 - speedIncreasePerLevel * Double(max(level, 1) - 1))
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

    static func profile(for level: Int) -> DifficultyProfile {
        let level = max(1, level)
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

        return DifficultyProfile(
            level: level,
            lengths: lengths,
            maxDifficulty: maxDifficulty,
            minFrequency: minFrequency,
            speed: speed(for: level),
            maxActiveWords: 1
        )
    }
}
