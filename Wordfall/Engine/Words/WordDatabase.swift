import Foundation

enum WordDatabaseError: Error {
    case missingResource
}

/// In-memory index over the bundled word list. Built once at launch.
final class WordDatabase: Sendable {
    let words: [Word]
    private let accepted: Set<String>
    private let groups: [String: [String]]
    private let playableByLength: [Int: [Word]]

    init(words: [Word]) {
        self.words = words
        var accepted = Set<String>()
        var groups: [String: [String]] = [:]
        var playableByLength: [Int: [Word]] = [:]
        for entry in words {
            let text = entry.text
            accepted.insert(text)
            groups[AnagramService.signature(text), default: []].append(text)
            if entry.playable {
                playableByLength[entry.length, default: []].append(entry)
            }
        }
        self.accepted = accepted
        self.groups = groups
        self.playableByLength = playableByLength
    }

    convenience init(jsonData: Data) throws {
        let words = try JSONDecoder().decode([Word].self, from: jsonData)
        self.init(words: words)
    }

    /// Loads `words.json` from the given bundle.
    static func loadBundled(from bundle: Bundle = .main) throws -> WordDatabase {
        guard let url = bundle.url(forResource: "words", withExtension: "json") else {
            throw WordDatabaseError.missingResource
        }
        return try WordDatabase(jsonData: Data(contentsOf: url))
    }

    /// Whether the word is an accepted answer (case-insensitive).
    func contains(_ word: String) -> Bool {
        accepted.contains(word.uppercased())
    }

    /// Every accepted word made of exactly the same letters, including the word itself.
    func anagrams(of word: String) -> [String] {
        groups[AnagramService.signature(word)] ?? []
    }

    /// True when the word's letters spell exactly one accepted word.
    func hasSingleAnswer(_ word: String) -> Bool {
        anagrams(of: word).count <= 1
    }

    /// Playable words of one length, in database (alphabetical) order.
    func playableWords(length: Int) -> [Word] {
        playableByLength[length] ?? []
    }

    var playableLengths: [Int] {
        playableByLength.keys.sorted()
    }
}
