import SwiftUI
import SwiftData

struct ProfileDetailView: View {

    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store
    @Query private var allProfiles: [Profile]

    @State private var searchText = ""
    @State private var editingRecord: HostRecord?
    @State private var isAddingRecord = false
    @State private var selectedRecordIDs: Set<UUID> = []

    private var filteredRecords: [HostRecord] {
        guard !searchText.isEmpty else { return profile.records }
        return profile.records.filter {
            $0.hostname.localizedCaseInsensitiveContains(searchText) ||
            $0.ip.localizedCaseInsensitiveContains(searchText)
        }
    }

    private struct RecordPair: Hashable {
        let ip: String
        let hostname: String
    }

    private var duplicatedPairs: Set<RecordPair> {
        var counts: [RecordPair: Int] = [:]
        for r in profile.records {
            counts[RecordPair(ip: r.ip.lowercased(), hostname: r.hostname.lowercased()), default: 0] += 1
        }
        for p in allProfiles where p.isActive && p.id != profile.id {
            for r in p.records where r.isEnabled {
                counts[RecordPair(ip: r.ip.lowercased(), hostname: r.hostname.lowercased()), default: 0] += 1
            }
        }
        return Set(counts.filter { $0.value > 1 }.keys)
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
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if !searchText.isEmpty && filteredRecords.isEmpty {
                ContentUnavailableView.search(text: searchText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                recordsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .searchable(text: $searchText, prompt: "Cerca IP o hostname")
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
                store.scheduleWrite(context: context)
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
        .padding(.vertical, 8)
    }

    private var moveTargets: [Profile] {
        allProfiles
            .filter { !$0.isReadOnly && $0.id != profile.id }
            .sorted { $0.order < $1.order }
    }

    private var recordsList: some View {
        Table(of: HostRecord.self, selection: $selectedRecordIDs) {
            TableColumn("") { record in
                Toggle("", isOn: Binding(
                    get: { record.isEnabled },
                    set: { record.isEnabled = $0; store.scheduleWrite(context: context) }
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
                HStack(spacing: 4) {
                    Text(record.hostname)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(record.isEnabled ? .primary : .secondary)
                        .opacity(record.isEnabled ? 1.0 : 0.5)
                    if duplicatedPairs.contains(RecordPair(ip: record.ip.lowercased(), hostname: record.hostname.lowercased())) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("Record duplicato — stessa coppia IP/hostname presente più volte")
                    }
                }
            }
        } rows: {
            ForEach(filteredRecords) { record in
                let row = TableRow(record)
                if profile.isReadOnly {
                    row
                } else {
                    row.draggable(HostRecordTransfer(id: record.id))
                }
            }
        }
        .contextMenu(forSelectionType: HostRecord.ID.self) { items in
            if items.count == 1,
               let id = items.first,
               let record = profile.records.first(where: { $0.id == id }) {
                Button("Modifica") {
                    editingRecord = record
                }
                .disabled(profile.isReadOnly)
            }
            if !items.isEmpty && !profile.isReadOnly {
                Menu("Sposta in") {
                    ForEach(moveTargets, id: \.id) { target in
                        Button(target.name) {
                            moveRecords(ids: items, to: target)
                        }
                    }
                }
                .disabled(moveTargets.isEmpty)
            }
            if !items.isEmpty {
                Button("Elimina", role: .destructive) {
                    deleteRecords(ids: items)
                }
                .disabled(profile.isReadOnly)
            }
        }
        .onDeleteCommand {
            guard !profile.isReadOnly, !selectedRecordIDs.isEmpty else { return }
            deleteRecords(ids: selectedRecordIDs)
        }
        .sheet(item: $editingRecord) { record in
            EditRecordSheet(record: record)
        }
    }

    private func moveRecords(ids: Set<UUID>, to destination: Profile) {
        let records = profile.records.filter { ids.contains($0.id) }
        guard !records.isEmpty else { return }
        store.moveRecords(records, to: destination, context: context)
        selectedRecordIDs.removeAll()
    }

    private func deleteRecords(ids: Set<UUID>) {
        for id in ids {
            if let record = profile.records.first(where: { $0.id == id }) {
                context.delete(record)
            }
        }
        try? context.save()
        store.scheduleWrite(context: context)
        selectedRecordIDs.removeAll()
    }
}
