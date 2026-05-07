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
        VStack(spacing: 0) {
            List(profiles, selection: $selectedProfile) { profile in
                ProfileRowView(
                    profile: profile,
                    isEditing: editingProfileID == profile.id,
                    existingNames: profiles.map(\.name),
                    onBeginEdit: { editingProfileID = profile.id },
                    onEndEdit: { editingProfileID = nil }
                )
                .tag(profile)
                .contextMenu {
                    Button("Elimina", role: .destructive) {
                        profileToDelete = profile
                    }
                    .disabled(profile.isReadOnly)
                }
            }
            .listStyle(.sidebar)
            .onDeleteCommand {
                if let selected = selectedProfile, !selected.isReadOnly {
                    profileToDelete = selected
                }
            }

            Divider()

            HStack {
                Button {
                    isAddingProfile = true
                } label: {
                    Label("Nuovo profilo", systemImage: "plus")
                        .font(.callout)
                }
                .buttonStyle(.plain)
                .padding(.leading, 12)

                Spacer()

                SettingsLink {
                    Image(systemName: "gear")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
            }
            .frame(height: 36)
        }
        .frame(maxHeight: .infinity)
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
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
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
                    .onTapGesture(count: 2) {
                        guard !profile.isReadOnly else { return }
                        draftName = profile.name
                        onBeginEdit()
                    }
            }

            if profile.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Toggle(isOn: $profile.isActive) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(profile.isReadOnly)
            .onChange(of: profile.isActive) {
                store.writeHosts(context: context)
            }
        }
        .padding(.vertical, 2)
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
