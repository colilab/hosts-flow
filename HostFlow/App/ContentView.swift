import SwiftUI
import SwiftData

struct ContentView: View {

    @Query(sort: \Profile.order) private var profiles: [Profile]
    @State private var selectedProfile: Profile?

    var body: some View {
        NavigationSplitView {
            SidebarView(selectedProfile: $selectedProfile)
        } detail: {
            if let profile = selectedProfile {
                ProfileDetailView(profile: profile)
            } else {
                ContentUnavailableView(
                    "Seleziona un profilo",
                    systemImage: "list.bullet.rectangle",
                    description: Text("Scegli un profilo dalla sidebar o creane uno nuovo.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear {
            if selectedProfile == nil {
                selectedProfile = profiles.first
            }
        }
    }
}
