import SwiftUI

struct HelperSettingsSection: View {

    @Environment(AppSettings.self) private var settings
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showUninstallConfirm = false

    var body: some View {
        Section("settings.section.helper") {
            LabeledContent("helper.status.label") {
                statusLabel
            }

            HStack {
                switch settings.helperStatus {
                case .installed:
                    Button("common.button.uninstall", role: .destructive) {
                        showUninstallConfirm = true
                    }
                    .disabled(isWorking)
                case .notInstalled, .error:
                    Button("common.button.install") {
                        runInstall()
                    }
                    .disabled(isWorking)
                }
                if isWorking { ProgressView().controlSize(.small) }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .task { settings.helperInstaller.refreshStatusVerified() }
        .confirmationDialog(
            "helper.uninstall.confirm.title",
            isPresented: $showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button("common.button.uninstall", role: .destructive) { runUninstall() }
            Button("common.button.cancel", role: .cancel) {}
        } message: {
            Text("helper.uninstall.confirm.message")
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch settings.helperStatus {
        case .installed:
            Text("helper.status.installed").foregroundStyle(.secondary)
        case .notInstalled:
            Text("helper.status.not_installed").foregroundStyle(.red)
        case .error:
            Text("helper.status.error").foregroundStyle(.red)
        }
    }

    private func runInstall() {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try settings.helperInstaller.install()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    private func runUninstall() {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false }
            do {
                try settings.helperInstaller.uninstall()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}
