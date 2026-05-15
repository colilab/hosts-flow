import Foundation
import SwiftUI

enum ImportJSONError: LocalizedError {
    case readFailed(String)
    case invalidFormat
    case unsupportedVersion(found: Int, max: Int)

    var errorDescription: String? {
        switch self {
        case .readFailed(let reason):
            return String(format: String(localized: "error.import.read_failed"), reason)
        case .invalidFormat:
            return String(localized: "error.import.json.invalid")
        case .unsupportedVersion(let found, let max):
            return String(format: String(localized: "error.import.json.unsupported_version"), found, max)
        }
    }
}

struct ImportJSONResult: Identifiable {
    let id = UUID()
    let payload: ExportPayload

    var profileCount: Int { payload.profiles.count }
    var recordCount: Int { payload.profiles.reduce(0) { $0 + $1.records.count } }
}

enum ImportMode: String, CaseIterable, Identifiable {
    case merge
    case replace

    var id: String { rawValue }

    var labelKey: LocalizedStringKey {
        switch self {
        case .merge:   "import.json.mode.merge"
        case .replace: "import.json.mode.replace"
        }
    }

    var descriptionKey: LocalizedStringKey {
        switch self {
        case .merge:   "import.json.mode.merge.description"
        case .replace: "import.json.mode.replace.description"
        }
    }
}

enum ImportJSONService {

    static func parseFile(at url: URL) throws -> ImportJSONResult {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw ImportJSONError.readFailed(error.localizedDescription)
        }

        let payload: ExportPayload
        do {
            payload = try JSONDecoder().decode(ExportPayload.self, from: data)
        } catch {
            throw ImportJSONError.invalidFormat
        }

        guard payload.version >= 1 else {
            throw ImportJSONError.invalidFormat
        }
        guard payload.version <= ExportPayload.currentVersion else {
            throw ImportJSONError.unsupportedVersion(
                found: payload.version,
                max: ExportPayload.currentVersion
            )
        }

        return ImportJSONResult(payload: payload)
    }
}
