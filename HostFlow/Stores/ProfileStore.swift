import Foundation
import SwiftData
import Observation

@Observable
final class ProfileStore {

    private(set) var isWritingHosts = false
    private(set) var lastWriteError: String?
    var helperMissing = false

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
        writeHosts(context: context)
    }

    func deleteProfile(_ profile: Profile, context: ModelContext) {
        context.delete(profile)
        try? context.save()
        writeHosts(context: context)
    }

    @discardableResult
    func duplicate(_ profile: Profile, context: ModelContext) -> Profile {
        let existing = (try? context.fetch(FetchDescriptor<Profile>())) ?? []
        let nextOrder = (existing.map(\.order).max() ?? -1) + 1
        let name = uniqueDuplicateName(base: profile.name, among: existing.map(\.name))
        let copy = Profile(name: name, order: nextOrder, isReadOnly: false)
        context.insert(copy)
        for source in profile.records {
            let record = HostRecord(ip: source.ip, hostname: source.hostname, profile: copy)
            record.isEnabled = source.isEnabled
            context.insert(record)
        }
        try? context.save()
        return copy
    }

    private func uniqueDuplicateName(base: String, among existing: [String]) -> String {
        let lowered = Set(existing.map { $0.lowercased() })
        var candidate = "\(base) (copia)"
        if !lowered.contains(candidate.lowercased()) { return candidate }
        var i = 2
        while true {
            candidate = "\(base) (copia \(i))"
            if !lowered.contains(candidate.lowercased()) { return candidate }
            i += 1
        }
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
        HelperInstaller.shared.refreshStatus()
        if !HelperInstaller.shared.isInstalled {
            helperMissing = true
            return
        }
        let descriptor = FetchDescriptor<Profile>()
        guard let profiles = try? context.fetch(descriptor) else { return }
        isWritingHosts = true
        lastWriteError = nil
        Task { @MainActor [weak self] in
            defer { self?.isWritingHosts = false }
            do {
                try await HostsFileManager.shared.write(profiles: profiles)
            } catch {
                self?.lastWriteError = error.localizedDescription
            }
        }
    }
}
