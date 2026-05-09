import Foundation
import os.log

final class HelperService: NSObject, HostFlowHelperProtocol {
    private static let log = OSLog(subsystem: "com.colilab.hostflow.helper", category: "service")
    private static let logFileURL = URL(fileURLWithPath: "/Library/Logs/HostFlow/helper.log")
    private let hostsURL = URL(fileURLWithPath: "/etc/hosts")
    private let backupURL = URL(fileURLWithPath: "/etc/hosts.hostflow.bak")

    func writeHosts(content: String, reply: @escaping (Error?) -> Void) {
        do {
            try performWrite(content: content)
            reply(nil)
        } catch {
            os_log(.error, log: HelperService.log, "writeHosts failed: %{public}@", String(describing: error))
            HelperService.appendErrorLog("writeHosts failed: \(error.localizedDescription)")
            reply(error)
        }
    }

    private func performWrite(content: String) throws {
        guard let data = content.data(using: .utf8) else {
            throw HelperError.writeFailed
        }

        if FileManager.default.fileExists(atPath: hostsURL.path) {
            _ = try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: hostsURL, to: backupURL)
        }

        let tmpURL = hostsURL.appendingPathExtension("hostflow.tmp")
        _ = try? FileManager.default.removeItem(at: tmpURL)

        do {
            try data.write(to: tmpURL, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o644, .ownerAccountID: 0, .groupOwnerAccountID: 0],
                ofItemAtPath: tmpURL.path
            )
            _ = try FileManager.default.replaceItemAt(hostsURL, withItemAt: tmpURL)
        } catch {
            _ = try? FileManager.default.removeItem(at: tmpURL)
            throw error
        }

        os_log(.info, log: HelperService.log, "wrote /etc/hosts (%d bytes)", data.count)
    }

    private static func appendErrorLog(_ message: String) {
        let dir = logFileURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] ERROR \(message)\n"
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: logFileURL.path) {
            if let handle = try? FileHandle(forWritingTo: logFileURL) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: logFileURL)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o644],
                ofItemAtPath: logFileURL.path
            )
        }
    }
}
