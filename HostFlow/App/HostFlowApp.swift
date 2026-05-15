import SwiftUI
import SwiftData

@main
struct HostFlowApp: App {

    private let container: ModelContainer = {
        let schema = Schema([Profile.self, HostRecord.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }()

    @State private var profileStore = ProfileStore()
    @State private var appSettings = AppSettings()

    var body: some Scene {
        Window("Host Flow", id: "main") {
            ContentView()
                .modelContainer(container)
                .environment(profileStore)
                .environment(appSettings)
                .preferredColorScheme(appSettings.preferredColorScheme)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 560)

        MenuBarExtra {
            MenuBarView()
                .modelContainer(container)
                .environment(profileStore)
                .environment(appSettings)
                .preferredColorScheme(appSettings.preferredColorScheme)
        } label: {
            MenuBarLabel()
                .modelContainer(container)
                .environment(profileStore)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .modelContainer(container)
                .environment(profileStore)
                .environment(appSettings)
                .preferredColorScheme(appSettings.preferredColorScheme)
        }
    }
}
