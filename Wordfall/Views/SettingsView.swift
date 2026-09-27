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
                Toggle("Keyboard Input", isOn: $settings.keyboardInputEnabled)
            }
            Section {
                Toggle("Reduced Motion", isOn: $settings.reducedMotion)
            } header: {
                Text("Accessibility")
            } footer: {
                Text("Reduced Motion turns off shaking, tilting and particle effects. It's also on automatically when Reduce Motion is enabled in iOS Settings.")
            }
            Section("Game Center") {
                Label("Leaderboards and achievements are coming in a later version.", systemImage: "gamecontroller")
                    .foregroundStyle(.secondary)
            }
            Section {
                Text("Wordfall \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")")
                    .foregroundStyle(.secondary)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
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
