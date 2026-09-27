import Foundation
import SwiftData

/// Shortcuts for development. Every one is off in Release builds.
enum DevOptions {
    /// Lets the daily be played again the same day (from the daily screen and
    /// the game-over screen). Each replay replaces that day's saved result.
    static let allowsDailyReplay: Bool = {
        #if DEBUG
        true
        #else
        false
        #endif
    }()

    /// Deletes the saved result for a day so it can be played again.
    @MainActor
    static func forgetDailyResult(dateKey: String, in context: ModelContext) {
        guard allowsDailyReplay else { return }
        try? context.delete(model: DailyResult.self, where: #Predicate { $0.dateKey == dateKey })
        try? context.save()
    }
}
