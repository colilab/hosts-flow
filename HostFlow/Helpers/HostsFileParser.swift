import Foundation

struct ParsedHostRecord {
    let ip: String
    let hostname: String
    let isEnabled: Bool
}

struct ClassifiedHosts {
    let system: [ParsedHostRecord]
    let custom: [ParsedHostRecord]
}

enum HostsFileParser {

    static func parseSystemHosts() throws -> [ParsedHostRecord] {
        let content = try HostsFileManager.shared.read()
        return parseUnmanaged(content)
    }

    static func parseSystemHostsClassified() throws -> ClassifiedHosts {
        let records = try parseSystemHosts()
        var system: [ParsedHostRecord] = []
        var custom: [ParsedHostRecord] = []
        for record in records {
            if SystemHostEntries.isSystem(record) {
                system.append(record)
            } else {
                custom.append(record)
            }
        }
        return ClassifiedHosts(system: system, custom: custom)
    }

    static func parseUnmanaged(_ content: HostsFileContent) -> [ParsedHostRecord] {
        let unmanaged = [content.preBlock, content.postBlock]
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
        return parse(unmanaged)
    }

    static func parse(_ content: String) -> [ParsedHostRecord] {
        var result: [ParsedHostRecord] = []
        for rawLine in content.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }

            let isCommented = line.hasPrefix("#")
            let payload = isCommented
                ? String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                : line

            let withoutTrail: String
            if let hashIdx = payload.firstIndex(of: "#") {
                withoutTrail = String(payload[..<hashIdx]).trimmingCharacters(in: .whitespaces)
            } else {
                withoutTrail = payload
            }
            guard !withoutTrail.isEmpty else { continue }

            let tokens = withoutTrail.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard tokens.count >= 2 else { continue }

            let ip = tokens[0]
            guard HostValidator.isValidIP(ip) else { continue }

            let hostnames = tokens.dropFirst()
            for hostname in hostnames where HostValidator.isValidHostname(hostname) {
                result.append(ParsedHostRecord(ip: ip, hostname: hostname, isEnabled: !isCommented))
            }
        }
        return result
    }
}
