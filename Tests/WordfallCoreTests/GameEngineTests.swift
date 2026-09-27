import XCTest
@testable import WordfallCore

final class GameEngineTests: XCTestCase {
    private func dailyEngine(_ words: [String], lives: Int? = nil) -> (GameEngine, EventLog) {
        var configuration = GameConfiguration.daily(TestSupport.dailyChallenge(words))
        if let lives { configuration.startingLives = lives }
        let engine = GameEngine(database: TestSupport.tiny, configuration: configuration, seed: 1)
        let log = EventLog()
        engine.onEvent = { log.events.append($0) }
        engine.start()
        engine.waitForWord()
        return (engine, log)
    }

    func testStartSpawnsAWordAfterTheInitialDelay() {
        let engine = GameEngine(database: TestSupport.tiny, seed: 3)
        XCTAssertEqual(engine.status, .ready)
        engine.start()
        XCTAssertEqual(engine.status, .playing)
        XCTAssertNil(engine.activeWord)
        engine.waitForWord()
        let word = try! XCTUnwrap(engine.activeWord)
        XCTAssertTrue(["CAT", "ACT"].contains(word.word))
        XCTAssertNotEqual(word.scrambledText, word.word)
    }

    func testTypingTheAnswerSolvesWithoutSubmit() {
        let (engine, log) = dailyEngine(["STOP", "RATE"])
        XCTAssertEqual(engine.activeWord?.scrambledText, "POTS")
        engine.typeWord("sto")
        XCTAssertEqual(engine.currentInput, "STO")
        engine.type("p")
        XCTAssertNil(engine.activeWord)
        XCTAssertEqual(engine.wordsSolved, 1)
        XCTAssertEqual(engine.combo, 1)
        XCTAssertGreaterThan(engine.score, 0)
        XCTAssertTrue(log.events.contains { if case .solved(let r) = $0 { return r.answer == "STOP" } else { return false } })
    }

    func testAnyValidAnagramSolves() {
        let (engine, _) = dailyEngine(["STOP"])
        engine.typeWord("TOPS")
        XCTAssertEqual(engine.wordsSolved, 1)
        XCTAssertEqual(engine.lastSolve?.answer, "TOPS")
        XCTAssertEqual(engine.lastSolve?.word, "STOP")
    }

    func testWrongFullAnswerIsRejectedAndCleared() {
        let (engine, log) = dailyEngine(["STOP"])
        engine.typeWord("SPTO")
        XCTAssertEqual(engine.wordsSolved, 0)
        XCTAssertEqual(engine.currentInput, "")
        XCTAssertNotNil(engine.activeWord)
        XCTAssertTrue(log.events.contains(.rejected("SPTO")))
    }

    func testTypingALetterThatIsNotAvailable() {
        let (engine, log) = dailyEngine(["STOP"])
        XCTAssertFalse(engine.type("Z"))
        engine.type("S")
        XCTAssertFalse(engine.type("S"), "only one S tile")
        XCTAssertEqual(engine.currentInput, "S")
        XCTAssertEqual(log.events.filter { if case .invalidKey = $0 { return true } else { return false } }.count, 2)
    }

    func testTapSwipeAndKeyboardShareOneSelection() {
        let (engine, _) = dailyEngine(["RATE"])
        let tiles = try! XCTUnwrap(engine.activeWord?.tiles) // E T A R
        XCTAssertEqual(String(tiles.map(\.letter)), "ETAR")
        engine.toggle(tileID: 3)                   // tap R
        engine.select(tileID: 2, via: .swipe)      // swipe A
        engine.type("t")                           // type T
        XCTAssertEqual(engine.currentInput, "RAT")
        engine.toggle(tileID: 2)                   // tap A again removes it
        XCTAssertEqual(engine.currentInput, "RT")
        engine.deleteLast()
        XCTAssertEqual(engine.currentInput, "R")
        engine.typeWord("ate")
        XCTAssertEqual(engine.wordsSolved, 1)
        XCTAssertEqual(engine.lastSolve?.lastMethod, .keyboard)
        XCTAssertEqual(engine.inputCounts[.tap], 1)
        XCTAssertEqual(engine.inputCounts[.swipe], 1)
    }

    func testMissCostsALifeAndResetsCombo() {
        let (engine, log) = dailyEngine(["STOP", "RATE", "CAT"])
        engine.typeWord("STOP")
        XCTAssertEqual(engine.combo, 1)
        engine.waitForWord()
        XCTAssertEqual(engine.activeWord?.word, "RATE")
        for _ in 0..<200 where engine.activeWord?.word == "RATE" { engine.tick(0.1) }
        XCTAssertEqual(engine.lives, 2)
        XCTAssertEqual(engine.combo, 0)
        XCTAssertEqual(engine.bestCombo, 1)
        XCTAssertEqual(engine.wordsMissed, 1)
        XCTAssertTrue(log.events.contains(.missed("RATE")))
        XCTAssertTrue(log.events.contains(.dangerEntered))
    }

    func testLosingAllLivesEndsTheGame() {
        let engine = GameEngine(database: TestSupport.tiny, seed: 5)
        let log = EventLog()
        engine.onEvent = { log.events.append($0) }
        engine.start()
        for _ in 0..<2000 where engine.status == .playing { engine.tick(0.1) }
        XCTAssertEqual(engine.status, .gameOver)
        XCTAssertEqual(engine.lives, 0)
        XCTAssertEqual(engine.wordsMissed, 3)
        XCTAssertEqual(log.events.last, .gameOver)
        XCTAssertFalse(engine.type("A"), "no input after game over")
    }

    func testDailyEndsAfterLastWord() {
        let (engine, _) = dailyEngine(["STOP", "CAT"])
        engine.typeWord("STOP")
        engine.waitForWord()
        engine.typeWord("CAT")
        engine.tick(1)
        XCTAssertEqual(engine.status, .gameOver)
        XCTAssertEqual(engine.outcomes.count, 2)
        XCTAssertEqual(engine.dailyProgress?.played, 2)
        XCTAssertEqual(engine.lives, 3)
    }

    func testHistoryRecordsEveryWord() {
        let (engine, _) = dailyEngine(["STOP", "RATE", "CAT"])
        engine.typeWord("TOPS")
        engine.waitForWord()
        for _ in 0..<300 where engine.activeWord?.word == "RATE" { engine.tick(0.1) }
        engine.waitForWord()
        engine.typeWord("ACT")
        engine.tick(2)
        XCTAssertEqual(engine.history.map(\.word), ["STOP", "RATE", "CAT"])
        XCTAssertEqual(engine.history.map(\.answer), ["TOPS", nil, "ACT"])
        XCTAssertEqual(engine.history.map(\.isSolved), [true, false, true])
        XCTAssertGreaterThan(engine.history[0].points, 0)
        XCTAssertEqual(engine.history[1].points, 0)
    }

    func testFastSolveIsPerfect() {
        let (engine, _) = dailyEngine(["CAT"])
        engine.typeWord("CAT")
        XCTAssertEqual(engine.outcomes, [.perfect])
        XCTAssertEqual(engine.perfectCount, 1)
    }

    func testLevelUpEveryFiveWordsInEndless() {
        let engine = GameEngine(database: TestSupport.tiny, seed: 11)
        let log = EventLog()
        engine.onEvent = { log.events.append($0) }
        engine.start()
        for _ in 0..<5 {
            engine.waitForWord()
            engine.typeWord(engine.activeWord!.word)
        }
        XCTAssertEqual(engine.level, 2)
        XCTAssertTrue(log.events.contains(.levelUp(2)))
        XCTAssertEqual(engine.combo, 5)
        XCTAssertEqual(engine.lastSolve?.milestone, .wordChain)
    }

    func testPauseFreezesTheWord() {
        let (engine, _) = dailyEngine(["STOP"])
        let before = engine.activeWord!.elapsed
        engine.pause()
        engine.tick(1)
        XCTAssertEqual(engine.activeWord!.elapsed, before)
        XCTAssertFalse(engine.type("S"))
        engine.resume()
        engine.tick(0.1)
        XCTAssertGreaterThan(engine.activeWord!.elapsed, before)
    }

    func testLargeTimeStepsAreClamped() {
        let (engine, _) = dailyEngine(["STOP"])
        engine.tick(60)
        XCTAssertNotNil(engine.activeWord, "a backgrounded frame must not skip the whole fall")
        XCTAssertEqual(engine.lives, 3)
    }
}

final class EventLog {
    var events: [GameEvent] = []
}
