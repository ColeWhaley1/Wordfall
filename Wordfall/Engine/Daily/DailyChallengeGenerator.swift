import Foundation

/// How one day's puzzle is shaped.
struct DailyRules: Equatable, Sendable {
    /// Word lengths in order.
    let lengthCurve: [Int]
    /// Fall speed multiplier (see `DifficultyService.fallDuration`).
    let speed: Double
    /// Only words at least this familiar are picked, when there are any.
    let minFrequency: Double
}

/// Builds the daily challenge from the date alone: date → seed → words.
///
/// The difficulty follows the week, crossword style: Monday is the gentlest,
/// the puzzle toughens midweek and Saturday is the hardest. It ignores the
/// player's endless difficulty so everyone gets the same puzzle.
enum DailyChallengeGenerator {
    static let wordCount = 10
    static let lives = 3
    /// Bump when the generation rules change so old seeds aren't reinterpreted.
    static let version = "v2"

    /// Indexed by `Calendar` weekday: 1 = Sunday … 7 = Saturday.
    static let weekdayDifficulty: [Int: GameDifficulty] = [
        1: .normal, 2: .easy, 3: .normal, 4: .normal, 5: .hard, 6: .hard, 7: .expert,
    ]

    static func rules(for difficulty: GameDifficulty) -> DailyRules {
        switch difficulty {
        case .easy:
            DailyRules(lengthCurve: [4, 4, 4, 5, 5, 5, 5, 6, 6, 6], speed: 0.95, minFrequency: 4.3 / 7.0)
        case .normal:
            DailyRules(lengthCurve: [4, 4, 5, 5, 5, 6, 6, 6, 7, 7], speed: 0.8, minFrequency: 4.0 / 7.0)
        case .hard:
            DailyRules(lengthCurve: [5, 5, 5, 6, 6, 6, 7, 7, 7, 8], speed: 0.7, minFrequency: 3.7 / 7.0)
        case .expert:
            DailyRules(lengthCurve: [5, 6, 6, 6, 7, 7, 7, 8, 8, 9], speed: 0.6, minFrequency: 3.4 / 7.0)
        }
    }

    /// The difficulty for a yyyy-MM-dd key, from its day of the week.
    static func difficulty(forDateKey key: String) -> GameDifficulty {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        guard parts.count == 3,
              let day = gregorian.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else { return .normal }
        return weekdayDifficulty[gregorian.component(.weekday, from: day)] ?? .normal
    }

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
        let difficulty = difficulty(forDateKey: dateKey)
        let rules = rules(for: difficulty)
        var rng = SeededRandom(seed: seed)
        var used = Set<String>()
        var words: [DailyWord] = []

        for length in rules.lengthCurve {
            let all = database.playableWords(length: length)
            let familiar = all.filter { $0.frequency >= rules.minFrequency }
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
            speed: rules.speed,
            difficulty: difficulty
        )
    }
}
