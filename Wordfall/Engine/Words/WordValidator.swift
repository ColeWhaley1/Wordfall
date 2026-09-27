import Foundation

/// Decides whether an answer solves a falling word. Any accepted word that
/// uses exactly the same letters counts, so POST solves STOP.
struct WordValidator: Sendable {
    let database: WordDatabase

    func isCorrect(_ answer: String, for target: String) -> Bool {
        let answer = answer.uppercased()
        let target = target.uppercased()
        guard answer.count == target.count,
              AnagramService.signature(answer) == AnagramService.signature(target)
        else { return false }
        return answer == target || database.contains(answer)
    }
}
