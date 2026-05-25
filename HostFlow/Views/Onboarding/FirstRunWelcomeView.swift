import SwiftUI

struct FirstRunWelcomeView: View {

    let customCount: Int
    let onContinue: () -> Void
    let onImportJSON: () -> Void
    let onStartEmpty: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("onboarding.first_run.welcome.title")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("onboarding.first_run.welcome.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("onboarding.first_run.welcome.found.title")
                    .font(.headline)
                Text(String(
                    format: String(localized: "onboarding.first_run.welcome.found.count"),
                    customCount
                ))
                .foregroundStyle(.secondary)
                Text("onboarding.first_run.welcome.found.description")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button("onboarding.first_run.welcome.action.import_json") {
                        onImportJSON()
                    }
                    JSONFormatHelpButton()
                    Spacer()
                }

                HStack {
                    Button("onboarding.first_run.welcome.action.start_empty") {
                        onStartEmpty()
                    }
                    .buttonStyle(.link)
                    Spacer()
                    Button("onboarding.first_run.welcome.action.continue") {
                        onContinue()
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
    }
}
