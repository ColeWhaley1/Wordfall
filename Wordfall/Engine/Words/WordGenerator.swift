import Foundation

/// Picks the next falling word for a difficulty profile and scrambles it.
struct WordGenerator {
    let database: WordDatabase
    /// Words are not repeated within this many picks.
    var recentLimit = 40
    private(set) var recent: [String] = []

    init(database: WordDatabase, recentLimit: Int = 40) {
        self.database = database
        self.recentLimit = recentLimit
    }

    mutating func nextWord(for profile: DifficultyProfile, using rng: inout SeededRandom) -> Word {
        let candidates = candidates(for: profile)
        let fresh = candidates.filter { !recent.contains($0.text) }
        let pool = fresh.isEmpty ? candidates : fresh
        precondition(!pool.isEmpty, "Word database has no playable words")
        let word = pool[rng.index(below: pool.count)]
        remember(word.text)
        return word
    }

    mutating func remember(_ text: String) {
        recent.append(text)
        if recent.count > recentLimit {
            recent.removeFirst(recent.count - recentLimit)
        }
    }

    /// Words matching the profile, relaxing the filters step by step if needed
    /// so a pick is always possible.
    func candidates(for profile: DifficultyProfile) -> [Word] {
        let byLength = profile.lengths.flatMap { database.playableWords(length: $0) }
        let strict = byLength.filter {
            $0.frequency >= profile.minFrequency && $0.difficulty <= profile.maxDifficulty
        }
        if !strict.isEmpty { return strict }
        let frequent = byLength.filter { $0.frequency >= profile.minFrequency }
        if !frequent.isEmpty { return frequent }
        if !byLength.isEmpty { return byLength }
        return database.playableLengths.flatMap { database.playableWords(length: $0) }
    }

    /// Shuffles the letters so the result never equals the answer and, where
    /// possible, isn't another valid word either (which would give it away).
    static func scramble(_ word: String, database: WordDatabase?, using rng: inout SeededRandom) -> [Character] {
        let letters = Array(word.uppercased())
        guard Set(letters).count > 1 else { return letters }
        var fallback: [Character]?
        for _ in 0..<24 {
            let shuffled = letters.stableShuffled(using: &rng)
            if shuffled == letters { continue }
            if let database, database.contains(String(shuffled)) {
                fallback = fallback ?? shuffled
                continue
            }
            return shuffled
        }
        if let fallback { return fallback }
        // Deterministic last resort: rotate by one, which always differs when
        // the letters are not all identical.
        var rotated = letters
        repeat {
            rotated.append(rotated.removeFirst())
        } while rotated == letters
        return rotated
    }
}
