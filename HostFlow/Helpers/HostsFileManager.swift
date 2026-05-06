import Foundation

final class HostsFileManager {

    static let shared = HostsFileManager()
    private init() {}

    private let hostsPath = "/etc/hosts"
    private let blockStart = "# --- Host Flow Start ---"
    private let blockEnd   = "# --- Host Flow End ---"

    func read() throws -> String {
        try String(contentsOfFile: hostsPath, encoding: .utf8)
    }

    func write(profiles: [Profile]) throws {
        let current = try read()
        let block = buildBlock(from: profiles)
        let updated = replaceBlock(in: current, with: block)
        try updated.write(toFile: hostsPath, atomically: true, encoding: .utf8)
    }

    private func buildBlock(from profiles: [Profile]) -> String {
        var lines = [blockStart]
        for profile in profiles where profile.isActive {
            for record in profile.records {
                if record.isEnabled {
                    lines.append("\(record.ip)\t\(record.hostname)")
                } else {
                    lines.append("# \(record.ip)\t\(record.hostname)")
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
