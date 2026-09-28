import Foundation
import Observation
import UserMessagingPlatform

/// Google's consent tool (UMP). Asks for consent where the law requires it
/// (EEA, UK and similar) before any ad is requested.
@MainActor
@Observable
final class ConsentManager {
    /// The player must be able to change their choices later, from Settings.
    private(set) var privacyOptionsRequired = false

    var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

    /// Refreshes the consent status and shows the form if it's needed.
    func gather() async {
        do {
            let parameters = RequestParameters()
            #if DEBUG
            parameters.debugSettings = Self.debugSettings()
            #endif
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // Consent from an earlier launch may still allow ads, so carry on.
            Analytics.debug("consent: \(error.localizedDescription)")
        }
        refresh()
    }

    /// Re-opens the consent form so the player can change their choices.
    func presentPrivacyOptions() async {
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: nil)
        } catch {
            Analytics.debug("privacy options: \(error.localizedDescription)")
        }
        refresh()
    }

    #if DEBUG
    /// Launch arguments for testing the consent form outside Europe:
    /// `-consentEEA` pretends the device is in the EEA, `-resetConsent`
    /// forgets earlier answers, and `-consentTestDevice <id>` registers a
    /// physical device (its id is printed by the SDK in the console).
    /// Simulators count as test devices automatically.
    private static func debugSettings() -> DebugSettings? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-resetConsent") {
            ConsentInformation.shared.reset()
        }
        guard arguments.contains("-consentEEA") else { return nil }
        let settings = DebugSettings()
        settings.geography = .EEA
        if let index = arguments.firstIndex(of: "-consentTestDevice"), index + 1 < arguments.count {
            settings.testDeviceIdentifiers = [arguments[index + 1]]
        }
        return settings
    }
    #endif

    private func refresh() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }
}
