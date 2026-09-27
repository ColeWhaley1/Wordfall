import Foundation

/// One entry of the bundled word database (`words.json`).
struct Word: Codable, Hashable, Sendable {
    /// Lowercase spelling as stored in the database.
    let word: String
    let length: Int
    /// 1 (easiest) to 5 (hardest), from length, familiarity, letter rarity and anagram count.
    let difficulty: Int
    /// Normalised usage frequency, 0...1 (Zipf frequency / 7).
    let frequency: Double
    /// Very common everyday word.
    let common: Bool
    /// Eligible to be spawned as a falling word. Non-playable words are still accepted as answers.
    let playable: Bool

    /// Uppercase spelling used everywhere in gameplay.
    var text: String { word.uppercased() }
}
