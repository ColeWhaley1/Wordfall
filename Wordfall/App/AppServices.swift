import Foundation
import Observation

/// App-wide singletons shared through the SwiftUI environment.
@MainActor
@Observable
final class AppServices {
    let database: WordDatabase
    let settings: GameSettings
    let haptics: HapticsManager
    let sound: SoundManager

    init() {
        do {
            database = try WordDatabase.loadBundled()
        } catch {
            fatalError("words.json is missing from the app bundle: \(error)")
        }
        settings = GameSettings()
        haptics = HapticsManager()
        sound = SoundManager()
    }

    func todaysChallenge(now: Date = .now) -> DailyChallenge {
        DailyChallengeGenerator.challenge(for: now, database: database)
    }
}
