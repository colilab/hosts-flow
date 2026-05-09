import SwiftUI
import SwiftData

struct ContentView: View {

    @Query(sort: \Profile.order) private var profiles: [Profile]
    @State private var selectedProfile: Profile?
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var store = store
        return content
            .sheet(isPresented: $store.helperMissing) {
                HelperOnboardingSheet(installer: settings.helperInstaller) { installed in
                    store.helperMissing = false
                    if installed {
                        store.writeHosts(context: context)
                    }
                }
            }
    }

    private var content: some View {
        HSplitView {
            SidebarView(selectedProfile: $selectedProfile)
                .frame(minWidth: 180, idealWidth: 220, maxWidth: 320)

            Group {
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
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all, edges: .top)
        }
        .task {
            store.seedIfNeeded(context: context)
        }
        .onAppear {
            if selectedProfile == nil {
                selectedProfile = profiles.first
            }
        }
        .onChange(of: profiles.count) { _, _ in
            if selectedProfile == nil {
                selectedProfile = profiles.first
            }
        }
    }
}
