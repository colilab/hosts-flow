import SwiftUI
import SwiftData
import AppKit

private let loginItemsSettingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(ProfileStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @State private var hasManagedBlock = false
    @State private var showResetConfirm = false

    var body: some View {
        @Bindable var settings = settings

        Form {
            Section("Generale") {
                Toggle("Avvia al login", isOn: $settings.launchAtLogin)
            }

            Section("Aspetto") {
                Picker("Tema", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            HelperSettingsSection()

            Section("Avanzate") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pulisci /etc/hosts")
                        Text("Rimuove il blocco gestito da Host Flow. I profili non saranno cancellati.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Pulisci") {
                        showResetConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!hasManagedBlock || store.isWritingHosts)
                }
            }

            Section {
                LabeledContent("Versione", value: Bundle.main.appVersion)
            } header: {
                Text("Info")
            } footer: {
                Text("© 2026 Colilab")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
        .onAppear {
            settings.syncLaunchAtLoginFromSystem()
            refreshManagedBlockState()
        }
        .onChange(of: store.lastWriteAt) { _, _ in
            refreshManagedBlockState()
        }
        .alert(
            "Pulisci /etc/hosts",
            isPresented: $showResetConfirm
        ) {
            Button("Annulla", role: .cancel) {}
            Button("Rimuovi", role: .destructive) {
                store.resetManagedBlock(context: modelContext)
            }
        } message: {
            Text("Verrà rimosso il blocco Host Flow da /etc/hosts. I tuoi profili NON saranno cancellati.")
        }
        .alert(
            alertTitle(for: settings.launchAtLoginAlert),
            isPresented: Binding(
                get: { settings.launchAtLoginAlert != nil },
                set: { if !$0 { settings.launchAtLoginAlert = nil } }
            ),
            presenting: settings.launchAtLoginAlert
        ) { alert in
            switch alert {
            case .registrationFailed:
                Button("OK", role: .cancel) {}
            case .requiresApproval:
                Button("Apri System Settings") {
                    NSWorkspace.shared.open(loginItemsSettingsURL)
                }
                Button("Annulla", role: .cancel) {}
            }
        } message: { alert in
            switch alert {
            case .registrationFailed(let message):
                Text("Impossibile attivare avvio automatico: \(message)")
            case .requiresApproval:
                Text("Approvazione richiesta in System Settings → General → Login Items.")
            }
        }
    }

    private func refreshManagedBlockState() {
        hasManagedBlock = HostsFileManager.shared.hasManagedBlock()
    }

    private func alertTitle(for alert: LaunchAtLoginAlert?) -> String {
        switch alert {
        case .registrationFailed: "Errore"
        case .requiresApproval:   "Approvazione richiesta"
        case .none:               ""
        }
    }
}
