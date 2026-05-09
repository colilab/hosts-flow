import SwiftUI

struct HelperSettingsSection: View {

    @Environment(AppSettings.self) private var settings
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var showUninstallConfirm = false

    var body: some View {
        Section("Componente di sistema") {
            LabeledContent("Stato") {
                statusLabel
            }

            HStack {
                switch settings.helperStatus {
                case .installed:
                    Button("Disinstalla…", role: .destructive) {
                        showUninstallConfirm = true
                    }
                    .disabled(isWorking)
                case .notInstalled, .error:
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
        .task { settings.helperInstaller.refreshStatus() }
        .confirmationDialog(
            "Disinstallare il componente di sistema?",
            isPresented: $showUninstallConfirm,
            titleVisibility: .visible
        ) {
            Button("Disinstalla", role: .destructive) { runUninstall() }
            Button("Annulla", role: .cancel) {}
        } message: {
            Text("Verrà richiesta la password di amministratore. Senza l'helper, Host Flow non potrà più aggiornare /etc/hosts.")
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch settings.helperStatus {
        case .installed:
            Text("Installato").foregroundStyle(.secondary)
        case .notInstalled:
            Text("Non installato").foregroundStyle(.red)
        case .error:
            Text("Errore").foregroundStyle(.red)
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
