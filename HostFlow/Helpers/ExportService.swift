import Foundation

enum ExportService {

    static func exportAll(profiles: [Profile]) throws -> Data {
        let payload = ExportPayload(
            version: ExportPayload.currentVersion,
            profiles: profiles
                .filter { !$0.isReadOnly }
                .sorted { $0.order < $1.order }
                .map { profile in
                    ProfileExport(
                        name: profile.name,
                        order: profile.order,
                        records: profile.records.map {
                            RecordExport(ip: $0.ip, hostname: $0.hostname, isEnabled: $0.isEnabled)
                        }
                    )
                }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(payload)
    }
}
