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
    /// Base fall time; longer words get a little more.
    let baseFallDuration: TimeInterval

    func fallDuration(forWordAt index: Int) -> TimeInterval {
        guard words.indices.contains(index) else { return baseFallDuration }
        return baseFallDuration + Double(max(0, words[index].word.count - 4)) * 0.6
    }
}
