#!/bin/bash
set -euo pipefail

# Generate the EdDSA (Ed25519) keypair Sparkle uses to sign update archives.
# Run ONCE. This key is INDEPENDENT of the helper CDHash-manifest key produced
# by Scripts/make-keys.sh — Sparkle update signing and daemon authorization are
# two separate trust chains and must never share a key.
#
# Sparkle ships its `generate_keys` tool inside the SwiftPM artifact bundle.
# Resolve the package at least once before running this script:
#
#   cd HostFlow && xcodegen generate
#   xcodebuild -project HostFlow.xcodeproj -resolvePackageDependencies
#
# Output:
#   * a new keypair stored in the login Keychain (Sparkle's default),
#   * the matching private key exported to the off-tree vault file below,
#   * the public key string printed for embedding as SUPublicEDKey in Info.plist.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

VAULT="$HOME/Documents/keys-vault"
PRIV="$VAULT/hostflow-sparkle-private.key"

find_tool() {
  local name="$1"
  # A vendored copy (committed under Scripts/sparkle-bin/) wins if present.
  if [[ -x "$ROOT/Scripts/sparkle-bin/$name" ]]; then
    echo "$ROOT/Scripts/sparkle-bin/$name"
    return 0
  fi
  find "$HOME/Library/Developer/Xcode/DerivedData" -type f \
    -path "*/Sparkle/bin/$name" 2>/dev/null | head -1
}

GEN=$(find_tool generate_keys)
if [[ -z "${GEN:-}" ]]; then
  echo "ERROR: Sparkle's generate_keys tool not found." >&2
  echo "       Resolve the Sparkle package first:" >&2
  echo "         cd HostFlow && xcodegen generate" >&2
  echo "         xcodebuild -project HostFlow.xcodeproj -resolvePackageDependencies" >&2
  exit 1
fi

if [[ -f "$PRIV" ]]; then
  echo "ERROR: $PRIV already exists. Refusing to overwrite." >&2
  echo "       Delete it deliberately if you intend to rotate the Sparkle key." >&2
  exit 1
fi

mkdir -p "$VAULT"

# Generate (or look up) the keypair in the Keychain and capture the public key.
"$GEN"

# Export the private key to the off-tree vault file used by build-release.sh.
"$GEN" -x "$PRIV"
chmod 600 "$PRIV"

cat <<EOF

✅ Sparkle keypair ready:
  private (Keychain): account "ed25519" in your login Keychain
  private (file):     $PRIV   ← NEVER COMMIT. .gitignore already covers it.

Next steps:
  1. Copy the "SUPublicEDKey" / public key value printed by generate_keys above.
  2. Paste it into HostFlow/Resources/Info.plist as the <string> for SUPublicEDKey.
  3. Point the release build at the exported private key:
       export HOSTFLOW_SPARKLE_PRIVATE_KEY="$PRIV"

EOF
