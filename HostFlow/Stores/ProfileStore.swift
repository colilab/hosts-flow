import Foundation
import SwiftData
import Observation

@Observable
final class ProfileStore {

    private(set) var isWritingHosts = false
    private(set) var lastWriteError: String?

    func toggleProfile(_ profile: Profile, context: ModelContext) {
        profile.isActive.toggle()
        try? context.save()
        writeHosts(context: context)
    }

    func addProfile(name: String, context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Profile>())) ?? 0
        let profile = Profile(name: name, order: count)
        context.insert(profile)
        try? context.save()
    }

    func deleteProfile(_ profile: Profile, context: ModelContext) {
        context.delete(profile)
        try? context.save()
        writeHosts(context: context)
    }

    func writeHosts(context: ModelContext) {
        let descriptor = FetchDescriptor<Profile>()
        guard let profiles = try? context.fetch(descriptor) else { return }
        isWritingHosts = true
        lastWriteError = nil
        do {
            try HostsFileManager.shared.write(profiles: profiles)
        } catch {
            lastWriteError = error.localizedDescription
        }
        isWritingHosts = false
    }
}
