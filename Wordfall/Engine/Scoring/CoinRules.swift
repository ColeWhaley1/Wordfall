import Foundation

/// How points turn into coins at the end of a round. Coins buy cosmetics only.
enum CoinRules {
    /// One coin per this many points. Difficulty already scales the points,
    /// so harder games pay out far more.
    static let pointsPerCoin = 20
    /// Extra coins for finishing every word of a daily puzzle.
    static let dailyCompletionBonus = 25

    static func coins(forScore score: Int, completedDaily: Bool = false) -> Int {
        max(0, score) / pointsPerCoin + (completedDaily ? dailyCompletionBonus : 0)
    }
}
