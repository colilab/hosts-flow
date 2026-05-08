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
        let cdHash = try extractCDHash(from: secCode)
        let bundleURL = try copyBundleURL(from: secCode)
        try verifyManifest(bundleURL: bundleURL, expectedCDHash: cdHash)
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

    private func extractCDHash(from code: SecCode) throws -> Data {
        let staticCode = try copyStaticCode(from: code)
        var infoCF: CFDictionary?
        let status = SecCodeCopySigningInformation(staticCode, [], &infoCF)
        guard status == errSecSuccess,
              let info = infoCF as? [String: Any],
              let hash = info[kSecCodeInfoUnique as String] as? Data
        else { throw HelperError.unauthorizedCaller }
        return hash
    }

    private func copyBundleURL(from code: SecCode) throws -> URL {
        let staticCode = try copyStaticCode(from: code)
        var urlCF: CFURL?
        let status = SecCodeCopyPath(staticCode, [], &urlCF)
        guard status == errSecSuccess, let url = urlCF as URL? else {
            throw HelperError.unauthorizedCaller
        }
        return url
    }

    private func copyStaticCode(from code: SecCode) throws -> SecStaticCode {
        var staticCode: SecStaticCode?
        let status = SecCodeCopyStaticCode(code, [], &staticCode)
        guard status == errSecSuccess, let staticCode else {
            throw HelperError.unauthorizedCaller
        }
        return staticCode
    }

    private func verifyManifest(bundleURL: URL, expectedCDHash: Data) throws {
        let resources = bundleURL.appendingPathComponent("Contents/Resources", isDirectory: true)
        let manifestURL = resources.appendingPathComponent("cdhash-manifest.json")
        let sigURL = resources.appendingPathComponent("cdhash-manifest.json.sig")

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
        let expectedHex = expectedCDHash.map { String(format: "%02x", $0) }.joined()
        guard manifest.cdhashes.contains(where: { $0.lowercased() == expectedHex }) else {
            throw HelperError.unauthorizedCaller
        }
    }

    private struct Manifest: Decodable {
        let version: Int
        let cdhashes: [String]
    }
}
