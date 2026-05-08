#!/bin/bash
set -euo pipefail

# Sign the binary-hash manifest for an .app bundle.
# Usage: sign-manifest.sh <app-path> <private-key.pem>
#
# Computes SHA-256 of the bundle's main executable
# (<App>/Contents/MacOS/<CFBundleExecutable>) and writes:
#   <App>/Contents/Resources/binary-hash-manifest.json
#   <App>/Contents/Resources/binary-hash-manifest.json.sig
#
# IMPORTANT: do NOT re-codesign the app after this script runs.
# Re-signing changes the bytes of the executable and invalidates the hash.

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

INFO_PLIST="$APP_PATH/Contents/Info.plist"
EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$INFO_PLIST")
BIN_PATH="$APP_PATH/Contents/MacOS/$EXEC_NAME"

if [[ ! -f "$BIN_PATH" ]]; then
  echo "ERROR: executable not found at $BIN_PATH" >&2
  exit 1
fi

HASH=$(shasum -a 256 "$BIN_PATH" | cut -d' ' -f1)

RESOURCES="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES"

MANIFEST="$RESOURCES/binary-hash-manifest.json"
SIG="$RESOURCES/binary-hash-manifest.json.sig"

cat > "$MANIFEST" <<EOF
{"version":1,"binaryHashes":["$HASH"]}
EOF

openssl pkeyutl -sign -inkey "$PRIV_KEY" -rawin -in "$MANIFEST" -out "$SIG"

echo "✅ Signed binary-hash manifest:"
echo "   binary: $BIN_PATH"
echo "   sha256: $HASH"
echo "   manifest: $MANIFEST"
echo "   signature: $SIG"
