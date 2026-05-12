import SwiftUI
import AppKit

private let loginItemsSettingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings

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

            Section("Info") {
                LabeledContent("Versione") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .padding()
        .onAppear { settings.syncLaunchAtLoginFromSystem() }
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

    private func alertTitle(for alert: LaunchAtLoginAlert?) -> String {
        switch alert {
        case .registrationFailed: "Errore"
        case .requiresApproval:   "Approvazione richiesta"
        case .none:               ""
        }
    }
}
