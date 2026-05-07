import SwiftUI

struct EditRecordSheet: View {

    @Bindable var record: HostRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    private var validationError: ValidationError? {
        HostValidator.validateRecord(ip: record.ip, hostname: record.hostname)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Modifica record")
                .font(.headline)

            Form {
                TextField("IP Address", text: $record.ip)
                    .fontDesign(.monospaced)
                TextField("Hostname", text: $record.hostname)
                    .fontDesign(.monospaced)
            }
            .formStyle(.grouped)

            if let error = validationError {
                Text(error.errorDescription ?? "")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Chiudi") {
                    record.ip = record.ip.trimmingCharacters(in: .whitespaces)
                    record.hostname = record.hostname.trimmingCharacters(in: .whitespaces)
                    try? context.save()
                    store.writeHosts(context: context)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(validationError != nil)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
