import SwiftData
import SwiftUI

struct GameLaunch: Identifiable {
    let id = UUID()
    let configuration: GameConfiguration
}

enum HomeRoute: Hashable {
    case daily, stats, settings
}

struct HomeView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Query private var stats: [PlayerStats]
    @Query private var dailyResults: [DailyResult]

    @State private var launch: GameLaunch?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                VStack(spacing: 16) {
                    Spacer()
                    TitleView(reducedMotion: services.settings.reducedMotion)
                    if let best = stats.first?.highestScore, best > 0 {
                        Text("BEST \(NumberText.grouped(best))")
                            .font(.system(size: 16, weight: .heavy, design: .rounded))
                            .tracking(2)
                            .foregroundStyle(Theme.gold)
                    }
                    Spacer()

                    Button("PLAY") {
                        launch = GameLaunch(configuration: .endless)
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

                    NavigationLink("STATS", value: HomeRoute.stats)
                        .buttonStyle(.arcadeSecondary)

                    NavigationLink("SETTINGS", value: HomeRoute.settings)
                        .buttonStyle(.arcadeSecondary)

                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .navigationDestination(for: HomeRoute.self) { route in
                switch route {
                case .daily: DailyView()
                case .stats: StatsView()
                case .settings: SettingsView()
                }
            }
            .fullScreenCover(item: $launch) { launch in
                GameView(configuration: launch.configuration)
                    .environment(services)
                    .modelContext(modelContext)
            }
        }
    }

    private var playedToday: Bool {
        let key = DailyChallengeGenerator.dateKey(for: .now)
        return dailyResults.contains { $0.dateKey == key }
    }
}

/// WORD as bobbing tiles, then "fall".
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
            Text("fall")
                .font(Theme.display(54))
                .foregroundStyle(
                    LinearGradient(colors: [Theme.accent, Theme.cardBottom], startPoint: .leading, endPoint: .trailing)
                )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wordfall")
        .accessibilityAddTraits(.isHeader)
    }
}
