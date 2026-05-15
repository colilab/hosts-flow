import SwiftUI

struct ImportProfileSheet: View {

    let suggestedName: String
    let records: [ParsedHostRecord]
    let existingNames: [String]
    let onImport: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String = ""
    @FocusState private var nameFocused: Bool

    private struct PreviewRow: Identifiable {
        let id = UUID()
        let record: ParsedHostRecord
    }

    private var rows: [PreviewRow] {
        records.map { PreviewRow(record: $0) }
    }

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var validationError: String? {
        guard !trimmed.isEmpty else { return nil }
        let normalized = existingNames.map { $0.lowercased() }
        if normalized.contains(trimmed.lowercased()) {
            return String(localized: "profile.add.error.duplicate")
        }
        return nil
    }

    private var canImport: Bool {
        !trimmed.isEmpty && validationError == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("import.sheet.title")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("profile.add.field.name.placeholder", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Text(String.localizedStringWithFormat(
                NSLocalizedString("import.records.count", comment: ""),
                records.count
            ))
            .font(.caption)
            .foregroundStyle(.secondary)

            Table(rows) {
                TableColumn("import.column.ip") { row in
                    Text(row.record.ip)
                        .font(.system(.body, design: .monospaced))
                }
                .width(min: 100, ideal: 140)

                TableColumn("import.column.hostname") { row in
                    Text(row.record.hostname)
                        .font(.system(.body, design: .monospaced))
                }

                TableColumn("import.column.enabled") { row in
                    Image(systemName: row.record.isEnabled ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(row.record.isEnabled ? Color.green : .secondary)
                }
                .width(60)
            }
            .frame(minHeight: 200, idealHeight: 240)

            HStack {
                Spacer()
                Button("common.button.cancel", role: .cancel) { dismiss() }
                Button("import.button.import") {
                    onImport(trimmed)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canImport)
            }
        }
        .padding(24)
        .frame(width: 520)
        .onAppear {
            name = suggestedName
            nameFocused = true
        }
    }
}
