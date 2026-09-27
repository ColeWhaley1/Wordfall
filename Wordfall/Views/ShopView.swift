import SwiftData
import SwiftUI

/// Spend coins on backgrounds and letter themes. Tap something you own to
/// equip it; tap something new to buy it (and equip it straight away).
struct ShopView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var inventories: [Inventory]

    @State private var pending: PendingPurchase?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        let inventory = inventories.first
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(spacing: 20) {
                    Text("SHOP")
                        .font(Theme.display(44))
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    CoinBadge(coins: inventory?.coins ?? 0, size: 22)
                        .animation(.snappy, value: inventory?.coins)

                    Text("Earn coins by scoring points. Harder difficulties pay much more.")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                        .multilineTextAlignment(.center)

                    section("BACKGROUNDS", caption: "Fades through these colors as the words get harder") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(CosmeticCatalog.backgrounds) { theme in
                                ShopItemCard(
                                    name: theme.name,
                                    price: theme.price,
                                    state: state(id: theme.id, price: theme.price, equippedID: inventory?.equippedBackgroundID ?? CosmeticCatalog.defaultBackground.id, inventory: inventory)
                                ) {
                                    BackgroundPreview(theme: theme)
                                } action: {
                                    select(id: theme.id, name: theme.name, price: theme.price, kind: .background)
                                }
                            }
                        }
                    }

                    section("LETTER TILES", caption: "The falling word and the letter pad") {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(CosmeticCatalog.letters) { theme in
                                ShopItemCard(
                                    name: theme.name,
                                    price: theme.price,
                                    state: state(id: theme.id, price: theme.price, equippedID: inventory?.equippedLettersID ?? CosmeticCatalog.defaultLetters.id, inventory: inventory)
                                ) {
                                    LetterPreview(theme: theme)
                                } action: {
                                    select(id: theme.id, name: theme.name, price: theme.price, kind: .letters)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            _ = Inventory.current(in: modelContext)
        }
        .confirmationDialog(
            pending.map { "Buy \($0.name) for \(NumberText.grouped($0.price)) coins?" } ?? "",
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            titleVisibility: .visible,
            presenting: pending
        ) { purchase in
            Button("Buy and equip") { buy(purchase) }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func section<Content: View>(_ title: String, caption: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.8))
                Text(caption)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            content()
        }
    }

    private func state(id: String, price: Int, equippedID: String, inventory: Inventory?) -> ShopItemState {
        if id == equippedID { return .equipped }
        if price == 0 || inventory?.owns(id) == true { return .owned }
        return (inventory?.coins ?? 0) >= price ? .affordable : .tooExpensive
    }

    private func select(id: String, name: String, price: Int, kind: PendingPurchase.Kind) {
        let inventory = Inventory.current(in: modelContext)
        if inventory.owns(id) {
            equip(id, kind: kind, in: inventory)
        } else if inventory.coins >= price {
            pending = PendingPurchase(id: id, name: name, price: price, kind: kind)
        }
    }

    private func buy(_ purchase: PendingPurchase) {
        let inventory = Inventory.current(in: modelContext)
        guard inventory.buy(purchase.id, price: purchase.price) else { return }
        equip(purchase.id, kind: purchase.kind, in: inventory)
    }

    private func equip(_ id: String, kind: PendingPurchase.Kind, in inventory: Inventory) {
        switch kind {
        case .background: inventory.equippedBackgroundID = id
        case .letters: inventory.equippedLettersID = id
        }
        try? modelContext.save()
    }
}

private struct PendingPurchase: Identifiable {
    enum Kind { case background, letters }
    let id: String
    let name: String
    let price: Int
    let kind: Kind
}

private enum ShopItemState {
    case equipped, owned, affordable, tooExpensive
}

private struct ShopItemCard<Preview: View>: View {
    let name: String
    let price: Int
    let state: ShopItemState
    @ViewBuilder let preview: Preview
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                preview
                    .frame(height: 84)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(name)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                status
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .frame(height: 18)
            }
            .padding(10)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(state == .equipped ? Theme.accent : .white.opacity(0.12), lineWidth: state == .equipped ? 2.5 : 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityValue(accessibilityValue)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder private var status: some View {
        switch state {
        case .equipped:
            Label("EQUIPPED", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.accent)
        case .owned:
            Text("EQUIP")
                .foregroundStyle(.white.opacity(0.8))
        case .affordable, .tooExpensive:
            HStack(spacing: 4) {
                CoinIcon(size: 14)
                Text(NumberText.grouped(price))
                    .monospacedDigit()
                    .foregroundStyle(state == .affordable ? Theme.gold : .white.opacity(0.6))
            }
        }
    }

    private var accessibilityValue: String {
        switch state {
        case .equipped: "Equipped"
        case .owned: "Owned. Double tap to equip"
        case .affordable: "\(price) coins. Double tap to buy"
        case .tooExpensive: "\(price) coins. Not enough coins yet"
        }
    }
}

/// Every stop of the background side by side, so the fade is visible.
private struct BackgroundPreview: View {
    let theme: BackgroundTheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(theme.stops.enumerated()), id: \.offset) { _, stop in
                LinearGradient(colors: [stop.top.color, stop.bottom.color], startPoint: .top, endPoint: .bottom)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .heavy))
                .foregroundStyle(.white.opacity(0.5))
                .padding(6)
        }
    }
}

/// A mini falling-word card above a row of pad tiles.
private struct LetterPreview: View {
    let theme: LetterTheme

    var body: some View {
        VStack(spacing: 6) {
            Text("W O R D")
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(theme.text.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.cardGradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            HStack(spacing: 5) {
                ForEach(Array("ABC"), id: \.self) { letter in
                    LetterTileView(letter: letter, size: 30, theme: theme)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.25))
    }
}
