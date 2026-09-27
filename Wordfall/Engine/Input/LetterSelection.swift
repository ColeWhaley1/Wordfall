import Foundation

/// How a letter was chosen. Every method produces the same `LetterSelection`,
/// so validation never cares how the player got there.
enum InputMethod: String, Codable, Sendable {
    case keyboard
    case tap
    case swipe
}

/// One scrambled letter of the active word. `id` is its position in the
/// scrambled word, which stays stable while letters are selected.
struct LetterTile: Identifiable, Hashable, Sendable {
    let id: Int
    let letter: Character
}

/// The ordered tiles the player has picked so far.
struct LetterSelection: Equatable, Sendable {
    private(set) var tileIDs: [Int] = []

    var isEmpty: Bool { tileIDs.isEmpty }
    var count: Int { tileIDs.count }

    func contains(_ tileID: Int) -> Bool {
        tileIDs.contains(tileID)
    }

    mutating func append(_ tileID: Int) {
        guard !contains(tileID) else { return }
        tileIDs.append(tileID)
    }

    @discardableResult
    mutating func removeLast() -> Int? {
        tileIDs.popLast()
    }

    mutating func remove(_ tileID: Int) {
        tileIDs.removeAll { $0 == tileID }
    }

    mutating func removeAll() {
        tileIDs.removeAll()
    }

    func text(in tiles: [LetterTile]) -> String {
        String(tileIDs.compactMap { id in tiles.first { $0.id == id }?.letter })
    }
}
