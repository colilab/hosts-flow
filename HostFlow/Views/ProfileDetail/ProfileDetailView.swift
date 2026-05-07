import SwiftUI
import SwiftData

struct ProfileDetailView: View {

    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    @State private var searchText = ""
    @State private var editingRecord: HostRecord?
    @State private var isAddingRecord = false

    private var filteredRecords: [HostRecord] {
        guard !searchText.isEmpty else { return profile.records }
        return profile.records.filter {
            $0.hostname.localizedCaseInsensitiveContains(searchText) ||
            $0.ip.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar

            Divider()

            if profile.records.isEmpty {
                ContentUnavailableView(
                    "Nessun record",
                    systemImage: "server.rack",
                    description: Text("Aggiungi un record host per questo profilo.")
                )
            } else {
                recordsList
            }
        }
        .navigationTitle(profile.name)
        .navigationSubtitle(profile.isActive ? "Attivo" : "Inattivo")
        .searchable(text: $searchText, prompt: "Cerca IP o hostname...")
        .sheet(isPresented: $isAddingRecord) {
            AddRecordSheet(profile: profile)
        }
    }

    private var toolbar: some View {
        HStack {
            Toggle(isOn: $profile.isActive) {
                Text("Profilo attivo")
                    .font(.callout)
            }
            .toggleStyle(.switch)
            .disabled(profile.isReadOnly)
            .onChange(of: profile.isActive) {
                store.writeHosts(context: context)
            }

            Spacer()

            Button {
                isAddingRecord = true
            } label: {
                Label("Aggiungi record", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(profile.isReadOnly)
            .help(profile.isReadOnly ? "Profilo di sistema — duplica per modificare" : "")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var recordsList: some View {
        Table(filteredRecords) {
            TableColumn("") { record in
                Toggle("", isOn: Binding(
                    get: { record.isEnabled },
                    set: { record.isEnabled = $0; store.writeHosts(context: context) }
                ))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .disabled(profile.isReadOnly)
            }
            .width(40)

            TableColumn("IP") { record in
                Text(record.ip)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(record.isEnabled ? .primary : .secondary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Hostname") { record in
                Text(record.hostname)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(record.isEnabled ? .primary : .secondary)
            }

            TableColumn("") { record in
                HStack(spacing: 4) {
                    Button {
                        editingRecord = record
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(profile.isReadOnly)

                    Button(role: .destructive) {
                        context.delete(record)
                        try? context.save()
                        store.writeHosts(context: context)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .disabled(profile.isReadOnly)
                }
            }
            .width(56)
        }
        .sheet(item: $editingRecord) { record in
            EditRecordSheet(record: record)
        }
    }
}
