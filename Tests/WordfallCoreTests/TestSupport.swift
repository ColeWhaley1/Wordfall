import Foundation
@testable import WordfallCore

enum TestSupport {
    /// The real bundled word list, read straight from the repo.
    static let database: WordDatabase = {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Wordfall/Resources/words.json")
        let data = try! Data(contentsOf: url)
        return try! WordDatabase(jsonData: data)
    }()

    /// A tiny hand-made database for precise engine tests.
    static let tiny = WordDatabase(words: [
        word("stop"), word("post"), word("pots"), word("tops"),
        word("rate"), word("tear"), word("tare"),
        word("cat"), word("act"),
        word("cloud"),
    ])

    static func word(_ text: String, playable: Bool = true) -> Word {
        Word(word: text, length: text.count, difficulty: 1, frequency: 0.8, common: true, playable: playable)
    }

    static func dailyChallenge(_ words: [String]) -> DailyChallenge {
        DailyChallenge(
            dateKey: "2026-09-27",
            number: 270,
            seed: 1,
            words: words.map { DailyWord(word: $0, scrambled: Array(String($0.reversed()))) },
            lives: 3,
            baseFallDuration: 5
        )
    }
}

extension GameEngine {
    /// Types a whole answer on the keyboard.
    func typeWord(_ text: String) {
        for character in text { type(character) }
    }

    /// Ticks until a word is falling.
    func waitForWord(step: TimeInterval = 0.05, limit: Int = 200) {
        var steps = 0
        while activeWord == nil, status == .playing, steps < limit {
            tick(step)
            steps += 1
        }
    }
}
