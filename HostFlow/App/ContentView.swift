import SwiftUI
import SwiftData
import AppKit

struct ContentView: View {

    @Query(sort: \Profile.order) private var profiles: [Profile]
    @State private var selectedProfile: Profile?
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store
    @Environment(AppSettings.self) private var settings
    @State private var watcher = HostsFileWatcher()

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
                "hosts.write_alert.title",
                isPresented: Binding(
                    get: { store.lastWriteError != nil },
                    set: { if !$0 { store.lastWriteError = nil } }
                ),
                presenting: store.lastWriteError
            ) { _ in
                Button("common.button.retry") {
                    store.lastWriteError = nil
                    store.writeHosts(context: context)
                }
                Button("common.button.cancel", role: .cancel) {
                    store.lastWriteError = nil
                }
            } message: { message in
                Text(message)
            }
    }

    private var content: some View {
        NavigationSplitView {
            SidebarView(selectedProfile: $selectedProfile)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 320)
        } detail: {
            Group {
                if let profile = selectedProfile {
                    ProfileDetailView(profile: profile)
                } else {
                    ContentUnavailableView(
                        "sidebar.empty.select_profile.title",
                        systemImage: "list.bullet.rectangle",
                        description: Text("sidebar.empty.select_profile.description")
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 400, ideal: 600)
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            store.seedIfNeeded(context: context)
            store.applyOnLaunch(context: context)
            watcher.start(profileStore: store, context: context)
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
