import SwiftUI
import SwiftData

struct MenuBarView: View {

    @Query(sort: \Profile.order) private var profiles: [Profile]
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Host Flow")
                .font(.headline)
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            if profiles.isEmpty {
                Text("Nessun profilo")
                    .foregroundStyle(.secondary)
                    .font(.callout)
                    .padding(12)
            } else {
                ForEach(profiles) { profile in
                    MenuBarProfileRow(profile: profile)
                }
            }

            Divider()
                .padding(.vertical, 4)

            Button("Apri Host Flow") {
                NSApp.activate(ignoringOtherApps: true)
                NSApp.windows.first?.makeKeyAndOrderFront(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            SettingsLink {
                Text("Impostazioni...")
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()
                .padding(.vertical, 4)

            Button("Esci") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
            .padding(.top, 2)
        }
        .frame(width: 220)
    }
}

private struct MenuBarProfileRow: View {

    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    var body: some View {
        Toggle(isOn: $profile.isActive) {
            Text(profile.name)
                .font(.callout)
        }
        .toggleStyle(.switch)
        .controlSize(.mini)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .onChange(of: profile.isActive) {
            try? context.save()
            store.writeHosts(context: context)
        }
    }
}
