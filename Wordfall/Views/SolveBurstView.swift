import SwiftUI

/// The payoff for a correct word, played in about half a second:
/// the word snaps together and pops, sparks fly out, and the points float up.
struct SolveBurstView: View {
    let burst: SolveBurst
    let reducedMotion: Bool

    @State private var exploded = false
    @State private var floated = false

    private let sparkCount = 16

    var body: some View {
        ZStack {
            if !reducedMotion {
                ForEach(0..<sparkCount, id: \.self) { index in
                    let angle = Double(index) / Double(sparkCount) * 2 * .pi + Double(index % 3) * 0.2
                    let distance: CGFloat = 70 + CGFloat(index % 4) * 18
                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                        .font(.system(size: index.isMultiple(of: 2) ? 16 : 7, weight: .bold))
                        .foregroundStyle(index.isMultiple(of: 3) ? Theme.gold : Theme.accent)
                        .offset(
                            x: exploded ? CGFloat(cos(angle)) * distance : 0,
                            y: exploded ? CGFloat(sin(angle)) * distance : 0
                        )
                        .opacity(exploded ? 0 : 1)
                }
            }

            Text("✨ \(burst.word) ✨")
                .font(Theme.display(34))
                .foregroundStyle(.white)
                .shadow(color: Theme.success.opacity(0.9), radius: 12)
                .scaleEffect(exploded ? 1.35 : 0.9)
                .opacity(floated ? 0 : 1)

            VStack(spacing: 2) {
                Text("+\(NumberText.grouped(burst.points))")
                    .font(Theme.display(28))
                    .foregroundStyle(Theme.gold)
                if burst.combo >= 2 {
                    Text("🔥 \(burst.combo) COMBO")
                        .font(Theme.display(18))
                        .foregroundStyle(.orange)
                }
            }
            .offset(y: floated ? -90 : 40)
            .opacity(floated ? 0 : 1)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Solved \(burst.word), plus \(burst.points) points")
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) {
                exploded = true
            }
            withAnimation(.easeIn(duration: 0.4).delay(0.35)) {
                floated = true
            }
        }
    }
}

/// Milestone, level-up, PERFECT and MISS banners.
struct BannerView: View {
    let banner: Banner

    var body: some View {
        Text(banner.text)
            .font(Theme.display(banner.style == .miss ? 26 : 34))
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.8), radius: 14)
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(.black.opacity(0.35), in: Capsule())
            .accessibilityAddTraits(.isStaticText)
    }

    private var color: Color {
        switch banner.style {
        case .milestone: return .orange
        case .level: return Theme.accent
        case .perfect: return Theme.gold
        case .miss: return Theme.danger
        }
    }
}
