import XCTest
@testable import WordfallCore

final class DailyChallengeTests: XCTestCase {
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
    }

    func testSameDayGivesSameChallenge() {
        let morning = DailyChallengeGenerator.challenge(for: date(2026, 9, 27, hour: 1), database: TestSupport.database, calendar: utc)
        let evening = DailyChallengeGenerator.challenge(for: date(2026, 9, 27, hour: 23), database: TestSupport.database, calendar: utc)
        XCTAssertEqual(morning, evening)
        XCTAssertEqual(morning.dateKey, "2026-09-27")
        XCTAssertEqual(morning.words.count, DailyChallengeGenerator.wordCount)
    }

    func testDifferentDaysDiffer() {
        let a = DailyChallengeGenerator.challenge(for: date(2026, 9, 27), database: TestSupport.database, calendar: utc)
        let b = DailyChallengeGenerator.challenge(for: date(2026, 9, 28), database: TestSupport.database, calendar: utc)
        XCTAssertNotEqual(a.words, b.words)
        XCTAssertEqual(b.number, a.number + 1)
    }

    func testChallengeFollowsTheLengthCurve() {
        let challenge = DailyChallengeGenerator.challenge(for: date(2026, 9, 27), database: TestSupport.database, calendar: utc)
        XCTAssertEqual(challenge.words.map(\.word.count), DailyChallengeGenerator.rules(for: challenge.difficulty).lengthCurve)
        XCTAssertEqual(Set(challenge.words.map(\.word)).count, challenge.words.count, "no duplicates")
        for word in challenge.words {
            XCTAssertNotEqual(String(word.scrambled), word.word)
            XCTAssertTrue(AnagramService.areAnagrams(String(word.scrambled), word.word))
        }
        XCTAssertGreaterThan(challenge.fallDuration(forWordAt: 9), challenge.fallDuration(forWordAt: 0))
    }

    func testDifficultyFollowsTheWeek() {
        // 2026-09-27 is a Sunday.
        let week = (27...33).map { day -> GameDifficulty in
            let key = DailyChallengeGenerator.dateKey(for: date(2026, 9, 1).addingTimeInterval(Double(day - 1) * 86_400), calendar: utc)
            return DailyChallengeGenerator.difficulty(forDateKey: key)
        }
        XCTAssertEqual(week, [.normal, .easy, .normal, .normal, .hard, .hard, .expert])

        let monday = DailyChallengeGenerator.challenge(for: date(2026, 9, 28), database: TestSupport.database, calendar: utc)
        let saturday = DailyChallengeGenerator.challenge(for: date(2026, 10, 3), database: TestSupport.database, calendar: utc)
        XCTAssertEqual(monday.difficulty, .easy)
        XCTAssertEqual(saturday.difficulty, .expert)
        XCTAssertLessThan(monday.words.map(\.word.count).reduce(0, +), saturday.words.map(\.word.count).reduce(0, +))
        XCTAssertEqual(saturday.words.count, DailyChallengeGenerator.wordCount)
        XCTAssertEqual(GameConfiguration.daily(saturday).difficulty, .expert)
    }

    func testNumbering() {
        XCTAssertEqual(DailyChallengeGenerator.number(for: date(2026, 1, 1), calendar: utc), 1)
        XCTAssertEqual(DailyChallengeGenerator.number(for: date(2026, 9, 27), calendar: utc), 270)
    }

    /// Guards against accidental changes to generation, which would give
    /// players on different app versions different puzzles on the same day.
    func testGenerationIsStable() {
        XCTAssertEqual(DailyChallengeGenerator.seed(forDateKey: "2026-09-27"), StableHash.fnv1a("wordfall-daily-v2-2026-09-27"))
        let a = DailyChallengeGenerator.challenge(dateKey: "2026-09-27", number: 270, database: TestSupport.database)
        let b = DailyChallengeGenerator.challenge(dateKey: "2026-09-27", number: 270, database: TestSupport.database)
        XCTAssertEqual(a, b)
    }

    func testShareTextHidesAnswers() {
        let challenge = DailyChallengeGenerator.challenge(for: date(2026, 9, 27), database: TestSupport.database, calendar: utc)
        let text = ShareResult.text(
            number: challenge.number,
            outcomes: [.perfect, .perfect, .solved, .missed, .solved, .perfect, .solved],
            total: 10,
            score: 4820,
            bestCombo: 3
        )
        XCTAssertTrue(text.hasPrefix("Word Fallout Daily #270"))
        XCTAssertTrue(text.contains("6/10"))
        XCTAssertTrue(text.contains("🟩 🟩 🟨 🟥 🟨\n🟩 🟨 ⬛ ⬛ ⬛"))
        XCTAssertTrue(text.contains("Score: 4,820"))
        XCTAssertTrue(text.contains("🔥 3 combo"))
        for word in challenge.words {
            XCTAssertFalse(text.uppercased().contains(word.word), "leaked \(word.word)")
        }
    }
}
