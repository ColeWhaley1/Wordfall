import Foundation

/// Everything the player did to one word, used for stats and the daily share grid.
enum WordOutcome: String, Codable, Equatable, Sendable {
    case perfect
    case solved
    case missed
}

struct SolveResult: Equatable, Sendable {
    /// The falling word's intended answer.
    let word: String
    /// What the player actually spelled (may be a different anagram).
    let answer: String
    let score: ScoreBreakdown
    let combo: Int
    let milestone: ComboMilestone?
    let solveTime: TimeInterval
    let fraction: Double
    let lastMethod: InputMethod?

    var points: Int { score.total }
    var isPerfect: Bool { score.isPerfect }
}

/// One-off moments the UI turns into animation, sound and haptics.
/// State (score, lives, the falling word) is observed directly instead.
enum GameEvent: Equatable, Sendable {
    case started
    case spawned(FallingWord)
    case letterSelected(LetterTile, InputMethod)
    case letterRemoved
    /// All letters were used but they don't spell a word; the selection was cleared.
    case rejected(String)
    /// A typed key matched no free letter.
    case invalidKey(Character)
    case solved(SolveResult)
    case dangerEntered
    case missed(String)
    case levelUp(Int)
    case gameOver
}
