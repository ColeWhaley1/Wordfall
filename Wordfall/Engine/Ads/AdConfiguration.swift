import Foundation

/// Every tunable number for when ads may appear. `AdPolicy` applies them.
enum AdConfiguration {
    /// A new player sees no interstitials during their first few games.
    static let minimumGamesBeforeInterstitial = 3

    /// Completed endless games required between two interstitials.
    static let gamesBetweenInterstitials = 3

    /// Minimum time between any ad and the next interstitial.
    static let normalAdCooldown: TimeInterval = 120

    /// Longer wait after a rewarded ad: the player already watched one.
    static let rewardedAdCooldown: TimeInterval = 300

    /// Extra hearts a player can earn from rewarded ads in one run.
    static let rewardedRevivesPerRun = 1

    /// The daily is one fair, identical attempt for everyone: no revives.
    static let rewardedEnabledForDailyChallenge = false

    /// The daily result screen stays ad-free.
    static let interstitialsEnabledForDailyChallenge = false
}
