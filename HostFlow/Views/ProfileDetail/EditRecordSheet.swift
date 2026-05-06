import SwiftUI

struct EditRecordSheet: View {

    @Bindable var record: HostRecord
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

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

            HStack {
                Spacer()
                Button("Chiudi") {
                    try? context.save()
                    store.writeHosts(context: context)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 360)
    }
}
