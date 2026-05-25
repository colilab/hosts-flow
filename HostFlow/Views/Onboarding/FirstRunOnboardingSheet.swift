import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

enum FirstRunOnboardingStep {
    case welcome
    case preview
}

enum FirstRunOnboardingOutcome {
    case dismissed
    case importedFromJSON(ImportJSONResult, ImportMode)
}

struct FirstRunOnboardingSheet: View {

    let customs: [ParsedHostRecord]
    let onComplete: (FirstRunOnboardingOutcome) -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(ProfileStore.self) private var store

    @State private var step: FirstRunOnboardingStep = .welcome
    @State private var profileName: String = ""
    @State private var importJSONResult: ImportJSONResult?
    @State private var importJSONError: String?
    @State private var showStartEmptyConfirm = false

    var body: some View {
        Group {
            switch step {
            case .welcome:
                FirstRunWelcomeView(
                    customCount: customs.count,
                    onContinue: {
                        profileName = String(localized: "onboarding.first_run.profile.imported.default_name")
                        step = .preview
                    },
                    onImportJSON: { startImportJSON() },
                    onStartEmpty: { showStartEmptyConfirm = true }
                )
            case .preview:
                FirstRunPreviewView(
                    customs: customs,
                    systemEntries: SystemHostEntries.canonicalEntries,
                    profileName: $profileName,
                    onBack: { step = .welcome },
                    onApply: { applyImport() }
                )
            }
        }
        .frame(width: 560, height: 560)
        .alert(
            "onboarding.first_run.start_empty.confirm.title",
            isPresented: $showStartEmptyConfirm
        ) {
            Button("common.button.cancel", role: .cancel) {}
            Button("onboarding.first_run.start_empty.confirm.button", role: .destructive) {
                store.markFirstRunOnboardingCompleted()
                onComplete(.dismissed)
            }
        } message: {
            Text("onboarding.first_run.start_empty.confirm.message")
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
                userProfileCount: 0
            ) { mode in
                store.applyImport(result.payload, mode: mode, context: modelContext)
                store.markFirstRunOnboardingCompleted()
                onComplete(.importedFromJSON(result, mode))
            }
        }
    }

    private func applyImport() {
        store.completeOnboardingImporting(
            customs: customs,
            profileName: profileName,
            context: modelContext
        )
        onComplete(.dismissed)
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
}
