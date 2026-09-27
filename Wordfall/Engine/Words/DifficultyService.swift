import Foundation

/// Everything that changes as the player levels up, in one place so the curve
/// can be tuned by playtesting.
struct DifficultyProfile: Equatable, Sendable {
    let level: Int
    /// Allowed word lengths.
    let lengths: ClosedRange<Int>
    /// Preferred maximum word difficulty (1...5). Relaxed if nothing matches.
    let maxDifficulty: Int
    /// Minimum normalised frequency; keeps rare words out of early levels.
    let minFrequency: Double
    /// Seconds a word takes to fall from the top to the danger line.
    let fallDuration: TimeInterval
    /// Words on screen at once. Always 1 in v1; multi-lane play comes later.
    let maxActiveWords: Int
}

enum DifficultyService {
    /// Correct words needed to advance one level.
    static let wordsPerLevel = 5

    static func level(forWordsSolved solved: Int) -> Int {
        1 + max(0, solved) / wordsPerLevel
    }

    /// The curve alternates between making words faster and making them longer
    /// instead of raising everything at once.
    private static let table: [(lengths: ClosedRange<Int>, maxDifficulty: Int, fall: TimeInterval)] = [
        (3...3, 1, 9.0),   // 1
        (3...4, 2, 8.5),   // 2  longer
        (3...4, 2, 7.8),   // 3  faster
        (4...4, 2, 7.8),   // 4  longer
        (4...5, 3, 7.8),   // 5  longer
        (4...5, 3, 7.0),   // 6  faster
        (5...5, 3, 7.4),   // 7  longer (a little extra time)
        (5...5, 3, 6.6),   // 8  faster
        (5...6, 3, 7.0),   // 9  longer
        (5...6, 4, 6.3),   // 10 faster
        (6...6, 4, 6.8),   // 11 longer
        (6...6, 4, 6.0),   // 12 faster
    ]

    static func profile(for level: Int) -> DifficultyProfile {
        let level = max(1, level)
        let minFrequency: Double
        switch level {
        case ...5: minFrequency = 4.0 / 7.0       // very common words
        case ...15: minFrequency = 3.6 / 7.0      // common and moderately uncommon
        default: minFrequency = 0                  // anything playable
        }

        if level <= table.count {
            let row = table[level - 1]
            return DifficultyProfile(
                level: level,
                lengths: row.lengths,
                maxDifficulty: row.maxDifficulty,
                minFrequency: minFrequency,
                fallDuration: row.fall,
                maxActiveWords: 1
            )
        }

        // Past the table: grow length every 4 levels, speed up a little each level.
        let extra = level - table.count
        let minLength = min(6 + extra / 8, 7)
        let maxLength = min(7 + extra / 4, 9)
        let lengthBonus = Double(maxLength - 6) * 0.4
        let fall = max(3.2, 6.2 - Double(extra) * 0.12) + lengthBonus
        return DifficultyProfile(
            level: level,
            lengths: minLength...maxLength,
            maxDifficulty: min(5, 4 + extra / 6),
            minFrequency: minFrequency,
            fallDuration: fall,
            maxActiveWords: 1
        )
    }
}
