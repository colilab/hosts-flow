import SwiftUI

struct AddProfileSheet: View {

    let existingNames: [String]
    let onCreate: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var trimmed: String {
        name.trimmingCharacters(in: .whitespaces)
    }

    private var validationError: String? {
        if trimmed.isEmpty { return nil }
        let normalized = existingNames.map { $0.lowercased() }
        if normalized.contains(trimmed.lowercased()) {
            return String(localized: "profile.add.error.duplicate")
        }
        return nil
    }

    private var canCreate: Bool {
        !trimmed.isEmpty && validationError == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("profile.add.title")
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                TextField("profile.add.field.name.placeholder", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit { if canCreate { create() } }

                if let error = validationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            HStack {
                Spacer()
                Button("common.button.cancel", role: .cancel) { dismiss() }
                Button("common.button.create") { create() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canCreate)
            }
        }
        .padding(20)
        .frame(width: 320)
        .onAppear { nameFocused = true }
    }

    private func create() {
        onCreate(trimmed)
        dismiss()
    }
}
