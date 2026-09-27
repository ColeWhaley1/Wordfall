import SwiftUI

/// The scrambled letters as big tiles near the bottom of the screen.
/// Tap a tile to add or remove it, or drag across tiles to spell a word.
/// Hit areas are much larger than the visible tiles so swipes feel forgiving.
struct LetterPadView: View {
    let word: FallingWord
    let selection: LetterSelection
    let swipeEnabled: Bool
    let reducedMotion: Bool
    let onSelect: (Int, InputMethod) -> Void
    let onDeselect: (Int) -> Void
    let onToggle: (Int) -> Void

    @State private var drag = DragTracker()

    private let spacing: CGFloat = 10

    var body: some View {
        GeometryReader { proxy in
            let layout = PadLayout(count: word.tiles.count, size: proxy.size, spacing: spacing)
            ZStack {
                SwipePath(points: drag.swipeTiles.compactMap { layout.center(of: $0) }, finger: drag.isSwiping ? drag.location : nil)
                    .stroke(
                        Theme.accent.opacity(0.85),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: Theme.accent.opacity(0.8), radius: 8)
                    .allowsHitTesting(false)

                ForEach(word.tiles) { tile in
                    let isSelected = selection.contains(tile.id)
                    LetterTileView(letter: tile.letter, size: layout.tileSize, isSelected: isSelected)
                        .scaleEffect(scale(for: tile.id, isSelected: isSelected))
                        .animation(reducedMotion ? nil : .spring(response: 0.22, dampingFraction: 0.55), value: isSelected)
                        .position(layout.center(of: tile.id) ?? .zero)
                        .accessibilityElement()
                        .accessibilityLabel(String(tile.letter))
                        .accessibilityValue(isSelected ? "selected" : "")
                        .accessibilityAddTraits(.isButton)
                        .accessibilityAction { onToggle(tile.id) }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(dragGesture(layout: layout))
        }
        .onChange(of: word.id) {
            drag = DragTracker()
        }
    }

    private func scale(for id: Int, isSelected: Bool) -> CGFloat {
        if drag.swipeTiles.last == id, drag.isSwiping { return 1.12 }
        return isSelected ? 0.88 : 1
    }

    private func dragGesture(layout: PadLayout) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if !drag.isActive {
                    drag = DragTracker()
                    drag.isActive = true
                    drag.startTile = layout.tile(near: value.startLocation, radius: layout.tapRadius)
                }
                drag.location = value.location

                let moved = hypot(value.translation.width, value.translation.height)
                guard swipeEnabled, moved > 14 || drag.isSwiping else { return }
                if !drag.isSwiping {
                    drag.isSwiping = true
                    if let start = drag.startTile, !selection.contains(start) {
                        drag.swipeTiles.append(start)
                        onSelect(start, .swipe)
                    }
                }
                guard let tile = layout.tile(near: value.location, radius: layout.swipeRadius) else { return }
                if drag.swipeTiles.count >= 2, tile == drag.swipeTiles[drag.swipeTiles.count - 2] {
                    // Sliding back onto the previous letter undoes the last one.
                    let last = drag.swipeTiles.removeLast()
                    onDeselect(last)
                } else if !selection.contains(tile), !drag.swipeTiles.contains(tile) {
                    drag.swipeTiles.append(tile)
                    onSelect(tile, .swipe)
                }
            }
            .onEnded { _ in
                if !drag.isSwiping, let start = drag.startTile {
                    onToggle(start)
                }
                drag = DragTracker()
            }
    }
}

private struct DragTracker {
    var isActive = false
    var isSwiping = false
    var startTile: Int?
    var swipeTiles: [Int] = []
    var location: CGPoint = .zero
}

/// Tile positions: one row for short words, two rows for longer ones.
struct PadLayout {
    let count: Int
    let size: CGSize
    let spacing: CGFloat

    var rows: Int { count > 5 ? 2 : 1 }
    var perRow: Int { Int((Double(count) / Double(rows)).rounded(.up)) }

    var tileSize: CGFloat {
        let byWidth = (size.width - spacing * CGFloat(perRow - 1) - 24) / CGFloat(max(perRow, 1))
        let byHeight = (size.height - spacing * CGFloat(rows - 1) - 12) / CGFloat(rows)
        return max(28, min(72, byWidth, byHeight))
    }

    /// First touch: generous, so a tap anywhere near a tile counts.
    var tapRadius: CGFloat { max(44, tileSize * 0.8) }
    /// During a swipe: smaller, so passing near a diagonal neighbour doesn't grab it.
    var swipeRadius: CGFloat { max(30, tileSize * 0.6) }

    func center(of id: Int) -> CGPoint? {
        guard id >= 0, id < count else { return nil }
        let row = id / perRow
        let column = id % perRow
        let itemsInRow = row == rows - 1 ? count - perRow * (rows - 1) : perRow
        let rowWidth = CGFloat(itemsInRow) * tileSize + CGFloat(itemsInRow - 1) * spacing
        let totalHeight = CGFloat(rows) * tileSize + CGFloat(rows - 1) * spacing
        let x = (size.width - rowWidth) / 2 + tileSize / 2 + CGFloat(column) * (tileSize + spacing)
        let y = (size.height - totalHeight) / 2 + tileSize / 2 + CGFloat(row) * (tileSize + spacing)
        return CGPoint(x: x, y: y)
    }

    func tile(near point: CGPoint, radius: CGFloat) -> Int? {
        var best: (id: Int, distance: CGFloat)?
        for id in 0..<count {
            guard let center = center(of: id) else { continue }
            let distance = hypot(center.x - point.x, center.y - point.y)
            if distance <= radius, distance < (best?.distance ?? .infinity) {
                best = (id, distance)
            }
        }
        return best?.id
    }
}

private struct SwipePath: Shape {
    let points: [CGPoint]
    let finger: CGPoint?

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        if let finger {
            path.addLine(to: finger)
        }
        return path
    }
}

/// A single letter tile. Selected tiles fade back; their letter moves to the answer.
struct LetterTileView: View {
    let letter: Character
    let size: CGFloat
    var isSelected = false
    /// Overrides the equipped theme, e.g. for shop previews.
    var theme: LetterTheme?

    @Environment(\.cosmetics) private var cosmetics

    var body: some View {
        let theme = theme ?? cosmetics.letters
        Text(String(letter))
            .font(.system(size: size * 0.52, weight: .heavy, design: .rounded))
            .foregroundStyle(isSelected ? Color.white.opacity(0.35) : theme.text.color)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Color.white.opacity(0.08)) : AnyShapeStyle(theme.tileGradient))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                    .strokeBorder(.white.opacity(isSelected ? 0.15 : theme.outlineOpacity), lineWidth: 1.5)
            )
            .shadow(color: isSelected ? .clear : theme.tileBottom.color.opacity(0.45), radius: 8, y: 4)
    }
}
