import Foundation

enum HelperError: Int, Error {
    case unauthorizedCaller = 1
    case manifestMissing = 2
    case manifestInvalid = 3
    case writeFailed = 4
}

extension HelperError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .unauthorizedCaller: return "Caller is not authorized."
        case .manifestMissing: return "CDHash manifest is missing from the app bundle."
        case .manifestInvalid: return "CDHash manifest signature is invalid."
        case .writeFailed: return "Failed to write /etc/hosts."
        }
    }
}

extension HelperError: CustomNSError {
    static var errorDomain: String { "com.colilab.hostflow.helper" }
    var errorCode: Int { rawValue }
    var errorUserInfo: [String: Any] { [NSLocalizedDescriptionKey: errorDescription ?? ""] }
}
