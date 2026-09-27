import Foundation
import SwiftData

/// The player's coins and cosmetics. There is a single row, created on first use.
@Model
final class Inventory {
    var coins: Int = 0
    var lifetimeCoins: Int = 0
    /// Comma-separated ids of every cosmetic bought (free ones are implied).
    var ownedRaw: String = ""
    var equippedBackgroundID: String = CosmeticCatalog.defaultBackground.id
    var equippedLettersID: String = CosmeticCatalog.defaultLetters.id

    init() {}

    var owned: Set<String> {
        CosmeticCatalog.starterIDs.union(ownedRaw.split(separator: ",").map(String.init))
    }

    func owns(_ id: String) -> Bool {
        owned.contains(id)
    }

    func earn(_ amount: Int) {
        guard amount > 0 else { return }
        coins += amount
        lifetimeCoins += amount
    }

    /// Spends the coins and adds the item. Returns false if it can't be afforded.
    @discardableResult
    func buy(_ id: String, price: Int) -> Bool {
        guard !owns(id) else { return true }
        guard coins >= price else { return false }
        coins -= price
        ownedRaw = (ownedRaw.split(separator: ",").map(String.init) + [id]).joined(separator: ",")
        return true
    }

    var equipped: EquippedCosmetics {
        EquippedCosmetics(
            background: CosmeticCatalog.background(id: equippedBackgroundID),
            letters: CosmeticCatalog.letters(id: equippedLettersID)
        )
    }

    @MainActor
    static func current(in context: ModelContext) -> Inventory {
        if let existing = try? context.fetch(FetchDescriptor<Inventory>()).first {
            return existing
        }
        let inventory = Inventory()
        context.insert(inventory)
        return inventory
    }
}
