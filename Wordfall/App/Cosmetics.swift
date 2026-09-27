import SwiftUI

/// A colour that can be blended, since `Color.mix` needs iOS 18.
struct RGB: Equatable, Sendable {
    let r: Double
    let g: Double
    let b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    func mixed(with other: RGB, by t: Double) -> RGB {
        RGB(r + (other.r - r) * t, g + (other.g - g) * t, b + (other.b - b) * t)
    }

    var color: Color { Color(red: r, green: g, blue: b) }
}

/// A background: a series of top/bottom gradients the screen fades through as
/// the game gets harder. The first one is also used on the menus.
struct BackgroundTheme: Identifiable, Equatable, Sendable {
    struct Stop: Equatable, Sendable {
        let top: RGB
        let bottom: RGB
    }

    /// Levels of progress between one stop and the next.
    static let levelsPerStop = 4.0

    let id: String
    let name: String
    let price: Int
    let stops: [Stop]

    /// The gradient for a game `intensity` (see `GameEngine.intensity`),
    /// blended between the two nearest stops and holding at the last.
    func colors(at intensity: Double) -> (top: Color, bottom: Color) {
        let position = min(max(intensity / Self.levelsPerStop, 0), Double(stops.count - 1))
        let lower = Int(position.rounded(.down))
        let upper = min(lower + 1, stops.count - 1)
        let t = position - Double(lower)
        return (
            stops[lower].top.mixed(with: stops[upper].top, by: t).color,
            stops[lower].bottom.mixed(with: stops[upper].bottom, by: t).color
        )
    }
}

/// How the letter tiles and the falling word card look.
struct LetterTheme: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let price: Int
    let tileTop: RGB
    let tileBottom: RGB
    let cardTop: RGB
    let cardBottom: RGB
    let text: RGB
    var outlineOpacity = 0.35

    var tileGradient: LinearGradient {
        LinearGradient(colors: [tileTop.color, tileBottom.color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var cardGradient: LinearGradient {
        LinearGradient(colors: [cardTop.color, cardBottom.color], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Everything the shop sells. Ids are stored on disk, so never rename them.
enum CosmeticCatalog {
    static let backgrounds: [BackgroundTheme] = [
        BackgroundTheme(id: "nightfall", name: "Nightfall", price: 0, stops: [
            .init(top: RGB(0.05, 0.06, 0.16), bottom: RGB(0.12, 0.04, 0.22)),   // midnight violet
            .init(top: RGB(0.02, 0.09, 0.18), bottom: RGB(0.02, 0.19, 0.26)),   // deep teal
            .init(top: RGB(0.03, 0.11, 0.09), bottom: RGB(0.05, 0.21, 0.12)),   // forest
            .init(top: RGB(0.14, 0.08, 0.03), bottom: RGB(0.30, 0.13, 0.04)),   // amber dusk
            .init(top: RGB(0.17, 0.03, 0.06), bottom: RGB(0.33, 0.04, 0.10)),   // crimson
            .init(top: RGB(0.09, 0.00, 0.10), bottom: RGB(0.02, 0.00, 0.03)),   // void
        ]),
        BackgroundTheme(id: "ocean", name: "Deep Ocean", price: 400, stops: [
            .init(top: RGB(0.02, 0.14, 0.24), bottom: RGB(0.03, 0.27, 0.36)),
            .init(top: RGB(0.01, 0.10, 0.22), bottom: RGB(0.02, 0.18, 0.34)),
            .init(top: RGB(0.01, 0.06, 0.16), bottom: RGB(0.03, 0.10, 0.26)),
            .init(top: RGB(0.01, 0.03, 0.10), bottom: RGB(0.04, 0.05, 0.18)),
            .init(top: RGB(0.00, 0.01, 0.05), bottom: RGB(0.02, 0.02, 0.08)),
        ]),
        BackgroundTheme(id: "sunset", name: "Sunset", price: 600, stops: [
            .init(top: RGB(0.16, 0.10, 0.30), bottom: RGB(0.40, 0.16, 0.30)),
            .init(top: RGB(0.24, 0.08, 0.24), bottom: RGB(0.48, 0.18, 0.18)),
            .init(top: RGB(0.26, 0.07, 0.12), bottom: RGB(0.50, 0.22, 0.06)),
            .init(top: RGB(0.18, 0.04, 0.10), bottom: RGB(0.34, 0.08, 0.06)),
            .init(top: RGB(0.06, 0.02, 0.08), bottom: RGB(0.12, 0.03, 0.06)),
        ]),
        BackgroundTheme(id: "aurora", name: "Aurora", price: 900, stops: [
            .init(top: RGB(0.02, 0.08, 0.12), bottom: RGB(0.04, 0.26, 0.20)),
            .init(top: RGB(0.03, 0.06, 0.16), bottom: RGB(0.08, 0.30, 0.28)),
            .init(top: RGB(0.06, 0.04, 0.20), bottom: RGB(0.18, 0.12, 0.36)),
            .init(top: RGB(0.10, 0.03, 0.18), bottom: RGB(0.30, 0.08, 0.30)),
            .init(top: RGB(0.04, 0.02, 0.08), bottom: RGB(0.10, 0.03, 0.14)),
        ]),
        BackgroundTheme(id: "ember", name: "Ember", price: 1_200, stops: [
            .init(top: RGB(0.08, 0.05, 0.04), bottom: RGB(0.20, 0.09, 0.05)),
            .init(top: RGB(0.12, 0.05, 0.03), bottom: RGB(0.32, 0.12, 0.03)),
            .init(top: RGB(0.16, 0.04, 0.02), bottom: RGB(0.42, 0.10, 0.02)),
            .init(top: RGB(0.14, 0.02, 0.02), bottom: RGB(0.36, 0.03, 0.03)),
            .init(top: RGB(0.06, 0.01, 0.01), bottom: RGB(0.14, 0.01, 0.01)),
        ]),
        BackgroundTheme(id: "synthwave", name: "Synthwave", price: 2_000, stops: [
            .init(top: RGB(0.08, 0.02, 0.18), bottom: RGB(0.36, 0.04, 0.34)),
            .init(top: RGB(0.04, 0.03, 0.22), bottom: RGB(0.10, 0.18, 0.42)),
            .init(top: RGB(0.14, 0.02, 0.22), bottom: RGB(0.46, 0.06, 0.30)),
            .init(top: RGB(0.02, 0.10, 0.20), bottom: RGB(0.04, 0.34, 0.38)),
            .init(top: RGB(0.12, 0.00, 0.14), bottom: RGB(0.30, 0.00, 0.20)),
        ]),
    ]

    static let letters: [LetterTheme] = [
        LetterTheme(id: "classic", name: "Classic", price: 0,
                    tileTop: RGB(1.0, 0.55, 0.26), tileBottom: RGB(0.96, 0.25, 0.52),
                    cardTop: RGB(0.36, 0.30, 0.95), cardBottom: RGB(0.62, 0.22, 0.88),
                    text: RGB(1, 1, 1)),
        LetterTheme(id: "glacier", name: "Glacier", price: 300,
                    tileTop: RGB(0.55, 0.90, 1.0), tileBottom: RGB(0.20, 0.52, 0.96),
                    cardTop: RGB(0.10, 0.36, 0.70), cardBottom: RGB(0.18, 0.62, 0.86),
                    text: RGB(1, 1, 1)),
        LetterTheme(id: "lime", name: "Lime Fizz", price: 500,
                    tileTop: RGB(0.78, 1.0, 0.36), tileBottom: RGB(0.20, 0.80, 0.42),
                    cardTop: RGB(0.56, 0.94, 0.44), cardBottom: RGB(0.24, 0.74, 0.40),
                    text: RGB(0.04, 0.18, 0.10)),
        LetterTheme(id: "candy", name: "Candy", price: 700,
                    tileTop: RGB(1.0, 0.72, 0.86), tileBottom: RGB(0.90, 0.40, 0.78),
                    cardTop: RGB(0.98, 0.52, 0.66), cardBottom: RGB(0.72, 0.42, 0.96),
                    text: RGB(1, 1, 1)),
        LetterTheme(id: "parchment", name: "Parchment", price: 900,
                    tileTop: RGB(0.98, 0.94, 0.84), tileBottom: RGB(0.88, 0.78, 0.60),
                    cardTop: RGB(0.94, 0.88, 0.74), cardBottom: RGB(0.80, 0.68, 0.50),
                    text: RGB(0.24, 0.16, 0.10), outlineOpacity: 0.5),
        LetterTheme(id: "midnight", name: "Neon Night", price: 1_500,
                    tileTop: RGB(0.10, 0.10, 0.14), tileBottom: RGB(0.02, 0.02, 0.05),
                    cardTop: RGB(0.06, 0.06, 0.10), cardBottom: RGB(0.00, 0.00, 0.02),
                    text: RGB(0.29, 0.98, 0.90), outlineOpacity: 0.7),
        LetterTheme(id: "gold", name: "24 Karat", price: 3_000,
                    tileTop: RGB(1.0, 0.90, 0.46), tileBottom: RGB(0.86, 0.58, 0.10),
                    cardTop: RGB(1.0, 0.84, 0.40), cardBottom: RGB(0.82, 0.56, 0.12),
                    text: RGB(0.30, 0.18, 0.00), outlineOpacity: 0.6),
    ]

    static let defaultBackground = backgrounds[0]
    static let defaultLetters = letters[0]

    static func background(id: String?) -> BackgroundTheme {
        backgrounds.first { $0.id == id } ?? defaultBackground
    }

    static func letters(id: String?) -> LetterTheme {
        letters.first { $0.id == id } ?? defaultLetters
    }

    /// Free items every player owns from the start.
    static var starterIDs: Set<String> {
        Set((backgrounds.map { ($0.id, $0.price) } + letters.map { ($0.id, $0.price) }).filter { $0.1 == 0 }.map(\.0))
    }
}

/// The cosmetics the player has equipped, shared through the environment.
struct EquippedCosmetics: Equatable, Sendable {
    var background = CosmeticCatalog.defaultBackground
    var letters = CosmeticCatalog.defaultLetters
}

private struct EquippedCosmeticsKey: EnvironmentKey {
    static let defaultValue = EquippedCosmetics()
}

extension EnvironmentValues {
    var cosmetics: EquippedCosmetics {
        get { self[EquippedCosmeticsKey.self] }
        set { self[EquippedCosmeticsKey.self] = newValue }
    }
}

/// The equipped background. In a game, `intensity` fades it through the
/// theme's colours as the player gets further.
struct ThemedBackground: View {
    var intensity: Double = 0
    var theme: BackgroundTheme?

    @Environment(\.cosmetics) private var cosmetics

    var body: some View {
        let colors = (theme ?? cosmetics.background).colors(at: intensity)
        LinearGradient(colors: [colors.top, colors.bottom], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }
}
