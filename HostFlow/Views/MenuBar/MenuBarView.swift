import SwiftUI
import SwiftData

struct MenuBarLabel: View {

    @Query(filter: #Predicate<Profile> { $0.isActive && !$0.isReadOnly })
    private var activeProfiles: [Profile]
    @Environment(ProfileStore.self) private var store

    var body: some View {
        Image(systemName: iconName)
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
            .help(tooltip)
    }

    private var iconName: String {
        if store.lastWriteError != nil { return "network.badge.shield.half.filled" }
        if activeProfiles.isEmpty { return "network.slash" }
        return "network"
    }

    private var iconColor: Color {
        if store.lastWriteError != nil { return .red }
        if activeProfiles.isEmpty { return .secondary }
        return Color(nsColor: .controlAccentColor)
    }

    private var tooltip: String {
        if store.lastWriteError != nil {
            return "Host Flow — Errore scrittura /etc/hosts"
        }
        let count = activeProfiles.count
        let suffix = count == 1 ? "profilo attivo" : "profili attivi"
        return "Host Flow — \(count) \(suffix)"
    }
}

struct MenuBarView: View {

    @Query(sort: \Profile.order) private var profiles: [Profile]
    @Environment(\.modelContext) private var context
    @Environment(\.openWindow) private var openWindow
    @Environment(ProfileStore.self) private var store
    @Environment(AppSettings.self) private var appSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
                Text("Profili")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 4)

                ForEach(profiles) { profile in
                    MenuBarProfileRow(profile: profile)
                }
            }

            Divider()
                .padding(.vertical, 4)

            Button {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "main")
            } label: {
                Label("Apri Host Flow", systemImage: "macwindow")
            }
            .buttonStyle(MenuItemButtonStyle())

            SettingsLink {
                Label("Impostazioni...", systemImage: "gearshape")
            }
            .buttonStyle(MenuItemButtonStyle())

            Divider()
                .padding(.vertical, 4)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Esci", systemImage: "power")
            }
            .buttonStyle(MenuItemButtonStyle())
            .keyboardShortcut("q", modifiers: .command)
            .padding(.bottom, 8)
        }
        .frame(width: 280)
    }
}

private struct MenuItemButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        MenuItemButtonBody(configuration: configuration)
    }
}

private struct MenuItemButtonBody: View {
    let configuration: ButtonStyle.Configuration
    @State private var isHovered = false

    var body: some View {
        configuration.label
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .foregroundStyle(isHighlighted ? Color.white : Color.primary)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHighlighted ? Color.accentColor : .clear)
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 5)
            .onHover { isHovered = $0 }
    }

    private var isHighlighted: Bool {
        isHovered || configuration.isPressed
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
            .onHover { hovering in
                guard !profile.isReadOnly else { return }
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onChange(of: profile.isActive) {
                try? context.save()
                store.scheduleWrite(context: context)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
    }
}
