#!/bin/bash
set -euo pipefail

# End-to-end Release build with signed binary-hash manifest.
# Requires HOSTFLOW_PRIVATE_KEY env var pointing to the Ed25519 private key.

if [[ -z "${HOSTFLOW_PRIVATE_KEY:-}" ]]; then
  echo "ERROR: HOSTFLOW_PRIVATE_KEY env var is required" >&2
  exit 1
fi
if [[ ! -f "$HOSTFLOW_PRIVATE_KEY" ]]; then
  echo "ERROR: private key not found at $HOSTFLOW_PRIVATE_KEY" >&2
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

# If Xcode didn't sign (Automatic signing without team can skip in Release),
# apply an ad-hoc signature ourselves so the binary has a stable CodeDirectory.
if ! codesign -dvvv "$APP_PATH" 2>&1 | grep -q "^CDHash="; then
  echo "App not signed by Xcode — applying ad-hoc signature..."
  codesign --force --deep --sign - "$APP_PATH"
fi

"$ROOT/Scripts/sign-manifest.sh" "$APP_PATH" "$HOSTFLOW_PRIVATE_KEY"

echo
echo "🎉 Release build complete:"
echo "   $APP_PATH"
echo
echo "Next: cp -R \"$APP_PATH\" /Applications/"
