import Foundation

struct DailyWord: Equatable, Hashable, Sendable {
    let word: String
    let scrambled: [Character]
}

/// Today's fixed puzzle. Everyone on the same calendar day gets the same words
/// in the same order with the same scrambles, with no server involved.
struct DailyChallenge: Equatable, Hashable, Sendable {
    /// Calendar day as yyyy-MM-dd.
    let dateKey: String
    /// Running puzzle number, e.g. "Daily #270".
    let number: Int
    let seed: UInt64
    let words: [DailyWord]
    let lives: Int
    /// Fall speed multiplier (see `DifficultyService.fallDuration`).
    let speed: Double

    /// Longer words fall more slowly, as in endless mode.
    func fallDuration(forWordAt index: Int) -> TimeInterval {
        let length = words.indices.contains(index) ? words[index].word.count : 5
        return DifficultyService.fallDuration(length: length, speed: speed)
    }
}
