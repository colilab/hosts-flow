import Foundation
import Darwin

enum ValidationError: LocalizedError {
    case emptyIP
    case invalidIP
    case emptyHostname
    case invalidHostname

    var errorDescription: String? {
        switch self {
        case .emptyIP: String(localized: "error.validation.ip_empty")
        case .invalidIP: String(localized: "error.validation.ip_invalid")
        case .emptyHostname: String(localized: "error.validation.hostname_empty")
        case .invalidHostname: String(localized: "error.validation.hostname_invalid")
        }
    }
}

enum HostValidator {

    static func isValidIPv4(_ s: String) -> Bool {
        var addr = in_addr()
        return s.withCString { inet_pton(AF_INET, $0, &addr) == 1 }
    }

    static func isValidIPv6(_ s: String) -> Bool {
        var addr = in6_addr()
        return s.withCString { inet_pton(AF_INET6, $0, &addr) == 1 }
    }

    static func isValidIP(_ s: String) -> Bool {
        isValidIPv4(s) || isValidIPv6(s)
    }

    static func isValidHostname(_ s: String) -> Bool {
        guard (1...253).contains(s.count) else { return false }
        let pattern = #"^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$"#
        return s.range(of: pattern, options: .regularExpression) != nil
    }

    static func validateRecord(ip: String, hostname: String) -> ValidationError? {
        let trimmedIP = ip.trimmingCharacters(in: .whitespaces)
        let trimmedHost = hostname.trimmingCharacters(in: .whitespaces)
        if trimmedIP.isEmpty { return .emptyIP }
        if !isValidIP(trimmedIP) { return .invalidIP }
        if trimmedHost.isEmpty { return .emptyHostname }
        if !isValidHostname(trimmedHost) { return .invalidHostname }
        return nil
    }
}
