import SwiftUI

struct HelperOnboardingSheet: View {
    let installer: HelperInstaller
    let onDismiss: (Bool) -> Void

    @State private var isInstalling = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                Text("Installa il componente di sistema")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Text("Host Flow ha bisogno di un piccolo componente di sistema per scrivere `/etc/hosts`. L'installazione richiede la password di amministratore una sola volta. Da quel momento, le modifiche saranno applicate automaticamente.")
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Spacer()
                Button("Annulla") {
                    onDismiss(false)
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isInstalling)

                Button("Installa…") {
                    runInstall()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(isInstalling)
            }
        }
        .padding(24)
        .frame(width: 480, height: 220)
    }

    private func runInstall() {
        isInstalling = true
        errorMessage = nil
        Task {
            defer { isInstalling = false }
            do {
                try installer.install()
                onDismiss(true)
            } catch {
                errorMessage = (error as NSError).localizedDescription
            }
        }
    }
}
