import Foundation

enum AnalyticsEvent: String {
    case rewardedAdAvailable = "rewarded_ad_available"
    case rewardedAdStarted = "rewarded_ad_started"
    case rewardedAdCompleted = "rewarded_ad_completed"
    case rewardedAdFailed = "rewarded_ad_failed"
    case rewardedExtraLifeGranted = "rewarded_extra_life_granted"
    case interstitialAvailable = "interstitial_available"
    case interstitialShown = "interstitial_shown"
    case interstitialFailed = "interstitial_failed"
    case gameStarted = "game_started"
    case gameCompleted = "game_completed"
    case gameOver = "game_over"
    case gameOverAfterRewarded = "game_over_after_rewarded"
}

/// The one place events are reported. There's no analytics service yet, so
/// events are only printed in debug builds; connect a provider here later.
enum Analytics {
    static func log(_ event: AnalyticsEvent, _ parameters: [String: String] = [:]) {
        #if DEBUG
        let details = parameters.isEmpty ? "" : " " + parameters.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " ")
        print("[Analytics] \(event.rawValue)\(details)")
        #endif
    }

    static func debug(_ message: String) {
        #if DEBUG
        print("[Ads] \(message)")
        #endif
    }
}
