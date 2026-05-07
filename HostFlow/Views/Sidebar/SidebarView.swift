import SwiftUI
import SwiftData

struct SidebarView: View {

    @Binding var selectedProfile: Profile?
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store
    @Query(sort: \Profile.order) private var profiles: [Profile]

    @State private var isAddingProfile = false

    var body: some View {
        VStack(spacing: 0) {
            List(profiles, selection: $selectedProfile) { profile in
                ProfileRowView(profile: profile)
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
    @Environment(\.modelContext) private var context
    @Environment(ProfileStore.self) private var store

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

            Text(profile.name)
                .lineLimit(1)

            if profile.isReadOnly {
                Image(systemName: "lock.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .help(profile.isReadOnly ? "Profilo di sistema — duplica per modificare" : "")
    }
}
