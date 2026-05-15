import SwiftUI
import SwiftData

struct SidebarView: View {

    @Binding var selectedProfile: Profile?
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store
    @Query(sort: \Profile.order) private var profiles: [Profile]

    @State private var isAddingProfile = false
    @State private var editingProfileID: UUID?
    @State private var profileToDelete: Profile?

    var body: some View {
        List(selection: $selectedProfile) {
            ForEach(profiles, id: \.id) { profile in
                ProfileRowView(
                    profile: profile,
                    isEditing: editingProfileID == profile.id,
                    existingNames: profiles.map(\.name),
                    onBeginEdit: { editingProfileID = profile.id },
                    onEndEdit: { editingProfileID = nil }
                )
                .tag(profile)
                .moveDisabled(profile.isReadOnly)
                .contextMenu {
                    Button("Rinomina") {
                        editingProfileID = profile.id
                    }
                    .disabled(profile.isReadOnly)

                    Button("Duplica") {
                        let copy = store.duplicate(profile, context: context)
                        selectedProfile = copy
                    }

                    Button("Elimina", role: .destructive) {
                        profileToDelete = profile
                    }
                    .disabled(profile.isReadOnly)

                    Divider()

                    Button(profile.isActive ? "Disattiva" : "Attiva") {
                        profile.isActive.toggle()
                        store.scheduleWrite(context: context)
                    }
                    .disabled(profile.isReadOnly)
                }
            }
            .onMove { source, destination in
                guard destination > 0 else { return }
                var copy = Array(profiles)
                copy.move(fromOffsets: source, toOffset: destination)
                store.reorder(copy, context: context)
            }
        }
        .listStyle(.sidebar)
        .onDeleteCommand {
            if let selected = selectedProfile, !selected.isReadOnly {
                profileToDelete = selected
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    isAddingProfile = true
                } label: {
                    Label("Nuovo profilo", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.plain)

                if store.isWritingHosts {
                    ProgressView()
                        .controlSize(.small)
                        .help("Scrittura /etc/hosts in corso…")
                }

                Spacer()

                SettingsLink {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .sheet(isPresented: $isAddingProfile) {
            AddProfileSheet(existingNames: profiles.map(\.name)) { name in
                let newProfile = store.addProfile(name: name, context: context)
                selectedProfile = newProfile
            }
        }
        .confirmationDialog(
            profileToDelete.map { "Eliminare profilo \"\($0.name)\"?" } ?? "",
            isPresented: Binding(
                get: { profileToDelete != nil },
                set: { if !$0 { profileToDelete = nil } }
            ),
            presenting: profileToDelete
        ) { profile in
            Button("Elimina", role: .destructive) {
                deleteProfile(profile)
            }
            Button("Annulla", role: .cancel) { }
        } message: { _ in
            Text("L'azione non può essere annullata. Tutti i record associati verranno rimossi.")
        }
    }

    private func deleteProfile(_ profile: Profile) {
        guard !profile.isReadOnly else { return }
        let nextSelection: Profile? = {
            guard let idx = profiles.firstIndex(of: profile) else { return nil }
            if idx < profiles.count - 1 { return profiles[idx + 1] }
            if idx > 0 { return profiles[idx - 1] }
            return nil
        }()
        store.deleteProfile(profile, context: context)
        selectedProfile = nextSelection
    }
}

private struct ProfileRowView: View {

    @Bindable var profile: Profile
    let isEditing: Bool
    let existingNames: [String]
    let onBeginEdit: () -> Void
    let onEndEdit: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

    @State private var draftName = ""
    @State private var isDropTargeted = false
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        let row = HStack(spacing: 8) {
            if isEditing {
                TextField("", text: $draftName)
                    .textFieldStyle(.plain)
                    .lineLimit(1)
                    .focused($isFieldFocused)
                    .onSubmit { commit() }
                    .onExitCommand { onEndEdit() }
            } else {
                Text(profile.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if profile.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Toggle(isOn: $profile.isActive) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .labelsHidden()
            .disabled(profile.isReadOnly)
            .onChange(of: profile.isActive) {
                store.scheduleWrite(context: context)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.accentColor.opacity(isDropTargeted ? 0.2 : 0))
        )
        .help(profile.isReadOnly ? "Profilo di sistema — duplica per modificare" : "")
        .onChange(of: isEditing) { _, editing in
            if editing {
                draftName = profile.name
                isFieldFocused = true
            }
        }
        .onChange(of: isFieldFocused) { _, focused in
            if !focused && isEditing {
                commit()
            }
        }

        if profile.isReadOnly {
            row
        } else {
            row.dropDestination(for: HostRecordTransfer.self) { items, _ in
                handleDrop(items)
            } isTargeted: { targeted in
                isDropTargeted = targeted
            }
        }
    }

    private func handleDrop(_ items: [HostRecordTransfer]) -> Bool {
        guard !profile.isReadOnly else { return false }
        let ids = items.map(\.id)
        guard !ids.isEmpty else { return false }
        let descriptor = FetchDescriptor<HostRecord>(predicate: #Predicate { record in
            ids.contains(record.id)
        })
        guard let records = try? context.fetch(descriptor), !records.isEmpty else { return false }
        store.moveRecords(records, to: profile, context: context)
        return true
    }

    private func commit() {
        let trimmed = draftName.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == profile.name {
            onEndEdit()
            return
        }
        let othersLowered = existingNames
            .filter { $0.lowercased() != profile.name.lowercased() }
            .map { $0.lowercased() }
        if othersLowered.contains(trimmed.lowercased()) {
            onEndEdit()
            return
        }
        profile.name = trimmed
        try? context.save()
        onEndEdit()
    }
}

