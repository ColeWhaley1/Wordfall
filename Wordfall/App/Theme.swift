import SwiftUI

/// Bright arcade look on a dark background.
enum Theme {
    static let backgroundTop = Color(red: 0.05, green: 0.06, blue: 0.16)
    static let backgroundBottom = Color(red: 0.12, green: 0.04, blue: 0.22)
    static let accent = Color(red: 0.29, green: 0.86, blue: 0.98)
    static let gold = Color(red: 1.0, green: 0.80, blue: 0.25)
    static let danger = Color(red: 1.0, green: 0.27, blue: 0.38)
    static let success = Color(red: 0.36, green: 0.95, blue: 0.56)
    static let tileTop = Color(red: 1.0, green: 0.55, blue: 0.26)
    static let tileBottom = Color(red: 0.96, green: 0.25, blue: 0.52)
    static let cardTop = Color(red: 0.36, green: 0.30, blue: 0.95)
    static let cardBottom = Color(red: 0.62, green: 0.22, blue: 0.88)
    static let panel = Color.white.opacity(0.08)

    static var background: LinearGradient {
        LinearGradient(colors: [backgroundTop, backgroundBottom], startPoint: .top, endPoint: .bottom)
    }

    static var tileGradient: LinearGradient {
        LinearGradient(colors: [tileTop, tileBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static var cardGradient: LinearGradient {
        LinearGradient(colors: [cardTop, cardBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func display(_ size: CGFloat) -> Font {
        .system(size: size, weight: .black, design: .rounded)
    }
}

/// Big rounded button used on the home and game-over screens.
struct ArcadeButtonStyle: ButtonStyle {
    var fill: AnyShapeStyle = AnyShapeStyle(Theme.tileGradient)
    var foreground: Color = .white

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.display(22))
            .foregroundStyle(foreground)
            .frame(maxWidth: 280)
            .padding(.vertical, 16)
            .background(fill, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            )
            .shadow(color: Theme.tileBottom.opacity(0.35), radius: 12, y: 6)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == ArcadeButtonStyle {
    static var arcade: ArcadeButtonStyle { ArcadeButtonStyle() }
    static var arcadeSecondary: ArcadeButtonStyle {
        ArcadeButtonStyle(fill: AnyShapeStyle(Theme.panel))
    }
}

/// Horizontal shake driven by an incrementing counter.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 10
    var shakes: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = amount * sin(animatableData * .pi * shakes * 2)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
