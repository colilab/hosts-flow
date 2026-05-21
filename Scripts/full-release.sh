#!/bin/bash
set -euo pipefail

# Orchestrates a stable release end-to-end:
#   preflight → bump → build → publish draft → commit + tag + push.
#
# Usage:
#   Scripts/full-release.sh -v patch|minor|major
#
# Requires (strict — fails fast):
#   * branch == main, working tree clean, up-to-date with origin/main
#   * HOSTFLOW_PRIVATE_KEY + HOSTFLOW_SPARKLE_PRIVATE_KEY exported and readable
#   * gh, xcodegen, create-dmg installed
#
# Release notes: drop dist/release-notes.md before running if you want
# anything other than the stub used by publish.sh.

versionType=""
while getopts ":v:" arg; do
  case $arg in
    v) versionType=$OPTARG ;;
    *) echo "Usage: $0 -v patch|minor|major" >&2; exit 1 ;;
  esac
done

case "$versionType" in
  patch|minor|major) ;;
  *) echo "ERROR: -v must be patch|minor|major" >&2; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$ROOT/HostFlow/project.yml"
PBXPROJ="$ROOT/HostFlow/HostFlow.xcodeproj/project.pbxproj"

# --- 1. Preflight ------------------------------------------------------------

branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
[ "$branch" = "main" ] || { echo "ERROR: must be on main, currently on '$branch'" >&2; exit 1; }

if ! git -C "$ROOT" diff-index --quiet HEAD --; then
  echo "ERROR: working tree is dirty — commit or stash first" >&2
  exit 1
fi
if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
  echo "ERROR: untracked changes present — clean them first" >&2
  git -C "$ROOT" status --short >&2
  exit 1
fi

git -C "$ROOT" fetch --quiet origin main
behind=$(git -C "$ROOT" rev-list HEAD..origin/main --count)
ahead=$(git -C "$ROOT" rev-list origin/main..HEAD --count)
[ "$behind" = "0" ] || { echo "ERROR: local main is $behind commit(s) behind origin/main — pull first" >&2; exit 1; }
[ "$ahead"  = "0" ] || { echo "ERROR: local main is $ahead commit(s) ahead of origin/main — push first" >&2; exit 1; }

for var in HOSTFLOW_PRIVATE_KEY HOSTFLOW_SPARKLE_PRIVATE_KEY; do
  val="${!var:-}"
  [ -n "$val" ]   || { echo "ERROR: $var is not set" >&2; exit 1; }
  [ -f "$val" ]   || { echo "ERROR: $var points to missing file: $val" >&2; exit 1; }
done

for tool in gh xcodegen create-dmg; do
  command -v "$tool" >/dev/null 2>&1 || { echo "ERROR: '$tool' not found in PATH" >&2; exit 1; }
done

# --- 2. Bump -----------------------------------------------------------------

current=$(awk -F'[[:space:]]*MARKETING_VERSION:[[:space:]]*' \
  '/^[[:space:]]*MARKETING_VERSION:/ { v=$2; gsub(/"/, "", v); print v; exit }' \
  "$PROJECT_YML")
[ -n "$current" ] || { echo "ERROR: cannot read MARKETING_VERSION from $PROJECT_YML" >&2; exit 1; }

case "$current" in
  *-*) echo "ERROR: current version '$current' is a prerelease — full-release.sh is stable-only" >&2; exit 1 ;;
esac

major=$(echo "$current" | cut -d. -f1)
minor=$(echo "$current" | cut -d. -f2)
patch=$(echo "$current" | cut -d. -f3)
case "$versionType" in
  patch) patch=$((patch + 1)) ;;
  minor) minor=$((minor + 1)); patch=0 ;;
  major) major=$((major + 1)); minor=0; patch=0 ;;
esac
new="${major}.${minor}.${patch}"

if git -C "$ROOT" rev-parse -q --verify "refs/tags/$new" >/dev/null; then
  echo "ERROR: tag '$new' already exists" >&2
  exit 1
fi

# CURRENT_PROJECT_VERSION is what Sparkle compares for the newer-than check —
# it must monotonically increase every public release.
cur_build=$(awk -F'[[:space:]]*CURRENT_PROJECT_VERSION:[[:space:]]*' \
  '/^[[:space:]]*CURRENT_PROJECT_VERSION:/ { v=$2; gsub(/"/, "", v); print v; exit }' \
  "$PROJECT_YML")
[ -n "$cur_build" ] || { echo "ERROR: cannot read CURRENT_PROJECT_VERSION from $PROJECT_YML" >&2; exit 1; }
new_build=$((cur_build + 1))

echo "→ bumping MARKETING_VERSION    $current → $new"
echo "→ bumping CURRENT_PROJECT_VERSION $cur_build → $new_build"

sed -i '' -E "s/(MARKETING_VERSION:[[:space:]]*\")[^\"]+(\")/\\1${new}\\2/" "$PROJECT_YML"
sed -i '' -E "s/(CURRENT_PROJECT_VERSION:[[:space:]]*\")[^\"]+(\")/\\1${new_build}\\2/" "$PROJECT_YML"

( cd "$ROOT/HostFlow" && xcodegen generate >/dev/null )

# --- 3. Build ----------------------------------------------------------------

echo "→ building signed DMG for $new"
"$ROOT/Scripts/build-release.sh"

# --- 4. Publish draft --------------------------------------------------------

echo "→ creating draft GitHub release $new"
"$ROOT/Scripts/publish.sh"

# --- 5. Commit + tag + push --------------------------------------------------

echo "→ committing version bump and tagging $new"
git -C "$ROOT" add "$PROJECT_YML" "$PBXPROJ"
git -C "$ROOT" commit -m "chore(release): 💯 release $new"
git -C "$ROOT" tag -a "$new" -m "🏷️ Release $new"
git -C "$ROOT" push --follow-tags

cat <<EOF

🎉 Release $new pushed.
   The tag push has triggered .github/workflows/release.yml, which will:
     1. flip the draft GitHub release to published,
     2. append the new <item> to appcast.xml on gh-pages.

   Watch: gh run watch
EOF
