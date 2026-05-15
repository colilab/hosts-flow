import Foundation

enum ImportError: LocalizedError {
    case readFailed(String)
    case noValidRecords

    var errorDescription: String? {
        switch self {
        case .readFailed(let reason):
            return String(format: String(localized: "error.import.read_failed"), reason)
        case .noValidRecords:
            return String(localized: "error.import.no_valid_records")
        }
    }
}

struct ImportResult: Identifiable {
    let id = UUID()
    let suggestedName: String
    let records: [ParsedHostRecord]
}

enum ImportService {

    static func parseFile(at url: URL) throws -> ImportResult {
        let content: String
        do {
            content = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ImportError.readFailed(error.localizedDescription)
        }

        let records = HostsFileParser.parse(content)
        guard !records.isEmpty else {
            throw ImportError.noValidRecords
        }

        let name = url.deletingPathExtension().lastPathComponent
        return ImportResult(suggestedName: name, records: records)
    }
}
