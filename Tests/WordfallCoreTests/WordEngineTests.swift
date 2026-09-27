import XCTest
@testable import WordfallCore

final class WordEngineTests: XCTestCase {
    func testSignatureSortsLetters() {
        XCTAssertEqual(AnagramService.signature("stop"), "OPST")
        XCTAssertEqual(AnagramService.signature("PLANET"), "AELNPT")
        XCTAssertEqual(AnagramService.signature("tangle"), "AEGLNT")
        XCTAssertTrue(AnagramService.areAnagrams("STOP", "post"))
    }

    func testValidatorAcceptsAnyAnagramInDatabase() {
        let validator = WordValidator(database: TestSupport.tiny)
        for answer in ["STOP", "POST", "POTS", "TOPS"] {
            XCTAssertTrue(validator.isCorrect(answer, for: "STOP"), answer)
        }
        XCTAssertFalse(validator.isCorrect("OPTS", for: "STOP"), "not in tiny database")
        XCTAssertFalse(validator.isCorrect("SPOT", for: "STOP"), "not in tiny database")
        XCTAssertFalse(validator.isCorrect("STO", for: "STOP"))
        XCTAssertFalse(validator.isCorrect("RATE", for: "STOP"))
        XCTAssertTrue(validator.isCorrect("rate", for: "TEAR"))
    }

    func testValidatorAcceptsTargetEvenIfMissingFromDatabase() {
        let validator = WordValidator(database: TestSupport.tiny)
        XCTAssertTrue(validator.isCorrect("PLANET", for: "planet"))
    }

    func testBundledDatabaseLoadsAndIsCurated() {
        let db = TestSupport.database
        XCTAssertGreaterThan(db.words.count, 20_000)
        let playable = db.words.filter(\.playable).count
        XCTAssertTrue((5_000...15_000).contains(playable), "playable: \(playable)")
        for length in 3...9 {
            XCTAssertFalse(db.playableWords(length: length).isEmpty, "no \(length)-letter words")
        }
        for word in ["STOP", "POST", "POTS", "TOPS", "RATE", "TEAR", "PLANET", "CASTLE", "HOUSE"] {
            XCTAssertTrue(db.contains(word), word)
        }
        XCTAssertEqual(Set(db.anagrams(of: "STOP")).isSuperset(of: ["STOP", "POST", "POTS", "TOPS"]), true)
        for bad in ["FUCK", "SHIT"] {
            XCTAssertFalse(db.contains(bad), bad)
        }
        XCTAssertTrue(db.words.allSatisfy { $0.word == $0.word.lowercased() && $0.length == $0.word.count })
    }

    func testScrambleNeverReturnsTheAnswer() {
        var rng = SeededRandom(seed: 42)
        for word in ["CAT", "STOP", "APPLE", "PLANET", "AB", "TOOT"] {
            for _ in 0..<50 {
                let scrambled = WordGenerator.scramble(word, database: TestSupport.database, using: &rng)
                XCTAssertNotEqual(String(scrambled), word)
                XCTAssertEqual(AnagramService.signature(String(scrambled)), AnagramService.signature(word))
            }
        }
    }

    func testScrambleAvoidsOtherValidWordsWhenPossible() {
        var rng = SeededRandom(seed: 7)
        for _ in 0..<100 {
            let scrambled = String(WordGenerator.scramble("STOP", database: TestSupport.database, using: &rng))
            XCTAssertFalse(TestSupport.database.contains(scrambled), scrambled)
        }
    }

    func testSeededRandomIsDeterministic() {
        var a = SeededRandom(seed: 123)
        var b = SeededRandom(seed: 123)
        XCTAssertEqual((0..<10).map { _ in a.next() }, (0..<10).map { _ in b.next() })
        var c = SeededRandom(seed: 123)
        var d = SeededRandom(seed: 124)
        XCTAssertNotEqual(c.next(), d.next())
    }

    func testGeneratorRespectsProfileAndAvoidsRepeats() {
        var generator = WordGenerator(database: TestSupport.database, recentLimit: 40)
        var rng = SeededRandom(seed: 99)
        let profile = DifficultyService.profile(for: 1)
        var picks: [String] = []
        for _ in 0..<40 {
            let word = generator.nextWord(for: profile, using: &rng)
            XCTAssertTrue(profile.lengths.contains(word.length))
            XCTAssertGreaterThanOrEqual(word.frequency, profile.minFrequency)
            XCTAssertTrue(word.playable)
            picks.append(word.text)
        }
        XCTAssertEqual(Set(picks).count, picks.count, "repeated within recent window")
    }

    func testGeneratorFallsBackWhenNothingMatches() {
        var generator = WordGenerator(database: TestSupport.tiny)
        var rng = SeededRandom(seed: 1)
        let profile = DifficultyProfile(level: 99, lengths: 12...12, maxDifficulty: 1, minFrequency: 1, speed: 1, maxActiveWords: 1)
        XCTAssertFalse(generator.nextWord(for: profile, using: &rng).text.isEmpty)
    }

    func testDifficultyCurveGetsHarderWithoutJumps() {
        var previous = DifficultyService.profile(for: 1)
        XCTAssertEqual(previous.lengths, 3...3)
        XCTAssertEqual(previous.maxActiveWords, 1)
        for level in 2...60 {
            let profile = DifficultyService.profile(for: level)
            XCTAssertGreaterThanOrEqual(profile.lengths.upperBound, previous.lengths.upperBound, "level \(level)")
            XCTAssertLessThanOrEqual(profile.lengths.upperBound, 9)
            XCTAssertLessThanOrEqual(profile.speed, previous.speed, "level \(level)")
            XCTAssertGreaterThanOrEqual(profile.fallDuration(forLength: profile.lengths.lowerBound), 5.0, "level \(level)")
            XCTAssertFalse(TestSupport.database.playableWords(length: profile.lengths.lowerBound).isEmpty)
            XCTAssertEqual(profile.maxActiveWords, 1)
            previous = profile
        }
        XCTAssertEqual(DifficultyService.level(forWordsSolved: 0), 1)
        XCTAssertEqual(DifficultyService.level(forWordsSolved: 4), 1)
        XCTAssertEqual(DifficultyService.level(forWordsSolved: 5), 2)
    }

    func testLongerWordsFallMoreSlowly() {
        let profile = DifficultyService.profile(for: 1)
        XCTAssertEqual(profile.fallDuration(forLength: 3), 6.5, accuracy: 0.001)
        XCTAssertEqual(profile.fallDuration(forLength: 9), 15.5, accuracy: 0.001)
        let later = DifficultyService.profile(for: 20)
        XCTAssertLessThan(later.fallDuration(forLength: 6), profile.fallDuration(forLength: 6))
        XCTAssertGreaterThan(later.fallDuration(forLength: 9), later.fallDuration(forLength: 6))
    }

    func testEarlyLevelsOnlyUseEverydayWords() {
        let generator = WordGenerator(database: TestSupport.database)
        let early = Set(generator.candidates(for: DifficultyService.profile(for: 1)).map(\.text))
        for word in ["CAT", "DOG", "SUN", "MAP", "CAR", "RUN"] {
            XCTAssertTrue(early.contains(word), word)
        }
        let first5 = (1...5).flatMap { generator.candidates(for: DifficultyService.profile(for: $0)).map(\.text) }
        for word in ["ITER", "TARE", "TOR", "ODE", "ERE", "BOB", "RICK"] {
            XCTAssertFalse(first5.contains(word), word)
        }
    }

    func testEveryLevelHasEnoughWords() {
        let generator = WordGenerator(database: TestSupport.database)
        for level in 1...40 {
            let count = generator.candidates(for: DifficultyService.profile(for: level)).count
            XCTAssertGreaterThan(count, 100, "level \(level) has only \(count) words")
        }
    }
}
