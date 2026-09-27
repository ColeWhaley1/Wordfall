import SwiftUI

struct GameOverView: View {
    let engine: GameEngine
    let recorded: RecordedGame?
    /// Nil for daily mode, which can be played once per day (except in development builds).
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

                    Text("\(engine.difficulty.title) · \(engine.difficulty.pointsLabel)")
                        .font(.system(size: 13, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(.white.opacity(0.55))

                    if let recorded {
                        CoinsEarnedView(earned: recorded.coinsEarned, balance: recorded.coinBalance)
                    }

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

                    if !engine.history.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("WORDS")
                                .font(.system(size: 13, weight: .heavy, design: .rounded))
                                .tracking(2)
                                .foregroundStyle(.white.opacity(0.55))
                            ForEach(engine.history) { record in
                                WordRecordRow(record: record)
                            }
                        }
                        .padding(.horizontal, 24)
                    }

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
                        Button(engine.mode.isDaily ? "PLAY AGAIN (DEV)" : "PLAY AGAIN", action: onPlayAgain)
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

/// The coins this round paid out, counting up from zero.
private struct CoinsEarnedView: View {
    let earned: Int
    let balance: Int

    @State private var shown = 0

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                CoinIcon(size: 28)
                Text("+\(NumberText.grouped(shown))")
                    .font(Theme.display(30))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(shown)))
                    .foregroundStyle(Theme.gold)
            }
            Text("COINS · \(NumberText.grouped(balance)) TOTAL")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.5)
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.gold.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Earned \(earned) coins. \(balance) coins in total")
        .task {
            try? await Task.sleep(for: .milliseconds(250))
            withAnimation(.easeOut(duration: 0.8)) { shown = earned }
        }
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

/// One line of the end-of-game word list.
private struct WordRecordRow: View {
    let record: WordRecord

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: record.isSolved ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(record.isSolved ? Theme.success : Theme.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(record.word)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                if let answer = record.answer, answer != record.word {
                    Text("solved as \(answer)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.isSolved ? "+\(NumberText.grouped(record.points))" : "MISS")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(record.isSolved ? Theme.gold : Theme.danger)
                if record.isSolved {
                    Text(String(format: "%.1fs", record.time))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 14)
        .background(Theme.panel, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}
