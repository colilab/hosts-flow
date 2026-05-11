import SwiftUI
import SwiftData
import AppKit

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
            .alert(
                "Errore di scrittura /etc/hosts",
                isPresented: Binding(
                    get: { store.lastWriteError != nil },
                    set: { if !$0 { store.lastWriteError = nil } }
                ),
                presenting: store.lastWriteError
            ) { _ in
                Button("Riprova") {
                    store.lastWriteError = nil
                    store.writeHosts(context: context)
                }
                Button("Annulla", role: .cancel) {
                    store.lastWriteError = nil
                }
            } message: { message in
                Text(message)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            store.flushPendingWrite(context: context)
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
