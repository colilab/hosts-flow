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

    @discardableResult
    func addProfile(name: String, context: ModelContext) -> Profile {
        let existing = (try? context.fetch(FetchDescriptor<Profile>())) ?? []
        let nextOrder = (existing.map(\.order).max() ?? -1) + 1
        let profile = Profile(name: name, order: nextOrder)
        context.insert(profile)
        try? context.save()
        return profile
    }

    func reorder(_ profiles: [Profile], context: ModelContext) {
        for (index, profile) in profiles.enumerated() {
            profile.order = index
        }
        try? context.save()
    }

    func deleteProfile(_ profile: Profile, context: ModelContext) {
        context.delete(profile)
        try? context.save()
        writeHosts(context: context)
    }

    func canEdit(_ profile: Profile) -> Bool {
        profile.isEditable
    }

    func seedIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Profile>())) ?? 0
        guard count == 0 else { return }

        let profile = Profile(name: "Default", order: 0, isReadOnly: true)
        profile.isActive = true
        context.insert(profile)

        let parsed: [ParsedHostRecord]
        do {
            parsed = try HostsFileParser.parseSystemHosts()
        } catch {
            print("HostFlow: seed could not read /etc/hosts — \(error.localizedDescription). Creating empty Default.")
            parsed = []
        }

        for entry in parsed {
            let record = HostRecord(ip: entry.ip, hostname: entry.hostname, profile: profile)
            record.isEnabled = entry.isEnabled
            context.insert(record)
        }

        try? context.save()
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
