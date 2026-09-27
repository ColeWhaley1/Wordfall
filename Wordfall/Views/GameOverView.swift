import SwiftUI

struct GameOverView: View {
    let engine: GameEngine
    let recorded: RecordedGame?
    /// Nil for daily mode, which can be played once per day.
    let onPlayAgain: (() -> Void)?
    let onHome: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    Text(title)
                        .font(Theme.display(40))
                        .foregroundStyle(.white)
                        .padding(.top, 40)

                    if recorded?.isNewHighScore == true {
                        Text("🏆 NEW HIGH SCORE")
                            .font(Theme.display(20))
                            .foregroundStyle(Theme.gold)
                    }

                    Text(NumberText.grouped(engine.score))
                        .font(Theme.display(64))
                        .foregroundStyle(Theme.gold)
                        .shadow(color: Theme.gold.opacity(0.6), radius: 16)
                        .accessibilityLabel("Score \(engine.score)")

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        if engine.mode.isDaily {
                            StatTile(value: "\(engine.wordsSolved)/\(engine.dailyProgress?.total ?? 0)", label: "WORDS")
                        } else {
                            StatTile(value: "\(engine.level)", label: "LEVEL")
                        }
                        StatTile(value: "🔥 \(engine.bestCombo)", label: "BEST COMBO")
                        StatTile(value: "\(engine.wordsSolved)", label: "SOLVED")
                        StatTile(value: "\(engine.wordsMissed)", label: "MISSED")
                        StatTile(value: averageText, label: "AVG SOLVE")
                        StatTile(value: "\(engine.perfectCount)", label: "PERFECT")
                    }
                    .padding(.horizontal, 24)

                    if case .daily(let challenge) = engine.mode {
                        let share = ShareResult.text(
                            number: challenge.number,
                            outcomes: engine.outcomes,
                            total: challenge.words.count,
                            score: engine.score,
                            bestCombo: engine.bestCombo
                        )
                        Text(ShareResult.grid(outcomes: engine.outcomes, total: challenge.words.count))
                            .font(.system(size: 24))
                        if let streak = recorded?.dailyStreak {
                            Text("Daily streak: \(streak)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        ShareLink(item: share) {
                            Label("SHARE RESULT", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.arcade)
                    }

                    if let onPlayAgain {
                        Button("PLAY AGAIN", action: onPlayAgain)
                            .buttonStyle(.arcade)
                    }
                    Button("HOME", action: onHome)
                        .buttonStyle(.arcadeSecondary)
                        .padding(.bottom, 32)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var title: String {
        if engine.mode.isDaily {
            return engine.lives > 0 ? "DAILY COMPLETE" : "OUT OF LIVES"
        }
        return "GAME OVER"
    }

    private var averageText: String {
        guard let average = engine.averageSolveTime else { return "—" }
        return String(format: "%.2fs", average)
    }
}

/// A big number over a small caption.
struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(Theme.display(26))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
