import Foundation
import SwiftData

/// The player's run of one day's challenge. One per calendar day.
@Model
final class DailyResult {
    @Attribute(.unique) var dateKey: String = ""
    var number: Int = 0
    var date: Date = Date.now
    var score: Int = 0
    /// Every word was played (the run didn't end by running out of lives).
    var completed: Bool = false
    var wordsSolved: Int = 0
    var totalWords: Int = 0
    var bestCombo: Int = 0
    var averageSolveTime: Double?
    /// Comma-separated `WordOutcome` raw values, for the share grid.
    var outcomesRaw: String = ""

    init(dateKey: String, number: Int, date: Date, score: Int, completed: Bool, wordsSolved: Int, totalWords: Int, bestCombo: Int, averageSolveTime: Double?, outcomes: [WordOutcome]) {
        self.dateKey = dateKey
        self.number = number
        self.date = date
        self.score = score
        self.completed = completed
        self.wordsSolved = wordsSolved
        self.totalWords = totalWords
        self.bestCombo = bestCombo
        self.averageSolveTime = averageSolveTime
        self.outcomesRaw = outcomes.map(\.rawValue).joined(separator: ",")
    }

    var outcomes: [WordOutcome] {
        outcomesRaw.split(separator: ",").compactMap { WordOutcome(rawValue: String($0)) }
    }

    var shareText: String {
        ShareResult.text(number: number, outcomes: outcomes, total: totalWords, score: score, bestCombo: bestCombo)
    }
}
