import Foundation

extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    var appBuild: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
