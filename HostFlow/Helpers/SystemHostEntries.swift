import Foundation

enum SystemHostEntries {

    private struct Entry: Hashable {
        let ip: String
        let hostname: String
    }

    private static let entries: Set<Entry> = [
        Entry(ip: "127.0.0.1", hostname: "localhost"),
        Entry(ip: "255.255.255.255", hostname: "broadcasthost"),
        Entry(ip: "::1", hostname: "localhost")
    ]

    static func isSystem(ip: String, hostname: String) -> Bool {
        entries.contains(Entry(ip: ip, hostname: hostname))
    }

    static func isSystem(_ record: ParsedHostRecord) -> Bool {
        isSystem(ip: record.ip, hostname: record.hostname)
    }

    static var canonicalEntries: [ParsedHostRecord] {
        [
            ParsedHostRecord(ip: "127.0.0.1", hostname: "localhost", isEnabled: true),
            ParsedHostRecord(ip: "255.255.255.255", hostname: "broadcasthost", isEnabled: true),
            ParsedHostRecord(ip: "::1", hostname: "localhost", isEnabled: true)
        ]
    }
}
