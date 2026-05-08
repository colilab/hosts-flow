import SwiftUI

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
    }
}
