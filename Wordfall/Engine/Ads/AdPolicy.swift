import Foundation

enum AdKind: String, Codable, Sendable {
    case rewarded
    case interstitial
}

/// Decides whether an ad may be shown. It knows nothing about AdMob or the
/// game engine: the game screen reports what happened and asks before each ad.
///
/// - Active play and the daily are always ad-free.
/// - A rewarded ad (extra heart) is the player's choice, once per endless run.
/// - An interstitial only appears between endless games. Never for a new
///   player, never in a run where they watched a rewarded ad, and only once
///   enough games and time have passed since the last ad.
///
/// The counters are saved so they survive relaunching the app.
final class AdPolicy {
    struct State: Codable, Equatable {
        /// Endless games played to the end, ever.
        var completedGames = 0
        var gamesSinceInterstitial = 0
        var lastAdShownAt: Date?
        var lastAdKind: AdKind?
        /// Remove Ads bought: no interstitials. Rewarded ads stay available,
        /// since the player chooses to watch those.
        var hasRemovedAds = false
    }

    private(set) var state: State {
        didSet { save() }
    }

    private(set) var rewardedAdsUsedThisRun = 0
    private(set) var runIsDaily = false

    private let defaults: UserDefaults
    private static let storageKey = "adPolicy.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.storageKey),
           let saved = try? JSONDecoder().decode(State.self, from: data) {
            state = saved
        } else {
            state = State()
        }
    }

    var hasRemovedAds: Bool {
        get { state.hasRemovedAds }
        set { state.hasRemovedAds = newValue }
    }

    // MARK: Reporting

    func gameStarted(isDaily: Bool) {
        rewardedAdsUsedThisRun = 0
        runIsDaily = isDaily
    }

    /// The run is over for good (after any extra heart). Only endless games
    /// count towards interstitials.
    func gameEnded() {
        guard !runIsDaily else { return }
        state.completedGames += 1
        state.gamesSinceInterstitial += 1
    }

    /// Call when a rewarded ad was shown, whether or not it was watched to the end.
    func rewardedAdShown(at now: Date = .now) {
        rewardedAdsUsedThisRun += 1
        state.lastAdShownAt = now
        state.lastAdKind = .rewarded
    }

    func interstitialShown(at now: Date = .now) {
        state.lastAdShownAt = now
        state.lastAdKind = .interstitial
        state.gamesSinceInterstitial = 0
    }

    /// Forgets every counter (not the Remove Ads purchase). For testing.
    func reset() {
        state = State(hasRemovedAds: state.hasRemovedAds)
        rewardedAdsUsedThisRun = 0
    }

    // MARK: Decisions

    /// The out-of-lives screen may offer an extra heart for a rewarded ad.
    var canUseRewardedForExtraLife: Bool {
        if runIsDaily && !AdConfiguration.rewardedEnabledForDailyChallenge { return false }
        return rewardedAdsUsedThisRun < AdConfiguration.rewardedRevivesPerRun
    }

    /// Whether leaving the results screen may show an interstitial.
    func shouldShowInterstitial(now: Date = .now) -> Bool {
        guard !state.hasRemovedAds else { return false }
        guard !runIsDaily || AdConfiguration.interstitialsEnabledForDailyChallenge else { return false }
        // Never straight after a rewarded ad: this run already had one.
        guard rewardedAdsUsedThisRun == 0 else { return false }
        guard state.completedGames >= AdConfiguration.minimumGamesBeforeInterstitial else { return false }
        guard state.gamesSinceInterstitial >= AdConfiguration.gamesBetweenInterstitials else { return false }
        guard let last = state.lastAdShownAt else { return true }
        let cooldown = state.lastAdKind == .rewarded ? AdConfiguration.rewardedAdCooldown : AdConfiguration.normalAdCooldown
        return now.timeIntervalSince(last) >= cooldown
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: Self.storageKey)
        }
    }
}
