import SwiftUI

struct AddRecordSheet: View {

    let profile: Profile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    @State private var ip = ""
    @State private var hostname = ""

    private var validationError: ValidationError? {
        HostValidator.validateRecord(ip: ip, hostname: hostname)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Nuovo record")
                .font(.headline)

            Form {
                TextField("IP Address", text: $ip)
                    .fontDesign(.monospaced)
                TextField("Hostname", text: $hostname)
                    .fontDesign(.monospaced)
            }
            .formStyle(.grouped)

            if let error = validationError, !ip.isEmpty || !hostname.isEmpty {
                Text(error.errorDescription ?? "")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button("Annulla", role: .cancel) { dismiss() }
                Button("Aggiungi") {
                    let trimmedIP = ip.trimmingCharacters(in: .whitespaces)
                    let trimmedHost = hostname.trimmingCharacters(in: .whitespaces)
                    let record = HostRecord(ip: trimmedIP, hostname: trimmedHost, profile: profile)
                    context.insert(record)
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
