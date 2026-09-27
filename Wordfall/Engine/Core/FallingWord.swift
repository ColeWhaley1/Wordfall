import Foundation

/// A word on its way down, with its own gameplay state.
struct FallingWord: Identifiable, Equatable, Sendable {
    let id: UUID
    /// The intended answer, uppercase. Any anagram in the database also solves it.
    let word: String
    /// The scrambled letters, in display order.
    let tiles: [LetterTile]
    let fallDuration: TimeInterval
    var elapsed: TimeInterval = 0
    /// Lane for future multi-word play. Always 0 in v1.
    var lane: Int = 0
    var isSelected = true
    var isSolved = false

    init(id: UUID = UUID(), word: String, scrambled: [Character], fallDuration: TimeInterval, lane: Int = 0) {
        self.id = id
        self.word = word.uppercased()
        self.tiles = scrambled.enumerated().map { LetterTile(id: $0.offset, letter: $0.element) }
        self.fallDuration = fallDuration
        self.lane = lane
    }

    /// 0 at the top, 1 at the danger line.
    var progress: Double {
        guard fallDuration > 0 else { return 1 }
        return min(max(elapsed / fallDuration, 0), 1)
    }

    var scrambledText: String {
        String(tiles.map(\.letter))
    }

    var remainingTime: TimeInterval {
        max(0, fallDuration - elapsed)
    }
}
