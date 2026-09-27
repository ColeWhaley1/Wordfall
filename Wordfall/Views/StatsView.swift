import SwiftData
import SwiftUI

struct StatsView: View {
    @Query private var stats: [PlayerStats]
    @Query(sort: \GameResult.date, order: .reverse) private var games: [GameResult]

    var body: some View {
        ZStack {
            ThemedBackground()
            ScrollView {
                VStack(spacing: 20) {
                    Text("YOUR STATS")
                        .font(Theme.display(36))
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    let current = stats.first
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatTile(value: NumberText.grouped(current?.highestScore ?? 0), label: "HIGH SCORE")
                        StatTile(value: "\(current?.highestCombo ?? 0)", label: "BEST COMBO")
                        StatTile(value: "\(current?.highestLevel ?? 1)", label: "BEST LEVEL")
                        StatTile(value: NumberText.grouped(current?.totalWordsSolved ?? 0), label: "WORDS SOLVED")
                        StatTile(value: "\(current?.totalGames ?? 0)", label: "GAMES")
                        StatTile(value: "\(current?.totalPerfects ?? 0)", label: "PERFECTS")
                        StatTile(value: fastestText(current?.fastestSolve), label: "FASTEST SOLVE")
                        StatTile(value: current?.longestWord.isEmpty == false ? current!.longestWord : "—", label: "LONGEST WORD")
                        StatTile(value: "\(current?.longestDailyStreak ?? 0)", label: "BEST DAILY STREAK")
                        StatTile(value: accuracyText(current), label: "ACCURACY")
                    }

                    if !games.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("RECENT GAMES")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.55))
                            ForEach(games.prefix(10)) { game in
                                HStack {
                                    Text(game.mode == "daily" ? "Daily" : "Endless · L\(game.level)")
                                        .foregroundStyle(.white.opacity(0.8))
                                    Spacer()
                                    Text(NumberText.grouped(game.score))
                                        .foregroundStyle(Theme.gold)
                                        .monospacedDigit()
                                    Text(game.date.formatted(.dateTime.month(.abbreviated).day()))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .frame(width: 64, alignment: .trailing)
                                }
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                .padding(.vertical, 10)
                                .padding(.horizontal, 14)
                                .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func fastestText(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.2fs", value)
    }

    private func accuracyText(_ stats: PlayerStats?) -> String {
        guard let stats else { return "—" }
        let total = stats.totalWordsSolved + stats.totalWordsMissed
        guard total > 0 else { return "—" }
        return "\(Int((Double(stats.totalWordsSolved) / Double(total) * 100).rounded()))%"
    }
}
