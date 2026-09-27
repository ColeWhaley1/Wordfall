import Foundation
import SwiftData

/// What the game-over screen needs to know after saving.
struct RecordedGame {
    let isNewHighScore: Bool
    let previousHighScore: Int
    let dailyStreak: Int?
}

/// Saves a finished game. Called once per game, never during play.
@MainActor
enum StatsRecorder {
    static func stats(in context: ModelContext) -> PlayerStats {
        let existing = (try? context.fetch(FetchDescriptor<PlayerStats>())) ?? []
        if let stats = existing.first { return stats }
        let stats = PlayerStats()
        context.insert(stats)
        return stats
    }

    static func dailyResult(for dateKey: String, in context: ModelContext) -> DailyResult? {
        var descriptor = FetchDescriptor<DailyResult>(predicate: #Predicate<DailyResult> { $0.dateKey == dateKey })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    static func record(_ engine: GameEngine, in context: ModelContext, now: Date = .now, calendar: Calendar = .current) -> RecordedGame {
        let stats = stats(in: context)
        let previousHigh = stats.highestScore

        stats.totalGames += 1
        stats.totalWordsSolved += engine.wordsSolved
        stats.totalWordsMissed += engine.wordsMissed
        stats.totalPerfects += engine.perfectCount
        stats.highestCombo = max(stats.highestCombo, engine.bestCombo)
        stats.keyboardLetters += engine.inputCounts[.keyboard] ?? 0
        stats.tapLetters += engine.inputCounts[.tap] ?? 0
        stats.swipeLetters += engine.inputCounts[.swipe] ?? 0
        if engine.longestWord.count > stats.longestWord.count {
            stats.longestWord = engine.longestWord
        }
        if let fastest = engine.solveTimes.min() {
            stats.fastestSolve = min(stats.fastestSolve ?? fastest, fastest)
        }

        var isNewHighScore = false
        var streak: Int?
        switch engine.mode {
        case .endless:
            stats.highestLevel = max(stats.highestLevel, engine.level)
            if engine.score > stats.highestScore {
                stats.highestScore = engine.score
                isNewHighScore = engine.score > 0
            }
        case .daily(let challenge):
            streak = updateStreak(stats, dateKey: challenge.dateKey, now: now, calendar: calendar)
            if dailyResult(for: challenge.dateKey, in: context) == nil {
                context.insert(DailyResult(
                    dateKey: challenge.dateKey,
                    number: challenge.number,
                    date: now,
                    score: engine.score,
                    completed: engine.outcomes.count >= challenge.words.count,
                    wordsSolved: engine.wordsSolved,
                    totalWords: challenge.words.count,
                    bestCombo: engine.bestCombo,
                    averageSolveTime: engine.averageSolveTime,
                    outcomes: engine.outcomes
                ))
            }
        }

        context.insert(GameResult(
            date: now,
            mode: engine.mode.isDaily ? "daily" : "endless",
            score: engine.score,
            level: engine.level,
            wordsSolved: engine.wordsSolved,
            wordsMissed: engine.wordsMissed,
            highestCombo: engine.bestCombo,
            duration: engine.elapsedTime
        ))
        try? context.save()

        return RecordedGame(isNewHighScore: isNewHighScore, previousHighScore: previousHigh, dailyStreak: streak)
    }

    private static func updateStreak(_ stats: PlayerStats, dateKey: String, now: Date, calendar: Calendar) -> Int {
        if stats.lastDailyDateKey == dateKey {
            return stats.currentDailyStreak
        }
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now).map {
            DailyChallengeGenerator.dateKey(for: $0, calendar: calendar)
        }
        if let yesterday, stats.lastDailyDateKey == yesterday {
            stats.currentDailyStreak += 1
        } else {
            stats.currentDailyStreak = 1
        }
        stats.lastDailyDateKey = dateKey
        stats.longestDailyStreak = max(stats.longestDailyStreak, stats.currentDailyStreak)
        return stats.currentDailyStreak
    }
}
