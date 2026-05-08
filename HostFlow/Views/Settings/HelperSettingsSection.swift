import SwiftUI

struct HelperSettingsSection: View {

    @State private var installer = HelperInstaller()
    @State private var isInstalled = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        Section("Componente di sistema") {
            LabeledContent("Stato") {
                Text(isInstalled ? "Installato" : "Non installato")
                    .foregroundStyle(isInstalled ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.red))
            }

            HStack {
                if isInstalled {
                    Button("Disinstalla…", role: .destructive) {
                        runUninstall()
                    }
                    .disabled(isWorking)
                } else {
                    Button("Installa…") {
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
        .task { refresh() }
    }

    private func refresh() {
        isInstalled = installer.isInstalled
    }

    private func runInstall() {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false; refresh() }
            do {
                try installer.install()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    private func runUninstall() {
        isWorking = true
        errorMessage = nil
        Task {
            defer { isWorking = false; refresh() }
            do {
                try installer.uninstall()
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}
