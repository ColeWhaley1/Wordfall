import SwiftData
import SwiftUI

struct GameLaunch: Identifiable {
    let id = UUID()
    let configuration: GameConfiguration
}

enum HomeRoute: Hashable {
    case daily, shop, stats, settings
}

struct HomeView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Environment(\.cosmetics) private var cosmetics
    @Query private var stats: [PlayerStats]
    @Query private var dailyResults: [DailyResult]
    @Query private var inventories: [Inventory]

    @State private var launch: GameLaunch?

    var body: some View {
        NavigationStack {
            ZStack {
                ThemedBackground()
                VStack(spacing: 14) {
                    HStack {
                        Spacer()
                        NavigationLink(value: HomeRoute.shop) {
                            CoinBadge(coins: inventories.first?.coins ?? 0)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the shop")
                    }
                    .padding(.top, 8)
                    Spacer()
                    TitleView(reducedMotion: services.settings.reducedMotion)
                    if let best = stats.first?.highestScore, best > 0 {
                        Text("BEST \(NumberText.grouped(best))")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Theme.gold)
                    }
                    Spacer()

                    DifficultyPicker(selection: Bindable(services.settings).difficulty)

                    Button("PLAY") {
                        launch = GameLaunch(configuration: .endless(services.settings.difficulty))
                    }
                    .buttonStyle(.arcade)

                    NavigationLink(value: HomeRoute.daily) {
                        HStack(spacing: 8) {
                            Text("DAILY")
                            if playedToday {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Theme.success)
                                    .accessibilityLabel("played today")
                            }
                        }
                    }
                    .buttonStyle(.arcadeSecondary)

                    NavigationLink("SHOP", value: HomeRoute.shop)
                        .buttonStyle(.arcadeSecondary)

                    HStack(spacing: 12) {
                        NavigationLink(value: HomeRoute.stats) {
                            Label("STATS", systemImage: "chart.bar.fill")
                                .labelStyle(.titleOnly)
                        }
                        NavigationLink(value: HomeRoute.settings) {
                            Image(systemName: "gearshape.fill")
                                .accessibilityLabel("Settings")
                        }
                        .frame(width: 84)
                    }
                    .buttonStyle(.arcadeSecondary)
                    .frame(maxWidth: 280)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .daily: DailyView()
                case .shop: ShopView()
                case .stats: StatsView()
                case .settings: SettingsView()
                }
            }
            .fullScreenCover(item: $launch) { launch in
                GameView(configuration: launch.configuration)
                    .environment(services)
                    .environment(\.cosmetics, cosmetics)
                    .modelContext(modelContext)
            }
        }
    }

    private var playedToday: Bool {
        let key = DailyChallengeGenerator.dateKey(for: .now)
        return dailyResults.contains { $0.dateKey == key }
    }
}

/// Endless difficulty chips, with what the choice means for time and points.
private struct DifficultyPicker: View {
    @Binding var selection: GameDifficulty

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                ForEach(GameDifficulty.allCases) { difficulty in
                    let isSelected = difficulty == selection
                    Button {
                        selection = difficulty
                    } label: {
                        Text(difficulty.title)
                            .font(.system(size: 13, weight: .heavy, design: .rounded))
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? .black : .white.opacity(0.8))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                Capsule().fill(isSelected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.panel))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .frame(maxWidth: 300)
            HStack(spacing: 6) {
                Text(selection.summary)
                Text("·")
                Text(selection.pointsLabel)
                    .foregroundStyle(selection.pointsMultiplier < 1 ? Theme.danger : Theme.gold)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        }
        .animation(.snappy(duration: 0.2), value: selection)
    }
}

/// Coin balance, used on the home screen, the shop and the game-over screen.
struct CoinBadge: View {
    let coins: Int
    var size: CGFloat = 16

    var body: some View {
        HStack(spacing: 6) {
            CoinIcon(size: size + 2)
            Text(NumberText.grouped(coins))
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(Theme.panel, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.4), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(coins) coins")
    }
}

struct CoinIcon: View {
    var size: CGFloat = 18

    var body: some View {
        Image(systemName: "centsign.circle.fill")
            .font(.system(size: size, weight: .bold))
            .symbolRenderingMode(.palette)
            .foregroundStyle(Color(red: 0.45, green: 0.3, blue: 0.0), Theme.gold)
            .accessibilityHidden(true)
    }
}

/// WORD as bobbing tiles, then "fallout".
private struct TitleView: View {
    let reducedMotion: Bool
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(Array("WORD".enumerated()), id: \.offset) { index, letter in
                    let tile = LetterTileView(letter: letter, size: 58)
                    if reducedMotion || systemReduceMotion {
                        tile
                    } else {
                        tile.phaseAnimator([false, true]) { view, up in
                            view
                                .offset(y: up ? -5 : 5)
                                .rotationEffect(.degrees(up ? -3 : 3))
                        } animation: { _ in
                            .easeInOut(duration: 1.1 + Double(index) * 0.17)
                        }
                    }
                }
            }
            Text("fallout")
                .font(Theme.display(54))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(
                    LinearGradient(colors: [Theme.accent, Theme.cardBottom], startPoint: .leading, endPoint: .trailing)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Word Fallout")
        .accessibilityAddTraits(.isHeader)
    }
}
