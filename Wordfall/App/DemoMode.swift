#if DEBUG
import Foundation
import SwiftData

/// Debug-only launch arguments for recording App Store screenshots and
/// previews. The game plays itself through the normal input path (one tile
/// tap at a time), so everything on screen is the real game.
///
/// - `-demoAutoplay`: solves each word at a human pace.
/// - `-demoSolveCount N`: stops solving after N words, so the game ends.
/// - `-demoEquip <backgroundID> <lettersID>`: owns and equips those cosmetics.
enum DemoMode {
    private static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var autoplay: Bool { arguments.contains("-demoAutoplay") }

    static var solveLimit: Int? {
        guard let index = arguments.firstIndex(of: "-demoSolveCount"), index + 1 < arguments.count else { return nil }
        return Int(arguments[index + 1])
    }

    @MainActor
    static func applyCosmetics(in context: ModelContext) {
        guard let index = arguments.firstIndex(of: "-demoEquip"), index + 2 < arguments.count else { return }
        let inventory = Inventory.current(in: context)
        let background = arguments[index + 1]
        let letters = arguments[index + 2]
        for id in [background, letters] where !inventory.owns(id) {
            inventory.ownedRaw = (inventory.ownedRaw.split(separator: ",").map(String.init) + [id]).joined(separator: ",")
        }
        inventory.equippedBackgroundID = background
        inventory.equippedLettersID = letters
        try? context.save()
    }

    /// Plays `session` until it ends or the solve limit is reached.
    @MainActor
    static func play(_ session: GameSession) async {
        var solved = 0
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(100))
            let engine = session.engine
            guard engine.status == .playing, let word = engine.activeWord, engine.selection.isEmpty else { continue }
            if let limit = solveLimit, solved >= limit { continue }
            // Read the word first, then tap it out.
            try? await Task.sleep(for: .milliseconds(Int.random(in: 700...1500) + word.tiles.count * 60))
            var used = Set<Int>()
            for letter in word.word.uppercased() {
                guard engine.activeWord?.id == word.id, engine.status == .playing,
                      let tile = word.tiles.first(where: { !used.contains($0.id) && Character($0.letter.uppercased()) == letter })
                else { break }
                used.insert(tile.id)
                _ = engine.select(tileID: tile.id, via: .tap)
                try? await Task.sleep(for: .milliseconds(Int.random(in: 130...220)))
            }
            if engine.activeWord?.id != word.id { solved += 1 }
        }
    }
}
#endif
