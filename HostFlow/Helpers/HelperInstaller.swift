import Foundation
import ServiceManagement

enum HelperInstallerError: LocalizedError {
    case bundleResourceMissing(String)
    case authorizationFailed(OSStatus)
    case scriptFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .bundleResourceMissing(let path):
            return "Helper resource not found in app bundle: \(path)"
        case .authorizationFailed(let status):
            return "Authorization failed (OSStatus \(status))"
        case .scriptFailed(let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return "Privileged script failed (exit \(code))" + (trimmed.isEmpty ? "" : ": \(trimmed)")
        }
    }
}

enum HelperStatus {
    case notInstalled
    case installed
    case error(Error)

    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }
}

@Observable
final class HelperInstaller {
    static let shared = HelperInstaller()

    private let helperLabel = "com.colilab.hostflow.helper"
    private let installedHelperPath = "/Library/PrivilegedHelperTools/com.colilab.hostflow.helper"
    private let installedPlistPath = "/Library/LaunchDaemons/com.colilab.hostflow.helper.plist"

    private(set) var status: HelperStatus = .notInstalled

    var isInstalled: Bool { status.isInstalled }

    private init() {
        refreshStatus()
    }

    func refreshStatus() {
        let installed = FileManager.default.fileExists(atPath: installedPlistPath)
            && FileManager.default.fileExists(atPath: installedHelperPath)
        status = installed ? .installed : .notInstalled
    }

    func install() throws {
        let launchDaemons = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Library/LaunchDaemons", isDirectory: true)
        let bundledHelper = launchDaemons.appendingPathComponent(helperLabel)
        let bundledPlist = launchDaemons.appendingPathComponent("\(helperLabel).plist")

        guard FileManager.default.fileExists(atPath: bundledHelper.path) else {
            throw HelperInstallerError.bundleResourceMissing(bundledHelper.path)
        }
        guard FileManager.default.fileExists(atPath: bundledPlist.path) else {
            throw HelperInstallerError.bundleResourceMissing(bundledPlist.path)
        }

        let script = """
        set -e
        cp "\(bundledHelper.path)" "\(installedHelperPath)"
        chown root:wheel "\(installedHelperPath)"
        chmod 755 "\(installedHelperPath)"
        cp "\(bundledPlist.path)" "\(installedPlistPath)"
        chown root:wheel "\(installedPlistPath)"
        chmod 644 "\(installedPlistPath)"
        launchctl bootout system "\(installedPlistPath)" 2>/dev/null || true
        launchctl bootstrap system "\(installedPlistPath)"
        """

        do {
            try runPrivileged(script: script, prompt: "Host Flow needs administrator privileges to install the helper.")
            status = .installed
        } catch {
            status = .error(error)
            throw error
        }
    }

    func uninstall() throws {
        let script = """
        launchctl bootout system "\(installedPlistPath)" 2>/dev/null || true
        rm -f "\(installedHelperPath)"
        rm -f "\(installedPlistPath)"
        """
        do {
            try runPrivileged(script: script, prompt: "Host Flow needs administrator privileges to remove the helper.")
            status = .notInstalled
        } catch {
            status = .error(error)
            throw error
        }
    }

    private func runPrivileged(script: String, prompt: String) throws {
        let escaped = script.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let osa = "do shell script \"\(escaped)\" with administrator privileges"

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", osa]

        let stderr = Pipe()
        process.standardError = stderr
        process.standardOutput = Pipe()

        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8) ?? ""
            throw HelperInstallerError.scriptFailed(process.terminationStatus, message)
        }
    }
}
