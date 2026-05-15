import SwiftUI
import SwiftData

struct MenuBarLabel: View {

    @Query(filter: #Predicate<Profile> { $0.isActive && !$0.isReadOnly })
    private var activeProfiles: [Profile]
    @Environment(ProfileStore.self) private var store

    var body: some View {
        Image("MenuBarIcon")
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(iconColor)
            .help(tooltip)
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
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        ForEach(profiles) { profile in
            if profile.isReadOnly {
                Button {
                } label: {
                    Label(profile.name, systemImage: "lock.fill")
                }
                .disabled(true)
            } else {
                MenuBarProfileMenu(profile: profile)
            }
        }

        if !profiles.isEmpty {
            Divider()
        }

        Button {
            NSApp.activate(ignoringOtherApps: true)
            openWindow(id: "main")
        } label: {
            Text("Apri Host Flow")
        }

        SettingsLink {
            Text("Impostazioni…")
        }

        Divider()

        Button {
            NSApp.terminate(nil)
        } label: {
            Text("Esci")
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

private struct MenuBarProfileMenu: View {

    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    var body: some View {
        Menu {
            Toggle("Attivo", isOn: Binding(
                get: { profile.isActive },
                set: { newValue in
                    profile.isActive = newValue
                    try? context.save()
                    store.scheduleWrite(context: context)
                }
            ))
        } label: {
            if profile.isActive {
                Label(profile.name, systemImage: "checkmark")
            } else {
                Text(profile.name)
            }
        }
    }
}
