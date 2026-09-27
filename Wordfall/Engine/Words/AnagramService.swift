import Foundation

/// Anagram signatures: the letters of a word sorted alphabetically.
/// STOP, POST, POTS and TOPS all share the signature OPST.
enum AnagramService {
    static func signature(_ word: String) -> String {
        String(word.uppercased().filter(\.isLetter).sorted())
    }

    static func areAnagrams(_ lhs: String, _ rhs: String) -> Bool {
        signature(lhs) == signature(rhs)
    }
}
