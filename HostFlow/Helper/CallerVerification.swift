import Foundation
import Security
import CryptoKit

struct CallerVerification {
    let connection: NSXPCConnection

    func verify() throws {
        #if DEBUG
        return
        #else
        let secCode = try copySecCode()
        let bundleURL = try copyBundleURL(from: secCode)
        let binaryHash = try sha256OfMainExecutable(bundleURL: bundleURL)
        try verifyManifest(bundleURL: bundleURL, expectedHash: binaryHash)
        #endif
    }

    private func copySecCode() throws -> SecCode {
        let pid = connection.processIdentifier
        let attrs: [CFString: Any] = [kSecGuestAttributePid: NSNumber(value: pid)]
        var code: SecCode?
        let status = SecCodeCopyGuestWithAttributes(nil, attrs as CFDictionary, [], &code)
        guard status == errSecSuccess, let code else { throw HelperError.unauthorizedCaller }
        return code
    }

    private func copyBundleURL(from code: SecCode) throws -> URL {
        var staticCode: SecStaticCode?
        let status = SecCodeCopyStaticCode(code, [], &staticCode)
        guard status == errSecSuccess, let staticCode else {
            throw HelperError.unauthorizedCaller
        }
        var urlCF: CFURL?
        let pathStatus = SecCodeCopyPath(staticCode, [], &urlCF)
        guard pathStatus == errSecSuccess, let url = urlCF as URL? else {
            throw HelperError.unauthorizedCaller
        }
        return url
    }

    private func sha256OfMainExecutable(bundleURL: URL) throws -> String {
        let infoURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let infoData = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any],
              let execName = info["CFBundleExecutable"] as? String
        else { throw HelperError.unauthorizedCaller }

        let binaryURL = bundleURL
            .appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(execName)

        guard let binaryData = try? Data(contentsOf: binaryURL) else {
            throw HelperError.unauthorizedCaller
        }
        let digest = SHA256.hash(data: binaryData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func verifyManifest(bundleURL: URL, expectedHash: String) throws {
        let resources = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let manifestURL = resources.appendingPathComponent("binary-hash-manifest.json")
        let sigURL = resources.appendingPathComponent("binary-hash-manifest.json.sig")

        guard let manifestData = try? Data(contentsOf: manifestURL),
              let sigData = try? Data(contentsOf: sigURL)
        else { throw HelperError.manifestMissing }

        let publicKey: Curve25519.Signing.PublicKey
        do {
            publicKey = try Curve25519.Signing.PublicKey(rawRepresentation: AuthorizedKeys.publicKeyData)
        } catch {
            throw HelperError.manifestInvalid
        }

        guard publicKey.isValidSignature(sigData, for: manifestData) else {
            throw HelperError.manifestInvalid
        }

        let manifest = try JSONDecoder().decode(Manifest.self, from: manifestData)
        guard manifest.binaryHashes.contains(where: { $0.lowercased() == expectedHash }) else {
            throw HelperError.unauthorizedCaller
        }
    }

    private struct Manifest: Decodable {
        let version: Int
        let binaryHashes: [String]
    }
}
