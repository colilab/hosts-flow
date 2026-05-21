#!/bin/bash
set -euo pipefail

# Sign Host Flow's binary-hash manifest — Sparkle-compatible variant.
#
# The manifest pins the *signed content region* of the main executable: the
# bytes [0, LC_CODE_SIGNATURE.dataoff) of each Mach-O slice, NOT the whole file.
# That region is byte-identical before and after (re-)code-signing, so the
# manifest can live INSIDE the code-sealed bundle. The flow is two-pass:
#
#   pass 1 : codesign the app so the executable gains an LC_CODE_SIGNATURE
#   write  : hash each slice's signed region -> binary-hash-manifest.json (+ .sig)
#   pass 2 : codesign again so the manifest is sealed; `codesign --verify` now
#            succeeds and Sparkle accepts the bundle as a valid update.
#
# Because the signed region is unchanged by pass 2, the manifest written between
# the passes stays valid. See docs/release.md §9 and docs/helper.md.
#
# Usage: sign-manifest.sh <app-path> <private-key.pem>

APP_PATH="${1:?app path required}"
PRIV_KEY="${2:?private key path required}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: $APP_PATH is not a directory" >&2
  exit 1
fi
if [[ ! -f "$PRIV_KEY" ]]; then
  echo "ERROR: private key $PRIV_KEY not found" >&2
  exit 1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required (ships with the Xcode Command Line Tools)" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REGION_HASH="$SCRIPT_DIR/macho-region-hash.py"

INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST")
BIN_PATH="$APP_PATH/Contents/MacOS/$EXEC_NAME"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "ERROR: executable not found at $BIN_PATH" >&2
  exit 1
fi

# Pass 1 — establish the code signature so LC_CODE_SIGNATURE exists.
codesign --force --deep --sign - "$APP_PATH"

# Hash the signed region of every Mach-O slice (stable across re-signing).
HASHES=$(python3 "$REGION_HASH" "$BIN_PATH")

RESOURCES="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES"

MANIFEST="$RESOURCES/binary-hash-manifest.json"
SIG="$RESOURCES/binary-hash-manifest.json.sig"

printf '{"version":2,"binaryHashes":%s}' "$HASHES" > "$MANIFEST"
openssl pkeyutl -sign -inkey "$PRIV_KEY" -rawin -in "$MANIFEST" -out "$SIG"

# Pass 2 — re-seal the bundle so the manifest is part of the code signature.
codesign --force --deep --sign - "$APP_PATH"

echo "✅ Signed binary-hash manifest (Sparkle-compatible):"
echo "   executable: $BIN_PATH"
echo "   manifest:   $MANIFEST"
echo "   hashes:     $HASHES"
echo "   bundle re-sealed — 'codesign --verify' now succeeds."
