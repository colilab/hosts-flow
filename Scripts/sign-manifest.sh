#!/bin/bash
set -euo pipefail

# Sign the CDHash manifest for an .app bundle.
# Usage: sign-manifest.sh <app-path> <private-key.pem>
#
# Writes:
#   <app>/Contents/Resources/cdhash-manifest.json
#   <app>/Contents/Resources/cdhash-manifest.json.sig

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

CDHASH=$(codesign -dvvv "$APP_PATH" 2>&1 | awk -F'=' '/^CDHash=/ {print $2}')
if [[ -z "$CDHASH" ]]; then
  echo "ERROR: could not extract CDHash from $APP_PATH (is it codesigned?)" >&2
  exit 1
fi

RESOURCES="$APP_PATH/Contents/Resources"
mkdir -p "$RESOURCES"

MANIFEST="$RESOURCES/cdhash-manifest.json"
SIG="$RESOURCES/cdhash-manifest.json.sig"

cat > "$MANIFEST" <<EOF
{"version":1,"cdhashes":["$CDHASH"]}
EOF

openssl pkeyutl -sign -inkey "$PRIV_KEY" -rawin -in "$MANIFEST" -out "$SIG"

echo "✅ Signed manifest:"
echo "  $MANIFEST"
echo "  $SIG"
echo "  CDHash: $CDHASH"
