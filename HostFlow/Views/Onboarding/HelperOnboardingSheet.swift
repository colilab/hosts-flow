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
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                Text("onboarding.helper.title")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            Text("onboarding.helper.description")
                .foregroundStyle(.secondary)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Spacer()

            HStack {
                Spacer()
                Button("common.button.cancel") {
                    onDismiss(false)
                }
                .keyboardShortcut(.cancelAction)
                .disabled(isInstalling)

                Button("common.button.install") {
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
