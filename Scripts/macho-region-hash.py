#!/usr/bin/env python3
"""SHA-256 of the *signed content region* of a Mach-O executable.

For each Mach-O slice (a thin file has one, a universal file has several) the
signed content region is the byte range [sliceStart, sliceStart + dataoff),
where `dataoff` comes from the slice's LC_CODE_SIGNATURE load command. Those
bytes are exactly what `codesign` covers with the Code Directory, and they are
byte-identical before and after (re-)signing — only the signature blob that
follows them changes. Hashing this region instead of the whole file lets Host
Flow's binary-hash manifest be sealed *inside* the code signature.

Prints a compact JSON array of lowercase hex digests, one per slice:
    ["<sha256>", ...]

Kept deliberately in lock-step with the Swift parser in
HostFlow/Helper/CallerVerification.swift — change both together.
"""
import hashlib
import json
import struct
import sys

FAT_MAGIC, FAT_MAGIC_64 = 0xCAFEBABE, 0xCAFEBABF
# Mach-O magics keyed by their little-endian on-disk reading -> (struct endian, 64-bit).
MACH_MAGICS = {
    0xFEEDFACE: ("<", False), 0xFEEDFACF: ("<", True),
    0xCEFAEDFE: (">", False), 0xCFFAEDFE: (">", True),
}
LC_CODE_SIGNATURE = 0x1D


def fail(message):
    sys.stderr.write(f"macho-region-hash: {message}\n")
    sys.exit(1)


def slices(data):
    """Return [(offset, size)] for every Mach-O contained in the file."""
    if len(data) < 8:
        fail("file too small to be a Mach-O")
    magic = struct.unpack_from(">I", data, 0)[0]  # fat header is always big-endian
    if magic not in (FAT_MAGIC, FAT_MAGIC_64):
        return [(0, len(data))]  # thin Mach-O
    wide = magic == FAT_MAGIC_64
    count = struct.unpack_from(">I", data, 4)[0]
    if not 0 < count <= 64:
        fail("implausible fat architecture count")
    out, cursor = [], 8
    for _ in range(count):
        if wide:
            offset, size = struct.unpack_from(">QQ", data, cursor + 8)
            cursor += 32
        else:
            offset, size = struct.unpack_from(">II", data, cursor + 8)
            cursor += 20
        if offset <= 0 or size <= 0 or offset + size > len(data):
            fail("fat slice out of bounds")
        out.append((offset, size))
    return out


def code_signature_offset(data, base, size):
    """File offset (relative to `base`) where the slice's code signature starts."""
    magic = struct.unpack_from("<I", data, base)[0]
    if magic not in MACH_MAGICS:
        fail("not a Mach-O slice")
    endian, wide = MACH_MAGICS[magic]
    header = 32 if wide else 28
    ncmds = struct.unpack_from(endian + "I", data, base + 16)[0]
    if not 0 < ncmds <= 4096:
        fail("implausible load command count")
    cursor, end = base + header, base + size
    for _ in range(ncmds):
        if cursor + 8 > end:
            fail("load command out of bounds")
        cmd, cmdsize = struct.unpack_from(endian + "II", data, cursor)
        if cmdsize < 8 or cursor + cmdsize > end:
            fail("malformed load command")
        if cmd == LC_CODE_SIGNATURE:
            return struct.unpack_from(endian + "I", data, cursor + 8)[0]
        cursor += cmdsize
    fail("slice has no LC_CODE_SIGNATURE — code-sign the app first")


def main():
    if len(sys.argv) != 2:
        fail("usage: macho-region-hash.py <mach-o-executable>")
    with open(sys.argv[1], "rb") as handle:
        data = handle.read()
    digests = []
    for base, size in slices(data):
        dataoff = code_signature_offset(data, base, size)
        if dataoff <= 0 or dataoff > size or base + dataoff > len(data):
            fail("code signature offset out of bounds")
        digests.append(hashlib.sha256(data[base:base + dataoff]).hexdigest())
    print(json.dumps(digests, separators=(",", ":")))


if __name__ == "__main__":
    main()
