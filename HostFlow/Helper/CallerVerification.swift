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
        let executableURL = try mainExecutableURL(bundleURL: bundleURL)
        let regionHashes = try signedRegionHashes(ofExecutableAt: executableURL)
        try verifyManifest(bundleURL: bundleURL, expectedHashes: regionHashes)
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

    private func mainExecutableURL(bundleURL: URL) throws -> URL {
        let infoURL = bundleURL.appendingPathComponent("Contents/Info.plist")
        guard let infoData = try? Data(contentsOf: infoURL),
              let info = try? PropertyListSerialization.propertyList(from: infoData, options: [], format: nil) as? [String: Any],
              let execName = info["CFBundleExecutable"] as? String
        else { throw HelperError.unauthorizedCaller }

        return bundleURL
            .appendingPathComponent("Contents/MacOS", isDirectory: true)
            .appendingPathComponent(execName)
    }

    /// SHA-256 of the *signed content region* — bytes `[0, LC_CODE_SIGNATURE.dataoff)`
    /// — of every Mach-O slice in the executable. That region is byte-identical
    /// before and after (re-)code-signing, so the manifest pinning it can itself
    /// be sealed inside the bundle's code signature (required for Sparkle).
    ///
    /// Kept in lock-step with Scripts/macho-region-hash.py — change both together.
    private func signedRegionHashes(ofExecutableAt url: URL) throws -> [String] {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            throw HelperError.unauthorizedCaller
        }
        var hashes: [String] = []
        for slice in try machOSlices(in: data) {
            let dataoff = try codeSignatureOffset(in: data, slice: slice)
            guard dataoff > 0, dataoff <= slice.size,
                  slice.offset + dataoff <= data.count else {
                throw HelperError.unauthorizedCaller
            }
            let lower = data.startIndex + slice.offset
            let upper = lower + dataoff
            let digest = SHA256.hash(data: data.subdata(in: lower ..< upper))
            hashes.append(digest.map { String(format: "%02x", $0) }.joined())
        }
        guard !hashes.isEmpty else { throw HelperError.unauthorizedCaller }
        return hashes
    }

    private func verifyManifest(bundleURL: URL, expectedHashes: [String]) throws {
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
        let trusted = Set(manifest.binaryHashes.map { $0.lowercased() })
        // Every Mach-O slice of the caller must be accounted for by the manifest.
        for hash in expectedHashes where !trusted.contains(hash.lowercased()) {
            throw HelperError.unauthorizedCaller
        }
    }

    // MARK: - Mach-O parsing

    private struct Slice {
        let offset: Int
        let size: Int
    }

    /// Enumerate every Mach-O slice: one entry for a thin file, several for a
    /// universal (fat) file.
    private func machOSlices(in data: Data) throws -> [Slice] {
        let fatMagic: UInt32 = 0xCAFEBABE
        let fatMagic64: UInt32 = 0xCAFEBABF

        let magic = try readUInt32(data, 0, bigEndian: true)  // fat header is big-endian
        guard magic == fatMagic || magic == fatMagic64 else {
            return [Slice(offset: 0, size: data.count)]       // thin Mach-O
        }

        let wide = (magic == fatMagic64)
        let count = Int(try readUInt32(data, 4, bigEndian: true))
        guard count > 0, count <= 64 else { throw HelperError.unauthorizedCaller }

        var slices: [Slice] = []
        var cursor = 8
        for _ in 0..<count {
            let offset: Int
            let size: Int
            if wide {
                offset = Int(try readUInt64(data, cursor + 8, bigEndian: true))
                size = Int(try readUInt64(data, cursor + 16, bigEndian: true))
                cursor += 32
            } else {
                offset = Int(try readUInt32(data, cursor + 8, bigEndian: true))
                size = Int(try readUInt32(data, cursor + 12, bigEndian: true))
                cursor += 20
            }
            guard offset > 0, size > 0, offset + size <= data.count else {
                throw HelperError.unauthorizedCaller
            }
            slices.append(Slice(offset: offset, size: size))
        }
        return slices
    }

    /// File offset (relative to the slice start) where the slice's code
    /// signature begins — i.e. the size of the signed content region.
    private func codeSignatureOffset(in data: Data, slice: Slice) throws -> Int {
        let machMagic: UInt32 = 0xFEEDFACE
        let machMagic64: UInt32 = 0xFEEDFACF
        let machCigam: UInt32 = 0xCEFAEDFE
        let machCigam64: UInt32 = 0xCFFAEDFE

        let magic = try readUInt32(data, slice.offset, bigEndian: false)
        let bigEndian: Bool
        let wide: Bool
        switch magic {
        case machMagic64: (bigEndian, wide) = (false, true)
        case machMagic:   (bigEndian, wide) = (false, false)
        case machCigam64: (bigEndian, wide) = (true, true)
        case machCigam:   (bigEndian, wide) = (true, false)
        default: throw HelperError.unauthorizedCaller
        }

        let headerSize = wide ? 32 : 28
        let ncmds = Int(try readUInt32(data, slice.offset + 16, bigEndian: bigEndian))
        guard ncmds > 0, ncmds <= 4096 else { throw HelperError.unauthorizedCaller }

        let lcCodeSignature: UInt32 = 0x1d
        var cmd = slice.offset + headerSize
        let sliceEnd = slice.offset + slice.size
        for _ in 0..<ncmds {
            guard cmd + 8 <= sliceEnd else { throw HelperError.unauthorizedCaller }
            let kind = try readUInt32(data, cmd, bigEndian: bigEndian)
            let size = Int(try readUInt32(data, cmd + 4, bigEndian: bigEndian))
            guard size >= 8, cmd + size <= sliceEnd else { throw HelperError.unauthorizedCaller }
            if kind == lcCodeSignature {
                // linkedit_data_command: cmd, cmdsize, dataoff, datasize
                return Int(try readUInt32(data, cmd + 8, bigEndian: bigEndian))
            }
            cmd += size
        }
        throw HelperError.unauthorizedCaller  // the executable slice is unsigned
    }

    private func readUInt32(_ data: Data, _ offset: Int, bigEndian: Bool) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= data.count else { throw HelperError.unauthorizedCaller }
        let i = data.startIndex + offset
        let value = UInt32(data[i])
            | (UInt32(data[i + 1]) << 8)
            | (UInt32(data[i + 2]) << 16)
            | (UInt32(data[i + 3]) << 24)
        return bigEndian ? value.byteSwapped : value
    }

    private func readUInt64(_ data: Data, _ offset: Int, bigEndian: Bool) throws -> UInt64 {
        guard offset >= 0, offset + 8 <= data.count else { throw HelperError.unauthorizedCaller }
        let i = data.startIndex + offset
        var value: UInt64 = 0
        for byte in 0..<8 {
            value |= UInt64(data[i + byte]) << (8 * byte)
        }
        return bigEndian ? value.byteSwapped : value
    }

    private struct Manifest: Decodable {
        let version: Int
        let binaryHashes: [String]
    }
}
