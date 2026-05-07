import SwiftUI
import SwiftData

struct ProfileDetailView: View {

    private struct CellAddress: Hashable {
        enum FieldType { case ip, hostname }
        let recordID: UUID
        let field: FieldType
    }

    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    @State private var searchText = ""
    @State private var editingRecord: HostRecord?
    @State private var isAddingRecord = false
    @State private var editingCell: CellAddress?
    @State private var draftValue = ""
    @State private var validationFailed = false
    @State private var selectedRecordIDs: Set<UUID> = []
    @FocusState private var focusedCell: CellAddress?

    private var filteredRecords: [HostRecord] {
        guard !searchText.isEmpty else { return profile.records }
        return profile.records.filter {
            $0.hostname.localizedCaseInsensitiveContains(searchText) ||
            $0.ip.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar

            toolbar

            Divider()

            if profile.records.isEmpty {
                ContentUnavailableView(
                    "Nessun record",
                    systemImage: "server.rack",
                    description: Text("Aggiungi un record host per questo profilo.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                recordsList
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $isAddingRecord) {
            AddRecordSheet(profile: profile)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Cerca IP o hostname...", text: $searchText)
                .textFieldStyle(.plain)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
        .padding(.top, 16)
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
        Table(filteredRecords, selection: $selectedRecordIDs) {
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
                editableCell(record: record, field: .ip, value: record.ip)
            }
            .width(min: 100, ideal: 140)

            TableColumn("Hostname") { record in
                editableCell(record: record, field: .hostname, value: record.hostname)
            }
        }
        .contextMenu(forSelectionType: HostRecord.ID.self) { items in
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

    private func deleteRecords(ids: Set<UUID>) {
        for id in ids {
            if let record = profile.records.first(where: { $0.id == id }) {
                context.delete(record)
            }
        }
        try? context.save()
        store.writeHosts(context: context)
        selectedRecordIDs.removeAll()
    }

    @ViewBuilder
    private func editableCell(record: HostRecord, field: CellAddress.FieldType, value: String) -> some View {
        let address = CellAddress(recordID: record.id, field: field)

        if editingCell == address {
            TextField("", text: $draftValue)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .focused($focusedCell, equals: address)
                .submitLabel(field == .ip ? .next : .return)
                .onSubmit { commitEdit(record: record, address: address, advance: true) }
                .onExitCommand { cancelEdit() }
                .onKeyPress(.tab) {
                    commitEdit(record: record, address: address, advance: address.field == .ip)
                    return .handled
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.red, lineWidth: 1)
                        .opacity(validationFailed ? 1 : 0)
                )
        } else {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(record.isEnabled ? .primary : .secondary)
                .opacity(record.isEnabled ? 1.0 : 0.5)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    guard !profile.isReadOnly else { return }
                    startEdit(address: address, value: value)
                }
        }
    }

    private func startEdit(address: CellAddress, value: String) {
        draftValue = value
        validationFailed = false
        editingCell = address
        focusedCell = address
    }

    private func commitEdit(record: HostRecord, address: CellAddress, advance: Bool) {
        validationFailed = false
        let trimmed = draftValue.trimmingCharacters(in: .whitespaces)

        let isValid: Bool
        switch address.field {
        case .ip: isValid = HostValidator.isValidIP(trimmed)
        case .hostname: isValid = HostValidator.isValidHostname(trimmed)
        }

        guard isValid else {
            validationFailed = true
            return
        }

        switch address.field {
        case .ip: record.ip = trimmed
        case .hostname: record.hostname = trimmed
        }
        try? context.save()
        store.writeHosts(context: context)

        if advance && address.field == .ip {
            let next = CellAddress(recordID: record.id, field: .hostname)
            draftValue = record.hostname
            editingCell = next
            focusedCell = next
        } else {
            cancelEdit()
        }
    }

    private func cancelEdit() {
        editingCell = nil
        focusedCell = nil
        validationFailed = false
    }
}
