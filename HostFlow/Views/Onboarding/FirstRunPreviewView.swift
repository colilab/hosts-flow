import SwiftUI

struct FirstRunPreviewView: View {

    let customs: [ParsedHostRecord]
    let systemEntries: [ParsedHostRecord]
    @Binding var profileName: String
    let onBack: () -> Void
    let onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "tray.and.arrow.down")
                    .font(.largeTitle)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("onboarding.first_run.preview.title")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("onboarding.first_run.preview.subtitle")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("onboarding.first_run.preview.profile_name.label")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                TextField("onboarding.first_run.preview.profile_name.placeholder", text: $profileName)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(String(
                    format: String(localized: "onboarding.first_run.preview.customs.title"),
                    customs.count
                ))
                .font(.headline)
                recordList(customs, dimmedWhenDisabled: true)
                    .frame(maxHeight: 180)
            }

            DisclosureGroup {
                recordList(systemEntries, dimmedWhenDisabled: false)
                    .frame(maxHeight: 100)
            } label: {
                Text("onboarding.first_run.preview.system.title")
                    .font(.headline)
            }

            Spacer()

            HStack {
                Button("common.button.back") {
                    onBack()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("onboarding.first_run.preview.action.apply") {
                    onApply()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
    }

    private func recordList(_ records: [ParsedHostRecord], dimmedWhenDisabled: Bool) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(records.enumerated()), id: \.offset) { _, record in
                    HStack(spacing: 8) {
                        Text(record.ip)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minWidth: 110, alignment: .leading)
                        Text(record.hostname)
                            .font(.system(.caption, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !record.isEnabled {
                            Text("onboarding.first_run.preview.record.disabled")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .opacity(dimmedWhenDisabled && !record.isEnabled ? 0.55 : 1.0)
                }
            }
            .padding(8)
        }
        .background(Color(nsColor: .textBackgroundColor))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
