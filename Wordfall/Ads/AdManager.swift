import Foundation
import GoogleMobileAds
import Observation

/// Loads and shows AdMob ads. It never decides *whether* an ad should be
/// shown; that's `AdPolicy`. Both ad types are preloaded as soon as consent
/// allows, and reloaded straight after each one is shown, so one is usually
/// ready. If an ad isn't ready, nothing is offered: the player never waits.
@MainActor
@Observable
final class AdManager: NSObject {
    enum AdUnit {
        // Debug builds must use Google's test units: tapping or repeatedly
        // viewing your own live ads breaks AdMob policy.
        #if DEBUG
        static let rewardedExtraHeart = "ca-app-pub-3940256099942544/1712485313"
        static let interstitial = "ca-app-pub-3940256099942544/4411468910"
        #else
        static let rewardedExtraHeart = "ca-app-pub-8273060205096005/1305097902"
        static let interstitial = "ca-app-pub-8273060205096005/1378259257"
        #endif
    }

    enum RewardedOutcome {
        /// Watched long enough to earn the reward.
        case earned
        /// Shown, but closed before the reward.
        case closedEarly
        /// Couldn't be shown at all.
        case failed
    }

    let consent = ConsentManager()

    private(set) var isRewardedAdReady = false
    private(set) var isInterstitialReady = false

    @ObservationIgnored private var hasStarted = false
    @ObservationIgnored private var sdkStarted = false
    @ObservationIgnored private var rewardedAd: RewardedAd?
    @ObservationIgnored private var interstitialAd: InterstitialAd?
    @ObservationIgnored private var loadingRewarded = false
    @ObservationIgnored private var loadingInterstitial = false
    @ObservationIgnored private var rewardedRetries = 0
    @ObservationIgnored private var interstitialRetries = 0
    @ObservationIgnored private var presentation: Presentation?

    private enum Presentation {
        case rewarded(earned: Bool, completion: (RewardedOutcome) -> Void)
        case interstitial(completion: (Bool) -> Void)
    }

    // MARK: Setup

    /// Gathers consent if needed, then starts the SDK and preloads. Safe to call more than once.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await consent.gather()
        startIfAllowed()
    }

    func presentPrivacyOptions() async {
        await consent.presentPrivacyOptions()
        startIfAllowed()
    }

    /// Loads whichever ads aren't ready or loading yet.
    func preload() {
        loadRewarded()
        loadInterstitial()
    }

    // MARK: Showing

    /// Shows the rewarded ad. `completion` runs once it's closed.
    func showRewarded(completion: @escaping (RewardedOutcome) -> Void) {
        guard presentation == nil, let ad = rewardedAd else {
            completion(.failed)
            loadRewarded()
            return
        }
        presentation = .rewarded(earned: false, completion: completion)
        // nil presents from the top-most view controller, the game's full-screen cover.
        ad.present(from: nil) { [weak self] in
            guard let self, case .rewarded(_, let completion) = self.presentation else { return }
            self.presentation = .rewarded(earned: true, completion: completion)
        }
    }

    /// Shows the interstitial. `completion` runs once it's closed, with false
    /// if it couldn't be shown.
    func showInterstitial(completion: @escaping (Bool) -> Void) {
        guard presentation == nil, let ad = interstitialAd else {
            completion(false)
            loadInterstitial()
            return
        }
        presentation = .interstitial(completion: completion)
        ad.present(from: nil)
    }

    // MARK: Loading

    private func startIfAllowed() {
        guard consent.canRequestAds else { return }
        if !sdkStarted {
            sdkStarted = true
            MobileAds.shared.start(completionHandler: nil)
        }
        preload()
    }

    private func loadRewarded() {
        guard sdkStarted, rewardedAd == nil, !loadingRewarded else { return }
        loadingRewarded = true
        Task {
            defer { loadingRewarded = false }
            do {
                let ad = try await RewardedAd.load(with: AdUnit.rewardedExtraHeart, request: Request())
                ad.fullScreenContentDelegate = self
                rewardedAd = ad
                rewardedRetries = 0
                isRewardedAdReady = true
            } catch {
                Analytics.debug("rewarded load: \(error.localizedDescription)")
                rewardedRetries += 1
                retry(after: rewardedRetries) { $0.loadRewarded() }
            }
        }
    }

    private func loadInterstitial() {
        guard sdkStarted, interstitialAd == nil, !loadingInterstitial else { return }
        loadingInterstitial = true
        Task {
            defer { loadingInterstitial = false }
            do {
                let ad = try await InterstitialAd.load(with: AdUnit.interstitial, request: Request())
                ad.fullScreenContentDelegate = self
                interstitialAd = ad
                interstitialRetries = 0
                isInterstitialReady = true
            } catch {
                Analytics.debug("interstitial load: \(error.localizedDescription)")
                interstitialRetries += 1
                retry(after: interstitialRetries) { $0.loadInterstitial() }
            }
        }
    }

    /// Backs off 10s, 20s, 40s… up to 2 minutes between failed loads.
    private func retry(after attempts: Int, _ load: @escaping (AdManager) -> Void) {
        let delay = min(120, 10 * (1 << min(attempts - 1, 4)))
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self else { return }
            load(self)
        }
    }

    private func finishPresentation(failed: Bool) {
        let finished = presentation
        presentation = nil
        switch finished {
        case .rewarded(let earned, let completion):
            rewardedAd = nil
            isRewardedAdReady = false
            loadRewarded()
            completion(failed ? .failed : earned ? .earned : .closedEarly)
        case .interstitial(let completion):
            interstitialAd = nil
            isInterstitialReady = false
            loadInterstitial()
            completion(!failed)
        case nil:
            break
        }
    }
}

extension AdManager: FullScreenContentDelegate {
    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in self.finishPresentation(failed: false) }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            Analytics.debug("present: \(error.localizedDescription)")
            self.finishPresentation(failed: true)
        }
    }
}
