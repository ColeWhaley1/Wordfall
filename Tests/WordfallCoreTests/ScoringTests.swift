import XCTest
@testable import WordfallCore

final class ScoringTests: XCTestCase {
    func testLongerWordsAreWorthMore() {
        let values = (3...9).map(ScoreEngine.baseScore(length:))
        XCTAssertEqual(values, [30, 50, 80, 120, 180, 260, 350])
    }

    func testSpeedAndPerfect() {
        XCTAssertEqual(ScoreEngine.speedMultiplier(fraction: 0.05), 2.0)
        XCTAssertEqual(ScoreEngine.speedMultiplier(fraction: 0.95), 1.0)
        XCTAssertTrue(ScoreEngine.isPerfect(fraction: 0.39))
        XCTAssertFalse(ScoreEngine.isPerfect(fraction: 0.4))
    }

    func testComboMultiplierGrowsAndCaps() {
        XCTAssertEqual(ScoreEngine.comboMultiplier(combo: 1), 1.0)
        XCTAssertEqual(ScoreEngine.comboMultiplier(combo: 2), 1.2, accuracy: 0.0001)
        XCTAssertEqual(ScoreEngine.comboMultiplier(combo: 11), 3.0, accuracy: 0.0001)
        XCTAssertEqual(ScoreEngine.comboMultiplier(combo: 50), 3.0, accuracy: 0.0001)
    }

    func testScoreCombinesMultipliers() {
        // 6 letters, slow, first word, level 1: 120 × 1.0 × 1.0 × 1.0
        XCTAssertEqual(ScoreEngine.score(length: 6, fraction: 0.9, combo: 1, level: 1).total, 120)
        // 4 letters, fast (perfect), combo 3, level 1: 50 × 2.0 × 1.4 × 1.25 = 175
        let fast = ScoreEngine.score(length: 4, fraction: 0.1, combo: 3, level: 1)
        XCTAssertTrue(fast.isPerfect)
        XCTAssertEqual(fast.total, 175)
    }

    func testEasierDifficultiesScoreFarLess() {
        let easy = ScoreEngine.score(length: 5, fraction: 0.5, combo: 1, level: 1, difficulty: .easy).total
        let normal = ScoreEngine.score(length: 5, fraction: 0.5, combo: 1, level: 1).total
        let hard = ScoreEngine.score(length: 5, fraction: 0.5, combo: 1, level: 1, difficulty: .hard).total
        let expert = ScoreEngine.score(length: 5, fraction: 0.5, combo: 1, level: 1, difficulty: .expert).total
        XCTAssertLessThan(Double(easy), Double(normal) * 0.5)
        XCTAssertLessThan(normal, hard)
        XCTAssertLessThan(hard, expert)
    }

    func testCoinsFollowPoints() {
        XCTAssertEqual(CoinRules.coins(forScore: 0), 0)
        XCTAssertEqual(CoinRules.coins(forScore: 19), 0)
        XCTAssertEqual(CoinRules.coins(forScore: 2_000), 100)
        XCTAssertEqual(CoinRules.coins(forScore: 2_000, completedDaily: true), 100 + CoinRules.dailyCompletionBonus)
    }

    func testComboMilestones() {
        var combo = ComboEngine()
        var milestones: [ComboMilestone] = []
        for _ in 0..<20 {
            if let milestone = combo.registerSolve() { milestones.append(milestone) }
        }
        XCTAssertEqual(milestones, [.wordChain, .unstoppable, .legendary(20)])
        combo.reset()
        XCTAssertEqual(combo.count, 0)
        XCTAssertEqual(combo.best, 20)
    }

    func testNumberGrouping() {
        XCTAssertEqual(NumberText.grouped(0), "0")
        XCTAssertEqual(NumberText.grouped(999), "999")
        XCTAssertEqual(NumberText.grouped(12840), "12,840")
        XCTAssertEqual(NumberText.grouped(1234567), "1,234,567")
    }
}
