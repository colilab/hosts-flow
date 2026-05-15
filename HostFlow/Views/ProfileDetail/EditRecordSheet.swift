import SwiftUI

struct EditRecordSheet: View {

    private enum Field: Hashable {
        case ip
        case hostname
    }

    @Bindable var record: HostRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    @State private var ip: String
    @State private var hostname: String
    @FocusState private var focusedField: Field?

    init(record: HostRecord) {
        self.record = record
        _ip = State(initialValue: record.ip)
        _hostname = State(initialValue: record.hostname)
    }

    private var validationError: ValidationError? {
        HostValidator.validateRecord(ip: ip, hostname: hostname)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("record.edit.title")
                .font(.headline)

            Form {
                TextField("record.field.ip.label", text: $ip, prompt: Text("127.0.0.1"))
                    .fontDesign(.monospaced)
                    .focused($focusedField, equals: .ip)
                TextField("record.field.hostname.label", text: $hostname, prompt: Text("example.local"))
                    .fontDesign(.monospaced)
                    .focused($focusedField, equals: .hostname)
            }
            .formStyle(.grouped)

            if let error = validationError {
                Text(error.errorDescription ?? "")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("common.button.cancel", role: .cancel) { dismiss() }
                Button("common.button.save") {
                    let trimmedIP = ip.trimmingCharacters(in: .whitespaces)
                    let trimmedHost = hostname.trimmingCharacters(in: .whitespaces)
                    record.ip = trimmedIP
                    record.hostname = trimmedHost
                    try? context.save()
                    store.scheduleWrite(context: context)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(validationError != nil)
            }
        }
        .padding(20)
        .frame(width: 360)
        .onAppear { focusedField = .ip }
    }
}
