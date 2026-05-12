import Foundation

struct HostsFileContent {
    let preBlock: String
    let block: String?
    let postBlock: String
}

enum HostsFileError: LocalizedError {
    case notReadable
    case malformedBlock
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .notReadable: "Impossibile leggere /etc/hosts."
        case .malformedBlock: "Blocco /etc/hosts malformato (marker mancante o in ordine errato)."
        case .encodingFailed: "Encoding di /etc/hosts non valido (atteso UTF-8)."
        }
    }
}

final class HostsFileManager {

    static let shared = HostsFileManager()
    private init() {}

    private let hostsPath = "/etc/hosts"
    private let blockStart = "# --- Host Flow Start ---"
    private let blockEnd   = "# --- Host Flow End ---"
    private let warningLine1 = "# DO NOT EDIT MANUALLY — managed by Host Flow.app"
    private let warningLine2 = "# Changes inside this block will be overwritten on the next sync."

    func read() throws -> HostsFileContent {
        let raw = try readRaw()
        return try parse(raw)
    }

    func write(profiles: [Profile]) async throws {
        let current = try readRaw()
        let block = buildBlock(from: profiles)
        let updated = replaceBlock(in: current, with: block)
        try await HostsXPCClient.shared.writeHosts(updated)
    }

    func hasManagedBlock() -> Bool {
        guard let raw = try? readRaw() else { return false }
        let lines = raw.components(separatedBy: "\n")
        return lines.contains(blockStart) && lines.contains(blockEnd)
    }

    func removeManagedBlock() async throws {
        let current = try readRaw()
        let stripped = stripBlock(from: current)
        try await HostsXPCClient.shared.writeHosts(stripped)
    }

    private func stripBlock(from content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        guard let startIdx = lines.firstIndex(of: blockStart),
              let endIdx = lines.firstIndex(of: blockEnd),
              startIdx < endIdx else {
            return content
        }

        var removeFrom = startIdx
        if removeFrom > 0, lines[removeFrom - 1].isEmpty {
            removeFrom -= 1
        }

        lines.removeSubrange(removeFrom...endIdx)
        return lines.joined(separator: "\n")
    }

    private func readRaw() throws -> String {
        guard FileManager.default.isReadableFile(atPath: hostsPath) else {
            throw HostsFileError.notReadable
        }
        do {
            return try String(contentsOfFile: hostsPath, encoding: .utf8)
        } catch {
            throw HostsFileError.encodingFailed
        }
    }

    private func parse(_ content: String) throws -> HostsFileContent {
        let lines = content.components(separatedBy: "\n")
        let startIdx = lines.firstIndex(of: blockStart)
        let endIdx = lines.firstIndex(of: blockEnd)

        switch (startIdx, endIdx) {
        case (nil, nil):
            return HostsFileContent(preBlock: content, block: nil, postBlock: "")

        case let (start?, end?) where start < end:
            let preLines = lines[..<start]
            let blockLines = lines[(start + 1)..<end]
            let postLines = (end + 1) < lines.count ? lines[(end + 1)...] : lines[lines.endIndex..<lines.endIndex]
            return HostsFileContent(
                preBlock: preLines.joined(separator: "\n"),
                block: blockLines.joined(separator: "\n"),
                postBlock: postLines.joined(separator: "\n")
            )

        default:
            throw HostsFileError.malformedBlock
        }
    }

    private func buildBlock(from profiles: [Profile]) -> String {
        var lines = [blockStart, warningLine1, warningLine2]
        let activeProfiles = profiles
            .filter { $0.isActive && !$0.isReadOnly }
            .sorted { $0.order < $1.order }
        for profile in activeProfiles {
            lines.append("")
            lines.append("# --- \(profile.name) ---")
            for record in profile.records {
                if record.isEnabled {
                    lines.append("\(record.ip) \(record.hostname)")
                } else {
                    lines.append("# \(record.ip) \(record.hostname)")
                }
            }
        }
        lines.append(blockEnd)
        return lines.joined(separator: "\n")
    }

    private func replaceBlock(in content: String, with block: String) -> String {
        var lines = content.components(separatedBy: "\n")

        if let startIdx = lines.firstIndex(of: blockStart),
           let endIdx = lines.firstIndex(of: blockEnd) {
            lines.replaceSubrange(startIdx...endIdx, with: block.components(separatedBy: "\n"))
        } else {
            lines.append("")
            lines.append(contentsOf: block.components(separatedBy: "\n"))
        }

        return lines.joined(separator: "\n")
    }
}
