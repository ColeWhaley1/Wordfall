import SwiftData
import SwiftUI

/// Today's challenge: 10 fixed words, 3 lives, the same for everyone.
struct DailyView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.modelContext) private var modelContext
    @Query private var results: [DailyResult]
    @Query private var stats: [PlayerStats]

    @State private var challenge: DailyChallenge?
    @State private var launch: GameLaunch?

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 20) {
                    Text("DAILY")
                        .font(Theme.display(44))
                        .foregroundStyle(.white)
                        .padding(.top, 12)

                    if let challenge {
                        Text("\(Date.now.formatted(.dateTime.month(.wide).day()))  ·  #\(challenge.number)")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        if let result = results.first(where: { $0.dateKey == challenge.dateKey }) {
                            playedCard(result)
                        } else {
                            unplayedCard(challenge)
                        }
                    }

                    if let streak = displayedStreak, streak > 0 {
                        Text("🔥 \(streak) day streak")
                            .font(.system(size: 17, weight: .heavy, design: .rounded))
                            .foregroundStyle(.orange)
                    }
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            challenge = services.todaysChallenge()
        }
        .fullScreenCover(item: $launch) { launch in
            GameView(configuration: launch.configuration)
                .environment(services)
                .modelContext(modelContext)
        }
    }

    private func unplayedCard(_ challenge: DailyChallenge) -> some View {
        VStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                Label("\(challenge.words.count) words, 4 to 7 letters", systemImage: "textformat.abc")
                Label("\(challenge.lives) lives", systemImage: "heart.fill")
                Label("Same puzzle for everyone today", systemImage: "globe")
                Label("One attempt", systemImage: "1.circle")
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white.opacity(0.85))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Theme.panel, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button("PLAY") {
                launch = GameLaunch(configuration: .daily(challenge))
            }
            .buttonStyle(.arcade)
        }
    }

    private func playedCard(_ result: DailyResult) -> some View {
        VStack(spacing: 16) {
            Text(NumberText.grouped(result.score))
                .font(Theme.display(56))
                .foregroundStyle(Theme.gold)
            Text(ShareResult.grid(outcomes: result.outcomes, total: result.totalWords))
                .font(.system(size: 26))
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatTile(value: "\(result.wordsSolved)/\(result.totalWords)", label: "SOLVED")
                StatTile(value: "🔥 \(result.bestCombo)", label: "BEST COMBO")
            }
            ShareLink(item: result.shareText) {
                Label("SHARE RESULT", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.arcade)

            VStack(spacing: 4) {
                Text("NEXT PUZZLE IN")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.55))
                Text(timerInterval: Date.now...nextMidnight, countsDown: true)
                    .font(Theme.display(26))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
        }
    }

    private var nextMidnight: Date {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: .now)
        return calendar.date(byAdding: .day, value: 1, to: start) ?? .now.addingTimeInterval(86_400)
    }

    /// The stored streak only counts if the last daily was today or yesterday.
    private var displayedStreak: Int? {
        guard let stats = stats.first, let last = stats.lastDailyDateKey else { return nil }
        let today = DailyChallengeGenerator.dateKey(for: .now)
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)
            .map { DailyChallengeGenerator.dateKey(for: $0) }
        return last == today || last == yesterday ? stats.currentDailyStreak : 0
    }
}
