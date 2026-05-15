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
            Section("settings.section.general") {
                Toggle("settings.launch_at_login", isOn: $settings.launchAtLogin)

                Picker("settings.language.picker", selection: $settings.preferredLanguage) {
                    ForEach(PreferredLanguage.allCases) { lang in
                        Text(lang.labelKey).tag(lang)
                    }
                }
            }

            Section("settings.section.appearance") {
                Picker("settings.appearance.picker", selection: $settings.appearanceMode) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.labelKey).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            HelperSettingsSection()

            Section("settings.section.advanced") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("settings.advanced.reset.title")
                        Text("settings.advanced.reset.description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("settings.advanced.reset.button") {
                        showResetConfirm = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!hasManagedBlock || store.isWritingHosts)
                }
            }

            Section {
                LabeledContent("settings.about.version", value: Bundle.main.appVersion)
            } header: {
                Text("settings.section.about")
            } footer: {
                Text("settings.about.copyright")
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
            "settings.advanced.reset.title",
            isPresented: $showResetConfirm
        ) {
            Button("common.button.cancel", role: .cancel) {}
            Button("common.button.remove", role: .destructive) {
                store.resetManagedBlock(context: modelContext)
            }
        } message: {
            Text("settings.advanced.reset.alert.message")
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
                Button("common.button.ok", role: .cancel) {}
            case .requiresApproval:
                Button("settings.launch_alert.open_settings") {
                    NSWorkspace.shared.open(loginItemsSettingsURL)
                }
                Button("common.button.cancel", role: .cancel) {}
            }
        } message: { alert in
            switch alert {
            case .registrationFailed(let message):
                Text(String(format: String(localized: "settings.launch_alert.failed.message"), message))
            case .requiresApproval:
                Text("settings.launch_alert.approval.message")
            }
        }
    }

    private func refreshManagedBlockState() {
        hasManagedBlock = HostsFileManager.shared.hasManagedBlock()
    }

    private func alertTitle(for alert: LaunchAtLoginAlert?) -> String {
        switch alert {
        case .registrationFailed: String(localized: "settings.launch_alert.failed.title")
        case .requiresApproval:   String(localized: "settings.launch_alert.approval.title")
        case .none:               ""
        }
    }
}
