import Foundation

struct RecordExport: Codable {
    let ip: String
    let hostname: String
    let isEnabled: Bool
}

struct ProfileExport: Codable {
    let name: String
    let order: Int
    let records: [RecordExport]
}

struct ExportPayload: Codable {
    static let currentVersion = 1

    let version: Int
    let profiles: [ProfileExport]
}
