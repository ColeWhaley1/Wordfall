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
    let ads: AdManager
    let adPolicy: AdPolicy

    init() {
        do {
            database = try WordDatabase.loadBundled()
        } catch {
            fatalError("words.json is missing from the app bundle: \(error)")
        }
        settings = GameSettings()
        haptics = HapticsManager()
        sound = SoundManager()
        ads = AdManager()
        adPolicy = AdPolicy()
    }

    func todaysChallenge(now: Date = .now) -> DailyChallenge {
        DailyChallengeGenerator.challenge(for: now, database: database)
    }
}
