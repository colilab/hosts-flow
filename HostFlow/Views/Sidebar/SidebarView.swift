import SwiftUI
import SwiftData

struct SidebarView: View {

    @Binding var selectedProfile: Profile?
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store
    @Query(sort: \Profile.order) private var profiles: [Profile]

    @State private var isAddingProfile = false
    @State private var editingProfileID: UUID?

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
            }
            .listStyle(.sidebar)

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
        HStack {
            Toggle(isOn: $profile.isActive) {
                EmptyView()
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .disabled(profile.isReadOnly)
            .onChange(of: profile.isActive) {
                store.writeHosts(context: context)
            }

            if isEditing {
                TextField("", text: $draftName)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .onSubmit { commit() }
                    .onExitCommand { onEndEdit() }
            } else {
                Text(profile.name)
                    .lineLimit(1)
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

            Spacer()
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
