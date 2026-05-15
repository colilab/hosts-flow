import SwiftUI

struct ImportJSONSheet: View {

    let result: ImportJSONResult
    let userProfileCount: Int
    let onConfirm: (ImportMode) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var mode: ImportMode = .merge
    @State private var showReplaceConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("import.json.sheet.title")
                .font(.headline)

            Text(String.localizedStringWithFormat(
                NSLocalizedString("import.json.count", comment: ""),
                result.profileCount,
                result.recordCount
            ))
            .font(.callout)
            .foregroundStyle(.secondary)

            Picker("import.json.mode.label", selection: $mode) {
                ForEach(ImportMode.allCases) { option in
                    Text(option.labelKey).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Text(mode.descriptionKey)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()
                Button("common.button.cancel", role: .cancel) { dismiss() }
                Button("import.button.import") { confirmTapped() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
        .alert(
            "import.json.replace.confirm.title",
            isPresented: $showReplaceConfirm
        ) {
            Button("common.button.cancel", role: .cancel) {}
            Button("import.json.replace.confirm.button", role: .destructive) {
                onConfirm(.replace)
                dismiss()
            }
        } message: {
            Text(String.localizedStringWithFormat(
                NSLocalizedString("import.json.replace.confirm.message", comment: ""),
                userProfileCount
            ))
        }
    }

    private func confirmTapped() {
        switch mode {
        case .merge:
            onConfirm(.merge)
            dismiss()
        case .replace:
            showReplaceConfirm = true
        }
    }
}
