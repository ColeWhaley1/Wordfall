import Foundation
import SwiftData

/// One finished game. Written once, when the game ends.
@Model
final class GameResult {
    var id: UUID = UUID()
    var date: Date = Date.now
    /// "endless" or "daily".
    var mode: String = "endless"
    /// A `GameDifficulty` raw value.
    var difficulty: String = GameDifficulty.normal.rawValue
    var score: Int = 0
    var level: Int = 1
    var wordsSolved: Int = 0
    var wordsMissed: Int = 0
    var highestCombo: Int = 0
    var duration: Double = 0
    var coinsEarned: Int = 0

    init(date: Date, mode: String, difficulty: GameDifficulty, score: Int, level: Int, wordsSolved: Int, wordsMissed: Int, highestCombo: Int, duration: Double, coinsEarned: Int) {
        self.id = UUID()
        self.date = date
        self.mode = mode
        self.difficulty = difficulty.rawValue
        self.coinsEarned = coinsEarned
        self.score = score
        self.level = level
        self.wordsSolved = wordsSolved
        self.wordsMissed = wordsMissed
        self.highestCombo = highestCombo
        self.duration = duration
    }
}
