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

    func pruneUnmanagedKeepingSystem(profiles: [Profile]) async throws {
        let current = try readRaw()
        let pruned = pruneUnmanaged(current)
        let block = buildBlock(from: profiles)
        let updated = replaceBlock(in: pruned, with: block)
        try await HostsXPCClient.shared.writeHosts(updated)
    }

    func formatProfile(_ profile: Profile) -> String {
        var lines = ["# \(profile.name)"]
        for record in profile.records {
            if record.isEnabled {
                lines.append("\(record.ip) \(record.hostname)")
            } else {
                lines.append("# \(record.ip) \(record.hostname)")
            }
        }
        return lines.joined(separator: "\n") + "\n"
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

    private func pruneUnmanaged(_ content: String) -> String {
        var inBlock = false
        var resultLines: [String] = []
        for rawLine in content.components(separatedBy: "\n") {
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
            if trimmed == blockStart {
                inBlock = true
                resultLines.append(rawLine)
                continue
            }
            if trimmed == blockEnd {
                inBlock = false
                resultLines.append(rawLine)
                continue
            }
            if inBlock {
                resultLines.append(rawLine)
                continue
            }
            if let sanitized = sanitizeUnmanagedLine(rawLine) {
                resultLines.append(sanitized)
            }
        }
        return resultLines.joined(separator: "\n")
    }

    private func sanitizeUnmanagedLine(_ rawLine: String) -> String? {
        let trimmed = rawLine.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return rawLine }

        let isCommented = trimmed.hasPrefix("#")
        let payload = isCommented
            ? String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            : trimmed

        let body: String
        let trail: String
        if let hashIdx = payload.firstIndex(of: "#") {
            body = String(payload[..<hashIdx]).trimmingCharacters(in: .whitespaces)
            trail = String(payload[hashIdx...])
        } else {
            body = payload
            trail = ""
        }

        guard !body.isEmpty else { return rawLine }

        let tokens = body.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard tokens.count >= 2, HostValidator.isValidIP(tokens[0]) else {
            return rawLine
        }

        let ip = tokens[0]
        let hostnames = Array(tokens.dropFirst())
        let kept = hostnames.filter { SystemHostEntries.isSystem(ip: ip, hostname: $0) }

        if kept.isEmpty {
            return nil
        }
        if kept.count == hostnames.count {
            return rawLine
        }

        let prefix = isCommented ? "# " : ""
        let suffix = trail.isEmpty ? "" : " \(trail)"
        return "\(prefix)\(ip) \(kept.joined(separator: " "))\(suffix)"
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
