import SwiftUI

/// The falling word as a floating card with a little personality: it tilts
/// gently as it falls, the letters bob, and it trembles in the danger zone.
struct FallingWordView: View {
    let word: FallingWord
    let tileSize: CGFloat
    let reducedMotion: Bool
    let dangerThreshold: Double

    private var inDanger: Bool { word.progress >= dangerThreshold }

    var body: some View {
        let progress = word.progress
        HStack(spacing: tileSize * 0.14) {
            ForEach(word.tiles) { tile in
                Text(String(tile.letter))
                    .font(.system(size: tileSize * 0.62, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: tileSize, height: tileSize * 1.1)
                    .offset(y: reducedMotion ? 0 : sin(progress * 18 + Double(tile.id) * 0.9) * 2.5)
            }
        }
        .padding(.horizontal, tileSize * 0.45)
        .padding(.vertical, tileSize * 0.35)
        .background(
            RoundedRectangle(cornerRadius: tileSize * 0.45, style: .continuous)
                .fill(Theme.cardGradient)
        )
        .overlay(
            RoundedRectangle(cornerRadius: tileSize * 0.45, style: .continuous)
                .strokeBorder(inDanger ? Theme.danger : .white.opacity(0.35), lineWidth: inDanger ? 3 : 1.5)
        )
        .shadow(color: (inDanger ? Theme.danger : Theme.cardTop).opacity(0.7), radius: inDanger ? 18 : 12)
        .rotationEffect(.degrees(reducedMotion ? 0 : sin(progress * 7) * 2.5))
        .offset(x: reducedMotion || !inDanger ? 0 : sin(progress * 260) * 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Falling word")
        .accessibilityValue(word.tiles.map { String($0.letter) }.joined(separator: " "))
    }
}
