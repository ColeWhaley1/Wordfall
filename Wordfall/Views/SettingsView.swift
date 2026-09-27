import SwiftUI

struct SettingsView: View {
    @Environment(AppServices.self) private var services

    var body: some View {
        @Bindable var settings = services.settings
        Form {
            Section("Gameplay") {
                Toggle("Haptics", isOn: $settings.hapticsEnabled)
                Toggle("Sound", isOn: $settings.soundEnabled)
                Toggle("Swipe Input", isOn: $settings.swipeInputEnabled)
            }
            Section {
                Toggle("Reduced Motion", isOn: $settings.reducedMotion)
            } header: {
                Text("Accessibility")
            } footer: {
                Text("Reduced Motion turns off shaking, tilting and particle effects. It's also on automatically when Reduce Motion is enabled in iOS Settings.")
            }
            if services.ads.consent.privacyOptionsRequired {
                Section {
                    Button("Privacy Choices") {
                        Task { await services.ads.presentPrivacyOptions() }
                    }
                } header: {
                    Text("Ads")
                } footer: {
                    Text("Change how your data is used for ads.")
                }
            }
            #if DEBUG
            AdDebugSection(policy: services.adPolicy)
            #endif
            Section("Game Center") {
                Label("Leaderboards and achievements are coming in a later version.", systemImage: "gamecontroller")
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("Word Fallout \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(ThemedBackground())
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: settings.hapticsEnabled) { _, enabled in
            services.haptics.isEnabled = enabled
        }
        .onChange(of: settings.soundEnabled) { _, enabled in
            services.sound.isEnabled = enabled
        }
    }
}

#if DEBUG
/// Development only: see and reset the ad policy's counters.
private struct AdDebugSection: View {
    let policy: AdPolicy
    @State private var removedAds = false
    @State private var summary = ""

    var body: some View {
        Section {
            Toggle("Simulate Remove Ads", isOn: $removedAds)
                .onChange(of: removedAds) { _, value in
                    policy.hasRemovedAds = value
                    refresh()
                }
            Text(summary)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
            Button("Reset Ad Counters") {
                policy.reset()
                refresh()
            }
        } header: {
            Text("Ads (dev only)")
        }
        .onAppear {
            removedAds = policy.hasRemovedAds
            refresh()
        }
    }

    private func refresh() {
        let state = policy.state
        let last = state.lastAdShownAt.map { "\($0.formatted(date: .omitted, time: .standard)) (\(state.lastAdKind?.rawValue ?? ""))" } ?? "never"
        summary = """
        games completed: \(state.completedGames)
        since interstitial: \(state.gamesSinceInterstitial)
        last ad: \(last)
        interstitial due now: \(policy.shouldShowInterstitial() ? "yes" : "no")
        """
    }
}
#endif
