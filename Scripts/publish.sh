#!/bin/bash
set -euo pipefail

# Creates the DRAFT GitHub Release for the current version, attaching the DMG
# and appcast-entry.json produced by Scripts/build-release.sh.
#
# The tag is NOT created here: a draft release only references a tag name.
# Push the real annotated tag afterwards with Scripts/release.sh — the tag push
# triggers .github/workflows/release.yml, which publishes the draft and updates
# the appcast on gh-pages.
#
# Version is read from project.yml so the release name cannot drift from the
# bundle that was actually built.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$ROOT/HostFlow/project.yml"
DIST="$ROOT/dist"

VERSION=$(awk -F'[[:space:]]*MARKETING_VERSION:[[:space:]]*' \
  '/^[[:space:]]*MARKETING_VERSION:/ { v=$2; gsub(/"/, "", v); print v; exit }' \
  "$PROJECT_YML")
[ -n "$VERSION" ] || { echo "ERROR: cannot read MARKETING_VERSION from $PROJECT_YML" >&2; exit 1; }

DMG="$DIST/HostFlow-${VERSION}.dmg"
ENTRY="$DIST/appcast-entry.json"

for f in "$DMG" "$ENTRY"; do
  [ -f "$f" ] || { echo "ERROR: missing $f — run Scripts/build-release.sh first" >&2; exit 1; }
done

# Release notes: dist/release-notes.md if the dev prepared one, else a stub.
NOTES_ARGS=(--notes "Host Flow ${VERSION}")
if [[ -f "$DIST/release-notes.md" ]]; then
  NOTES_ARGS=(--notes-file "$DIST/release-notes.md")
fi

gh release create "$VERSION" \
  --draft \
  --title "Host Flow ${VERSION}" \
  "${NOTES_ARGS[@]}" \
  "$DMG" "$ENTRY"

cat <<EOF

✅ Draft release "$VERSION" created with the DMG + appcast-entry.json attached.

Next: push the tag so the workflow publishes the release and updates the appcast:

  Scripts/release.sh -v patch        # on main: bumps, commits, tags, pushes

EOF
