import SwiftData
import SwiftUI

@main
struct WordfallApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            HomeView()
                .environment(services)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
        .modelContainer(for: [PlayerStats.self, GameResult.self, DailyResult.self])
    }
}
