import Foundation
import SwiftData
import Darwin

@MainActor
final class HostsFileWatcher {

    private let hostsPath = "/etc/hosts"
    private let queue = DispatchQueue(label: "com.colilab.hostflow.watcher", qos: .utility)
    private static let debounceNanos: UInt64 = 300_000_000
    private static let mtimeToleranceSeconds: TimeInterval = 2.0
    private static let reopenBackoffsMs: [UInt64] = [50, 100, 200, 500, 1_000, 2_000]

    private var fd: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private var debounceTask: Task<Void, Never>?
    private var profileStore: ProfileStore?
    private var context: ModelContext?
    private var started = false

    func start(profileStore: ProfileStore, context: ModelContext) {
        guard !started else { return }
        started = true
        self.profileStore = profileStore
        self.context = context
        attach()
    }

    func stop() {
        started = false
        debounceTask?.cancel()
        debounceTask = nil
        detach()
    }

    deinit {
        debounceTask?.cancel()
        if let source = source { source.cancel() }
        if fd >= 0 { close(fd) }
    }

    private func attach() {
        detach()

        let opened = open(hostsPath, O_EVTONLY)
        guard opened >= 0 else {
            print("HostFlow: watcher could not open /etc/hosts — errno \(errno)")
            return
        }
        fd = opened

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: opened,
            eventMask: [.write, .delete, .rename, .extend, .attrib],
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let events = src.data
            Task { @MainActor in
                self.handleEvents(events)
            }
        }

        src.setCancelHandler { [opened] in
            close(opened)
        }

        source = src
        src.resume()
    }

    private func detach() {
        if let source = source {
            source.cancel()
            self.source = nil
        }
        fd = -1
    }

    private func handleEvents(_ events: DispatchSource.FileSystemEvent) {
        if events.contains(.delete) || events.contains(.rename) {
            Task { @MainActor in
                await self.reopenWithBackoff()
                self.scheduleDebouncedSync()
            }
            return
        }
        scheduleDebouncedSync()
    }

    private func reopenWithBackoff() async {
        detach()
        for delay in Self.reopenBackoffsMs {
            try? await Task.sleep(nanoseconds: delay * 1_000_000)
            if FileManager.default.isReadableFile(atPath: hostsPath) {
                attach()
                if source != nil { return }
            }
        }
        attach()
    }

    private func scheduleDebouncedSync() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.debounceNanos)
            guard !Task.isCancelled else { return }
            self?.debounceTask = nil
            self?.runSync()
        }
    }

    private func runSync() {
        guard let store = profileStore, let context = context else { return }
        if store.isWritingHosts { return }
        if let lastWrite = store.lastWriteAt, let mtime = fileModificationDate() {
            if abs(mtime.timeIntervalSince(lastWrite)) <= Self.mtimeToleranceSeconds {
                return
            }
        }
        store.syncDefaultFromFile(context: context)
    }

    private func fileModificationDate() -> Date? {
        var st = stat()
        guard stat(hostsPath, &st) == 0 else { return nil }
        let sec = TimeInterval(st.st_mtimespec.tv_sec)
        let nsec = TimeInterval(st.st_mtimespec.tv_nsec) / 1_000_000_000
        return Date(timeIntervalSince1970: sec + nsec)
    }
}
