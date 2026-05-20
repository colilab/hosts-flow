import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

private let loginItemsSettingsURL = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension")!

struct SettingsView: View {

    @Environment(AppSettings.self) private var settings
    @Environment(ProfileStore.self) private var store
    @Environment(UpdaterStore.self) private var updater
    @Environment(\.modelContext) private var modelContext

    @State private var hasManagedBlock = false
    @State private var showResetConfirm = false
    @State private var hudMessage: LocalizedStringKey?
    @State private var exportError: String?
    @State private var importResult: ImportResult?
    @State private var importError: String?
    @State private var importJSONResult: ImportJSONResult?
    @State private var importJSONError: String?

    var body: some View {
        @Bindable var settings = settings
        @Bindable var updater = updater

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
                        Text("settings.advanced.import.title")
                        Text("settings.advanced.import.description")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        Button("settings.advanced.import.hosts") { startImport() }
                        Button("settings.advanced.import.json") { startImportJSON() }
                    } label: {
                        Text("settings.advanced.import.button")
                    }
                    .menuStyle(.borderlessButton)
                    .fixedSize()
                }

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

                Toggle("settings.about.auto_check", isOn: $updater.automaticallyChecksForUpdates)

                HStack {
                    Button("settings.about.check_updates") {
                        updater.checkForUpdates()
                    }
                    .disabled(!updater.canCheckForUpdates)

                    Spacer()

                    if let lastCheck = updater.lastUpdateCheckDate {
                        Text(lastCheckedText(lastCheck))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
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
        .alert(
            "settings.advanced.import.error.title",
            isPresented: Binding(
                get: { importError != nil },
                set: { if !$0 { importError = nil } }
            ),
            presenting: importError
        ) { _ in
            Button("common.button.ok", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .sheet(item: $importResult) { result in
            ImportProfileSheet(
                suggestedName: result.suggestedName,
                records: result.records,
                existingNames: currentProfileNames()
            ) { finalName in
                createProfile(name: finalName, records: result.records)
            }
        }
        .alert(
            "settings.advanced.import.error.title",
            isPresented: Binding(
                get: { importJSONError != nil },
                set: { if !$0 { importJSONError = nil } }
            ),
            presenting: importJSONError
        ) { _ in
            Button("common.button.ok", role: .cancel) {}
        } message: { message in
            Text(message)
        }
        .sheet(item: $importJSONResult) { result in
            ImportJSONSheet(
                result: result,
                userProfileCount: store.userProfileCount(context: modelContext)
            ) { mode in
                store.applyImport(result.payload, mode: mode, context: modelContext)
                showHUD("settings.advanced.import.done")
            }
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

    private func startImport() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "settings.advanced.import.panel.title")
        panel.allowedContentTypes = [.plainText, .data]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                importResult = try ImportService.parseFile(at: url)
            } catch {
                importError = error.localizedDescription
            }
        }
    }

    private func startImportJSON() {
        let panel = NSOpenPanel()
        panel.title = String(localized: "settings.advanced.import.json.panel.title")
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                importJSONResult = try ImportJSONService.parseFile(at: url)
            } catch {
                importJSONError = error.localizedDescription
            }
        }
    }

    private func currentProfileNames() -> [String] {
        let descriptor = FetchDescriptor<Profile>()
        return ((try? modelContext.fetch(descriptor)) ?? []).map(\.name)
    }

    private func createProfile(name: String, records: [ParsedHostRecord]) {
        let profile = store.addProfile(name: name, context: modelContext)
        for parsed in records {
            let record = HostRecord(ip: parsed.ip, hostname: parsed.hostname, profile: profile)
            record.isEnabled = parsed.isEnabled
            modelContext.insert(record)
        }
        try? modelContext.save()
        showHUD("settings.advanced.import.done")
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

    private func lastCheckedText(_ date: Date) -> String {
        let relative = date.formatted(
            .relative(presentation: .named).locale(settings.resolvedLocale)
        )
        return String(format: String(localized: "settings.about.last_checked"), relative)
    }

    private func alertTitle(for alert: LaunchAtLoginAlert?) -> String {
        switch alert {
        case .registrationFailed: String(localized: "settings.launch_alert.failed.title")
        case .requiresApproval:   String(localized: "settings.launch_alert.approval.title")
        case .none:               ""
        }
    }
}
