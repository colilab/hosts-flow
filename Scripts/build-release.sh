#!/bin/bash
set -euo pipefail

# End-to-end Release build with:
#   * signed binary-hash manifest (helper authorization),
#   * a distributable DMG,
#   * a Sparkle EdDSA signature + appcast-entry.json for the update feed.
#
# Required env vars:
#   HOSTFLOW_PRIVATE_KEY          Ed25519 key for the helper CDHash manifest.
#   HOSTFLOW_SPARKLE_PRIVATE_KEY  EdDSA key for Sparkle update signing.
# The two keys are deliberately distinct (see docs/release.md §9).

if [[ -z "${HOSTFLOW_PRIVATE_KEY:-}" ]]; then
  echo "ERROR: HOSTFLOW_PRIVATE_KEY env var is required" >&2
  exit 1
fi
if [[ ! -f "$HOSTFLOW_PRIVATE_KEY" ]]; then
  echo "ERROR: private key not found at $HOSTFLOW_PRIVATE_KEY" >&2
  exit 1
fi
if [[ -z "${HOSTFLOW_SPARKLE_PRIVATE_KEY:-}" ]]; then
  echo "ERROR: HOSTFLOW_SPARKLE_PRIVATE_KEY env var is required" >&2
  exit 1
fi
if [[ ! -f "$HOSTFLOW_SPARKLE_PRIVATE_KEY" ]]; then
  echo "ERROR: Sparkle private key not found at $HOSTFLOW_SPARKLE_PRIVATE_KEY" >&2
  exit 1
fi
if ! command -v create-dmg >/dev/null 2>&1; then
  echo "ERROR: create-dmg not found. Run: brew install create-dmg" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

cd "$ROOT/HostFlow"
xcodegen generate

xcodebuild \
  -project HostFlow.xcodeproj \
  -scheme HostFlow \
  -configuration Release \
  clean build \
  CODE_SIGN_IDENTITY=-

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData \
  -path "*Release*HostFlow.app" -type d -maxdepth 7 2>/dev/null | head -1)

if [[ -z "$APP_PATH" ]]; then
  echo "ERROR: could not locate built HostFlow.app" >&2
  exit 1
fi

# sign-manifest.sh owns code-signing end to end: it ad-hoc signs the app, writes
# the binary-hash manifest over the executable's signed region, then re-seals the
# bundle so the manifest is inside the code signature — so `codesign --verify`
# passes and Sparkle accepts the bundle as a valid update.
"$ROOT/Scripts/sign-manifest.sh" "$APP_PATH" "$HOSTFLOW_PRIVATE_KEY"

# --- Sparkle distribution: DMG + EdDSA signature -----------------------------
# IMPORTANT: everything below runs AFTER sign-manifest.sh and must NOT re-sign
# the .app. create-dmg only copies the bundle into a disk image (no --codesign
# flag passed) so the Mach-O signature and binary-hash manifest stay valid.

INFO_PLIST="$APP_PATH/Contents/Info.plist"
SHORT_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST")
BUNDLE_VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST")
MIN_OS=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$INFO_PLIST")

DIST="$ROOT/dist"
mkdir -p "$DIST"

DMG_NAME="HostFlow-${SHORT_VERSION}.dmg"
DMG_PATH="$DIST/$DMG_NAME"
rm -f "$DMG_PATH"

DMG_STAGE=$(mktemp -d)
trap 'rm -rf "$DMG_STAGE"' EXIT
cp -R "$APP_PATH" "$DMG_STAGE/"

create-dmg \
  --volname "Host Flow" \
  --window-size 540 380 \
  --icon-size 100 \
  --icon "HostFlow.app" 140 190 \
  --app-drop-link 400 190 \
  --format UDZO \
  "$DMG_PATH" \
  "$DMG_STAGE"

# Locate Sparkle's sign_update tool (vendored copy wins, else SwiftPM artifact).
SIGN_UPDATE=""
if [[ -x "$ROOT/Scripts/sparkle-bin/sign_update" ]]; then
  SIGN_UPDATE="$ROOT/Scripts/sparkle-bin/sign_update"
else
  SIGN_UPDATE=$(find ~/Library/Developer/Xcode/DerivedData -type f \
    -path "*/Sparkle/bin/sign_update" 2>/dev/null | head -1)
fi
if [[ -z "$SIGN_UPDATE" ]]; then
  echo "ERROR: Sparkle sign_update tool not found under DerivedData." >&2
  echo "       Run Scripts/make-sparkle-keys.sh notes to resolve the package." >&2
  exit 1
fi

# sign_update prints: sparkle:edSignature="..." length="..."
SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH" -f "$HOSTFLOW_SPARKLE_PRIVATE_KEY")
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -E 's/.*edSignature="([^"]+)".*/\1/')
LENGTH=$(echo "$SIGN_OUTPUT" | sed -E 's/.*length="([^"]+)".*/\1/')

if [[ -z "$ED_SIGNATURE" || -z "$LENGTH" ]]; then
  echo "ERROR: could not parse sign_update output: $SIGN_OUTPUT" >&2
  exit 1
fi

ENTRY_PATH="$DIST/appcast-entry.json"
cat > "$ENTRY_PATH" <<EOF
{
  "version": "${BUNDLE_VERSION}",
  "shortVersion": "${SHORT_VERSION}",
  "dmgFilename": "${DMG_NAME}",
  "length": "${LENGTH}",
  "edSignature": "${ED_SIGNATURE}",
  "minimumSystemVersion": "${MIN_OS}"
}
EOF

echo
echo "🎉 Release build complete:"
echo "   app:           $APP_PATH"
echo "   dmg:           $DMG_PATH"
echo "   appcast entry: $ENTRY_PATH"
echo
echo "Next: ./Scripts/publish.sh   (creates the draft GitHub Release)"
