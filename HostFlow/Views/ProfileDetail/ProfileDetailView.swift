import SwiftUI
import SwiftData
import AppKit
import UniformTypeIdentifiers

struct ProfileDetailView: View {

    @Bindable var profile: Profile
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store
    @Query private var allProfiles: [Profile]

    @State private var searchText = ""
    @State private var editingRecord: HostRecord?
    @State private var isAddingRecord = false
    @State private var selectedRecordIDs: Set<UUID> = []
    @State private var hudMessage: LocalizedStringKey?
    @State private var saveError: String?
    @State private var sortOrder: [KeyPathComparator<HostRecord>] = []

    private var filteredRecords: [HostRecord] {
        let base: [HostRecord]
        if searchText.isEmpty {
            base = profile.records
        } else {
            base = profile.records.filter {
                $0.hostname.localizedCaseInsensitiveContains(searchText) ||
                $0.ip.localizedCaseInsensitiveContains(searchText)
            }
        }
        return sortOrder.isEmpty ? base : base.sorted(using: sortOrder)
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
                    "profile.detail.empty.title",
                    systemImage: "server.rack",
                    description: Text("profile.detail.empty.description")
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
        .searchable(text: $searchText, prompt: Text("profile.detail.search.prompt"))
        .sheet(isPresented: $isAddingRecord) {
            AddRecordSheet(profile: profile)
        }
        .overlay(alignment: .top) {
            if let hudMessage {
                Label(hudMessage, systemImage: "checkmark.circle.fill")
                    .font(.callout)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.top, 12)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hudMessage != nil)
        .alert(
            "profile.detail.export.save.error.title",
            isPresented: Binding(
                get: { saveError != nil },
                set: { if !$0 { saveError = nil } }
            ),
            presenting: saveError
        ) { _ in
            Button("common.button.ok", role: .cancel) {}
        } message: { message in
            Text(message)
        }
    }

    private var toolbar: some View {
        HStack {
            Toggle(isOn: $profile.isActive) {
                Text("profile.detail.toggle.active")
                    .font(.callout)
            }
            .toggleStyle(.switch)
            .disabled(profile.isReadOnly)
            .onChange(of: profile.isActive) {
                store.scheduleWrite(context: context)
            }

            Spacer()

            Menu {
                Button("profile.detail.export.copy") { copyToClipboard() }
                Button("profile.detail.export.save") { saveToFile() }
            } label: {
                Label("profile.detail.export.menu", systemImage: "square.and.arrow.up")
            }
            .menuStyle(.borderlessButton)
            .controlSize(.small)
            .fixedSize()
            .disabled(profile.isReadOnly)

            Button {
                isAddingRecord = true
            } label: {
                Label("profile.detail.button.add_record", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(profile.isReadOnly)
            .help(profile.isReadOnly ? String(localized: "profile.detail.readonly.help") : "")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func copyToClipboard() {
        let text = HostsFileManager.shared.formatProfile(profile)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showHUD("profile.detail.export.copied")
    }

    private func saveToFile() {
        let text = HostsFileManager.shared.formatProfile(profile)
        let panel = NSSavePanel()
        panel.title = String(localized: "profile.detail.export.save.panel.title")
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = defaultExportFilename
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                try text.write(to: url, atomically: true, encoding: .utf8)
                showHUD("profile.detail.export.saved")
            } catch {
                saveError = error.localizedDescription
            }
        }
    }

    private var defaultExportFilename: String {
        let slug = profile.name
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
        return "\(slug).hosts"
    }

    private func showHUD(_ key: LocalizedStringKey) {
        hudMessage = key
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(1500))
            hudMessage = nil
        }
    }

    private var moveTargets: [Profile] {
        allProfiles
            .filter { !$0.isReadOnly && $0.id != profile.id }
            .sorted { $0.order < $1.order }
    }

    private var recordsList: some View {
        Table(of: HostRecord.self, selection: $selectedRecordIDs, sortOrder: $sortOrder) {
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

            TableColumn("profile.detail.column.ip", sortUsing: KeyPathComparator(\HostRecord.ip)) { record in
                Text(record.ip)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(record.isEnabled ? .primary : .secondary)
            }
            .width(min: 100, ideal: 140)

            TableColumn("profile.detail.column.hostname", sortUsing: KeyPathComparator(\HostRecord.hostname)) { record in
                HStack(spacing: 4) {
                    Text(record.hostname)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(record.isEnabled ? .primary : .secondary)
                        .opacity(record.isEnabled ? 1.0 : 0.5)
                    if duplicatedPairs.contains(RecordPair(ip: record.ip.lowercased(), hostname: record.hostname.lowercased())) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                            .help("profile.detail.duplicate.help")
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
                Button("common.button.edit") {
                    editingRecord = record
                }
                .disabled(profile.isReadOnly)
            }
            if !items.isEmpty && !profile.isReadOnly {
                Menu("profile.detail.menu.move_to") {
                    ForEach(moveTargets, id: \.id) { target in
                        Button(target.name) {
                            moveRecords(ids: items, to: target)
                        }
                    }
                }
                .disabled(moveTargets.isEmpty)
            }
            if !items.isEmpty {
                Button("common.button.delete", role: .destructive) {
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
