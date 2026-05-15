import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

private let loginItemsSettingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(ProfileStore.self) private var store
    @Environment(\.modelContext) private var modelContext

    @State private var hasManagedBlock = false
    @State private var showResetConfirm = false
    @State private var hudMessage: LocalizedStringKey?
    @State private var exportError: String?

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
                        Text("settings.advanced.export.title")
                        Text("settings.advanced.export.description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("settings.advanced.export.button") { exportAll() }
                        .buttonStyle(.borderedProminent)
                }

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
        .alert(
            "settings.advanced.export.error.title",
            isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            ),
            presenting: exportError
        ) { _ in
            Button("common.button.ok", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .overlay(alignment: .top) {
            if let hudMessage {
                Label(hudMessage, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hudMessage != nil)
    }

    private func exportAll() {
        let descriptor = FetchDescriptor<Profile>(sortBy: [SortDescriptor(\.order)])
        let profiles = (try? modelContext.fetch(descriptor)) ?? []
        let data: Data
        do {
            data = try ExportService.exportAll(profiles: profiles)
        } catch {
            exportError = error.localizedDescription
            return
        }
        let panel = NSSavePanel()
        panel.title = String(localized: "settings.advanced.export.panel.title")
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = defaultExportFilename
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try data.write(to: url, options: .atomic)
                showHUD("settings.advanced.export.done")
            } catch {
                exportError = error.localizedDescription
            }
        }
    }

    private var defaultExportFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return "hostflow-export-\(formatter.string(from: Date())).json"
    }

    private func showHUD(_ key: LocalizedStringKey) {
        hudMessage = key
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            hudMessage = nil
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
