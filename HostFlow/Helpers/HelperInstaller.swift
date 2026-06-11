import Foundation
import ServiceManagement

enum HelperInstallerError: LocalizedError {
    case bundleResourceMissing(String)
    case authorizationFailed(OSStatus)
    case scriptFailed(Int32, String)

    var errorDescription: String? {
        switch self {
        case .bundleResourceMissing(let path):
            return String(format: String(localized: "error.installer.bundle_missing"), path)
        case .authorizationFailed(let status):
            return String(format: String(localized: "error.installer.authorization_failed"), Int(status))
        case .scriptFailed(let code, let stderr):
            let trimmed = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            let suffix = trimmed.isEmpty ? "" : ": \(trimmed)"
            return String(format: String(localized: "error.installer.script_failed"), Int(code), suffix)
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

    /// Fast, side-effect-free check used on the hosts-write hot path
    /// (`ProfileStore`): only verifies the two privileged files exist. Does not
    /// spawn a subprocess, so it must not be relied on to detect a "ghost"
    /// launchd registration — use `refreshStatusVerified()` for that.
    func refreshStatus() {
        let installed = FileManager.default.fileExists(atPath: installedPlistPath)
            && FileManager.default.fileExists(atPath: installedHelperPath)
        status = installed ? .installed : .notInstalled
    }

    /// Authoritative status: the files must exist *and* the daemon must be
    /// registered with launchd. Spawns `launchctl print`, so it is only used in
    /// non-hot paths (install/uninstall result, Settings appearance).
    func refreshStatusVerified() {
        let filesExist = FileManager.default.fileExists(atPath: installedPlistPath)
            && FileManager.default.fileExists(atPath: installedHelperPath)
        status = (filesExist && isRegistered()) ? .installed : .notInstalled
    }

    /// Whether launchd currently has the helper's service registered in the
    /// system domain. `launchctl print system/<label>` exits 0 when the service
    /// is bootstrapped, non-zero otherwise. Does not require privileges.
    private func isRegistered() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = ["print", "system/\(helperLabel)"]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
        } catch {
            return false
        }
        process.waitUntilExit()
        return process.terminationStatus == 0
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

        // Idempotent against a "ghost" registration left by a previous version
        // (brew uninstall removes the .app but never boots out the daemon nor
        // deletes /Library/LaunchDaemons + /Library/PrivilegedHelperTools).
        //
        //  1. bootout by LABEL — booting out by plist path is a no-op when the
        //     on-disk plist no longer matches what launchd has registered,
        //     which leaves the stale service loaded and makes the later
        //     bootstrap fail with "5: Input/output error".
        //  2. wait (bounded) until launchctl no longer reports the service, so
        //     the old helper process has exited before we overwrite its binary
        //     (overwriting a running, mapped executable yields ETXTBSY/EIO).
        //  3. copy + chown + chmod, forced so it also fixes files left with
        //     wrong ownership/permissions by an earlier failed attempt.
        //  4. bootstrap, then verify the service is actually registered — a
        //     silent bootstrap failure must surface as a script error.
        let label = helperLabel
        let script = """
        set -e
        launchctl bootout system/\(label) 2>/dev/null || true
        for _ in $(seq 1 15); do
            launchctl print system/\(label) >/dev/null 2>&1 || break
            sleep 0.2
        done
        cp "\(bundledHelper.path)" "\(installedHelperPath)"
        chown root:wheel "\(installedHelperPath)"
        chmod 755 "\(installedHelperPath)"
        cp "\(bundledPlist.path)" "\(installedPlistPath)"
        chown root:wheel "\(installedPlistPath)"
        chmod 644 "\(installedPlistPath)"
        launchctl bootstrap system "\(installedPlistPath)"
        launchctl print system/\(label) >/dev/null 2>&1 || { echo "service not registered after bootstrap" >&2; exit 1; }
        """

        do {
            try runPrivileged(script: script, prompt: String(localized: "helper.install.prompt"))
            refreshStatusVerified()
        } catch {
            status = .error(error)
            throw error
        }
    }

    func uninstall() throws {
        let script = """
        launchctl bootout system/\(helperLabel) 2>/dev/null || true
        rm -f "\(installedHelperPath)"
        rm -f "\(installedPlistPath)"
        """
        do {
            try runPrivileged(script: script, prompt: String(localized: "helper.uninstall.prompt"))
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
