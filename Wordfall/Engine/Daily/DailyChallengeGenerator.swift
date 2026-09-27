import Foundation

/// Builds the daily challenge from the date alone: date → seed → words.
enum DailyChallengeGenerator {
    static let wordCount = 10
    /// Word lengths in order: a gentle ramp from 4 to 7 letters.
    static let lengthCurve = [4, 4, 5, 5, 5, 6, 6, 6, 7, 7]
    static let lives = 3
    /// A 4-letter word falls in 6.4s, a 7-letter word in 10s.
    static let speed = 0.8
    /// Only familiar words appear in the daily puzzle.
    static let minFrequency = 4.0 / 7.0
    /// Bump when the generation rules change so old seeds aren't reinterpreted.
    static let version = "v1"

    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Days since 2026-01-01 (Daily #1).
    static func number(for date: Date, calendar: Calendar = .current) -> Int {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let today = calendar.dateComponents([.year, .month, .day], from: date)
        guard let start = gregorian.date(from: DateComponents(year: 2026, month: 1, day: 1)),
              let day = gregorian.date(from: today),
              let days = gregorian.dateComponents([.day], from: start, to: day).day
        else { return 1 }
        return days + 1
    }

    static func seed(forDateKey key: String) -> UInt64 {
        StableHash.fnv1a("wordfall-daily-\(version)-\(key)")
    }

    static func challenge(for date: Date, database: WordDatabase, calendar: Calendar = .current) -> DailyChallenge {
        let key = dateKey(for: date, calendar: calendar)
        return challenge(dateKey: key, number: number(for: date, calendar: calendar), database: database)
    }

    static func challenge(dateKey: String, number: Int, database: WordDatabase) -> DailyChallenge {
        let seed = seed(forDateKey: dateKey)
        var rng = SeededRandom(seed: seed)
        var used = Set<String>()
        var words: [DailyWord] = []

        for length in lengthCurve {
            let all = database.playableWords(length: length)
            let familiar = all.filter { $0.frequency >= minFrequency }
            let pool = (familiar.isEmpty ? all : familiar).filter { !used.contains($0.text) }
            guard !pool.isEmpty else { continue }
            let pick = pool[rng.index(below: pool.count)]
            used.insert(pick.text)
            let scrambled = WordGenerator.scramble(pick.text, database: database, using: &rng)
            words.append(DailyWord(word: pick.text, scrambled: scrambled))
        }

        return DailyChallenge(
            dateKey: dateKey,
            number: number,
            seed: seed,
            words: words,
            lives: lives,
            speed: speed
        )
    }
}
