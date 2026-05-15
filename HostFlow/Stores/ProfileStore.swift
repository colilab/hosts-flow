import Foundation
import SwiftData
import Observation

@Observable
final class ProfileStore {

    private(set) var isWritingHosts = false
    private(set) var lastWriteAt: Date?
    var lastWriteError: String?
    var helperMissing = false

    @ObservationIgnored
    private var writeDebouncer: Task<Void, Never>?

    private static let debounceInterval: Duration = .milliseconds(500)

    func toggleProfile(_ profile: Profile, context: ModelContext) {
        profile.isActive.toggle()
        try? context.save()
        scheduleWrite(context: context)
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
        scheduleWrite(context: context)
    }

    func deleteProfile(_ profile: Profile, context: ModelContext) {
        context.delete(profile)
        try? context.save()
        scheduleWrite(context: context)
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

    func moveRecords(_ records: [HostRecord], to destination: Profile, context: ModelContext) {
        guard !destination.isReadOnly else { return }
        var moved = false
        for record in records {
            guard record.profile?.id != destination.id else { continue }
            if let source = record.profile, source.isReadOnly { continue }
            record.profile = destination
            moved = true
        }
        guard moved else { return }
        try? context.save()
        scheduleWrite(context: context)
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

    func syncDefaultFromFile(context: ModelContext) {
        let parsed: [ParsedHostRecord]
        do {
            let content = try HostsFileManager.shared.read()
            parsed = HostsFileParser.parseUnmanaged(content)
        } catch {
            print("HostFlow: watcher could not read /etc/hosts — \(error.localizedDescription)")
            return
        }

        let descriptor = FetchDescriptor<Profile>(predicate: #Predicate { $0.isReadOnly == true })
        guard let defaultProfile = (try? context.fetch(descriptor))?.first else { return }

        struct Key: Hashable { let ip: String; let hostname: String }
        var existing: [Key: HostRecord] = [:]
        for record in defaultProfile.records {
            existing[Key(ip: record.ip, hostname: record.hostname)] = record
        }

        var seen = Set<Key>()
        var changed = false
        for entry in parsed {
            let key = Key(ip: entry.ip, hostname: entry.hostname)
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if let record = existing[key] {
                if record.isEnabled != entry.isEnabled {
                    record.isEnabled = entry.isEnabled
                    changed = true
                }
            } else {
                let record = HostRecord(ip: entry.ip, hostname: entry.hostname, profile: defaultProfile)
                record.isEnabled = entry.isEnabled
                context.insert(record)
                changed = true
            }
        }

        for (key, record) in existing where !seen.contains(key) {
            context.delete(record)
            changed = true
        }

        if changed {
            try? context.save()
        }
    }

    func scheduleWrite(context: ModelContext) {
        writeDebouncer?.cancel()
        writeDebouncer = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.debounceInterval)
            guard !Task.isCancelled else { return }
            self?.writeDebouncer = nil
            self?.writeHostsImmediate(context: context)
        }
    }

    func writeHosts(context: ModelContext) {
        writeDebouncer?.cancel()
        writeDebouncer = nil
        writeHostsImmediate(context: context)
    }

    func flushPendingWrite(context: ModelContext) {
        guard writeDebouncer != nil else { return }
        writeDebouncer?.cancel()
        writeDebouncer = nil
        writeHostsImmediate(context: context)
    }

    func resetManagedBlock(context: ModelContext) {
        writeDebouncer?.cancel()
        writeDebouncer = nil

        let userProfiles = (try? context.fetch(
            FetchDescriptor<Profile>(predicate: #Predicate { $0.isReadOnly == false })
        )) ?? []
        for profile in userProfiles {
            context.delete(profile)
        }

        let defaultProfile = (try? context.fetch(
            FetchDescriptor<Profile>(predicate: #Predicate { $0.isReadOnly == true })
        ))?.first
        defaultProfile?.isActive = true

        try? context.save()

        HelperInstaller.shared.refreshStatus()
        if !HelperInstaller.shared.isInstalled {
            helperMissing = true
            return
        }

        isWritingHosts = true
        lastWriteError = nil
        Task { @MainActor [weak self] in
            defer { self?.isWritingHosts = false }
            do {
                try await HostsFileManager.shared.removeManagedBlock()
                self?.lastWriteAt = Date()
            } catch {
                self?.lastWriteError = error.localizedDescription
            }
        }
    }

    private func writeHostsImmediate(context: ModelContext) {
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
                self?.lastWriteAt = Date()
            } catch {
                self?.lastWriteError = error.localizedDescription
            }
        }
    }
}
