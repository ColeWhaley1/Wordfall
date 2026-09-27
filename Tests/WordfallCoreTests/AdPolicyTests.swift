import XCTest
@testable import WordfallCore

final class AdPolicyTests: XCTestCase {
    private var defaults: UserDefaults!
    private let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    override func setUp() {
        let suite = "AdPolicyTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    /// Plays one endless game to the end, optionally watching a rewarded ad in it.
    private func play(_ policy: AdPolicy, watchingRewardedAt time: Date? = nil) {
        policy.gameStarted(isDaily: false)
        if let time { policy.rewardedAdShown(at: time) }
        policy.gameEnded()
    }

    func testNewPlayersSeeNoInterstitialForTheirFirstGames() {
        let policy = AdPolicy(defaults: defaults)
        play(policy)
        XCTAssertFalse(policy.shouldShowInterstitial(now: start))
        play(policy)
        XCTAssertFalse(policy.shouldShowInterstitial(now: start))
        play(policy)
        XCTAssertTrue(policy.shouldShowInterstitial(now: start))
    }

    func testInterstitialsNeedThreeGamesInBetween() {
        let policy = AdPolicy(defaults: defaults)
        for _ in 0..<3 { play(policy) }
        policy.interstitialShown(at: start)
        let later = start.addingTimeInterval(3600)
        play(policy)
        play(policy)
        XCTAssertFalse(policy.shouldShowInterstitial(now: later))
        play(policy)
        XCTAssertTrue(policy.shouldShowInterstitial(now: later))
    }

    func testTwoMinuteCooldownAfterAnInterstitial() {
        let policy = AdPolicy(defaults: defaults)
        for _ in 0..<3 { play(policy) }
        policy.interstitialShown(at: start)
        for _ in 0..<3 { play(policy) }
        XCTAssertFalse(policy.shouldShowInterstitial(now: start.addingTimeInterval(119)))
        XCTAssertTrue(policy.shouldShowInterstitial(now: start.addingTimeInterval(120)))
    }

    func testNeverAnInterstitialInARunWithARewardedAd() {
        let policy = AdPolicy(defaults: defaults)
        for _ in 0..<5 { play(policy) }
        policy.gameStarted(isDaily: false)
        policy.rewardedAdShown(at: start)
        policy.gameEnded()
        XCTAssertFalse(policy.shouldShowInterstitial(now: start.addingTimeInterval(3600)))
    }

    func testFiveMinuteCooldownAfterARewardedAd() {
        let policy = AdPolicy(defaults: defaults)
        play(policy, watchingRewardedAt: start)
        play(policy)
        play(policy)
        XCTAssertFalse(policy.shouldShowInterstitial(now: start.addingTimeInterval(299)))
        XCTAssertTrue(policy.shouldShowInterstitial(now: start.addingTimeInterval(300)))
    }

    func testOneRewardedRevivePerRun() {
        let policy = AdPolicy(defaults: defaults)
        policy.gameStarted(isDaily: false)
        XCTAssertTrue(policy.canUseRewardedForExtraLife)
        policy.rewardedAdShown(at: start)
        XCTAssertFalse(policy.canUseRewardedForExtraLife)
        policy.gameEnded()
        policy.gameStarted(isDaily: false)
        XCTAssertTrue(policy.canUseRewardedForExtraLife)
    }

    func testTheDailyIsAdFreeAndDoesNotCount() {
        let policy = AdPolicy(defaults: defaults)
        for _ in 0..<3 { play(policy) }
        policy.gameStarted(isDaily: true)
        XCTAssertFalse(policy.canUseRewardedForExtraLife)
        policy.gameEnded()
        XCTAssertFalse(policy.shouldShowInterstitial(now: start))
        XCTAssertEqual(policy.state.completedGames, 3)
    }

    func testRemoveAdsStopsInterstitialsButKeepsRewarded() {
        let policy = AdPolicy(defaults: defaults)
        policy.hasRemovedAds = true
        for _ in 0..<5 { play(policy) }
        XCTAssertFalse(policy.shouldShowInterstitial(now: start))
        policy.gameStarted(isDaily: false)
        XCTAssertTrue(policy.canUseRewardedForExtraLife)
    }

    func testCountersSurviveARelaunch() {
        let policy = AdPolicy(defaults: defaults)
        for _ in 0..<3 { play(policy) }
        policy.interstitialShown(at: start)
        let relaunched = AdPolicy(defaults: defaults)
        XCTAssertEqual(relaunched.state.completedGames, 3)
        XCTAssertEqual(relaunched.state.gamesSinceInterstitial, 0)
        XCTAssertEqual(relaunched.state.lastAdKind, .interstitial)
    }
}
