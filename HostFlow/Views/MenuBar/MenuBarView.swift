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
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Nessun profilo. Crea il primo dalla finestra principale.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
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
        .frame(width: 280)
    }
}

private struct MenuBarProfileRow: View {

    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    var body: some View {
        HStack(spacing: 6) {
            Text(profile.name)
                .font(.callout)
                .lineLimit(1)
                .truncationMode(.tail)

            if profile.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Toggle(isOn: $profile.isActive) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .disabled(profile.isReadOnly)
            .onChange(of: profile.isActive) {
                try? context.save()
                store.scheduleWrite(context: context)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}
