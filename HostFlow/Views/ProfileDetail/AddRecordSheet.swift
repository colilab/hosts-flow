import SwiftUI

struct AddRecordSheet: View {

    let profile: Profile
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    @State private var ip = ""
    @State private var hostname = ""

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

            HStack {
                Spacer()
                Button("Annulla", role: .cancel) { dismiss() }
                Button("Aggiungi") {
                    let record = HostRecord(ip: ip, hostname: hostname, profile: profile)
                    context.insert(record)
                    try? context.save()
                    store.writeHosts(context: context)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(ip.isEmpty || hostname.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
