import Foundation
import SwiftData

/// Lifetime totals. There is a single row, created on first use.
@Model
final class PlayerStats {
    var totalGames: Int = 0
    var totalWordsSolved: Int = 0
    var totalWordsMissed: Int = 0
    var totalPerfects: Int = 0
    var highestScore: Int = 0
    var highestCombo: Int = 0
    var highestLevel: Int = 1
    var longestWord: String = ""
    var fastestSolve: Double?
    var currentDailyStreak: Int = 0
    var longestDailyStreak: Int = 0
    var lastDailyDateKey: String?
    var keyboardLetters: Int = 0
    var tapLetters: Int = 0
    var swipeLetters: Int = 0

    init() {}
}
