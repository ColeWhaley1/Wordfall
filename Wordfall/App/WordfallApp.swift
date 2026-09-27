import SwiftData
import SwiftUI

@main
struct WordfallApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            CosmeticsRoot {
                HomeView()
            }
            .environment(services)
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
            .task {
                // Shows Google's consent form first where the law requires it.
                await services.ads.start()
            }
        }
        .modelContainer(for: [PlayerStats.self, GameResult.self, DailyResult.self, Inventory.self])
    }
}

/// Reads the equipped cosmetics from the saved inventory and shares them
/// with every screen below.
private struct CosmeticsRoot<Content: View>: View {
    @ViewBuilder let content: Content
    @Query private var inventories: [Inventory]
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        content
            .environment(\.cosmetics, inventories.first?.equipped ?? EquippedCosmetics())
            #if DEBUG
            .onAppear { DemoMode.applyCosmetics(in: modelContext) }
            #endif
    }
}
