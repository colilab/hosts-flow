#!/bin/sh
# Bumps the project version (MARKETING_VERSION in project.yml), commits and
# pushes. Releases on main (rel/fix) are always tagged. Mirrors the
# pnpm-version flow used in JS projects, adapted to a Swift/macOS project
# where the version lives in project.yml.
#
# Usage:
#   Scripts/release.sh -v [none|patch|minor|major] -r [pre|rc|fix|rel]
#
#     -v  version type, default: none
#     -r  release type, default: rel
#
# Branch rules:
#   main    → only rel or fix     (tagged + pushed)
#   develop → only pre            (not tagged)
#   quality → only rc             (not tagged)

set -e

versionType=""
releaseType=""

while getopts ":v:r:" arg; do
  case $arg in
  v) versionType=$OPTARG ;;
  r) releaseType=$OPTARG ;;
  *)
    printf "\n%s -v [none|patch|minor|major] -r [pre|rc|fix|rel]\n\n" "$0"
    exit 0
    ;;
  esac
done

[ -z "$versionType" ] && versionType="none"
[ "$releaseType" = "rel" ] && releaseType=""

case "$versionType" in
  none|patch|minor|major) ;;
  *) echo "Version type not supported: $versionType"; exit 1 ;;
esac

case "$releaseType" in
  ""|pre|rc|fix) ;;
  *) echo "Release type not supported: $releaseType"; exit 1 ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$ROOT/HostFlow/project.yml"
PBXPROJ="$ROOT/HostFlow/HostFlow.xcodeproj/project.pbxproj"

branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD)
case "$branch" in
  main|develop|quality) ;;
  *) echo "Release can be done only on main, develop or quality branch"; exit 1 ;;
esac

if [ "$branch" = "main" ] && [ -n "$releaseType" ] && [ "$releaseType" != "fix" ]; then
  echo "Release type '$releaseType' not supported on main branch"; exit 1
fi
if [ "$branch" = "develop" ] && [ "$releaseType" != "pre" ]; then
  echo "Release type '$releaseType' not supported on develop branch (use -r pre)"; exit 1
fi
if [ "$branch" = "quality" ] && [ "$releaseType" != "rc" ]; then
  echo "Release type '$releaseType' not supported on quality branch (use -r rc)"; exit 1
fi

# Reads MARKETING_VERSION from project.yml (handles quoted or unquoted values)
current=$(awk -F'[[:space:]]*MARKETING_VERSION:[[:space:]]*' \
  '/^[[:space:]]*MARKETING_VERSION:/ { v=$2; gsub(/"/, "", v); print v; exit }' \
  "$PROJECT_YML")
[ -n "$current" ] || { echo "Cannot find MARKETING_VERSION in $PROJECT_YML"; exit 1; }

# Reproduces the `npm version` rules used in the JS variant.
#   bump <current> <versionType> <releaseType> <preid>
bump() {
  cur=$1; vt=$2; rt=$3; preid=$4

  core=${cur%%-*}
  pre=""
  case "$cur" in *-*) pre=${cur#*-} ;; esac

  major=$(echo "$core" | cut -d. -f1)
  minor=$(echo "$core" | cut -d. -f2)
  patch=$(echo "$core" | cut -d. -f3)

  if [ "$vt" = "none" ] && [ -n "$rt" ]; then
    # prerelease bump: same preid → increment counter, else fresh patch prerelease at .0
    cur_preid=${pre%%.*}
    cur_count=${pre##*.}
    if [ -n "$pre" ] && [ "$cur_preid" = "$preid" ] && [ "$cur_count" != "$cur_preid" ]; then
      printf "%s.%s.%s-%s.%d" "$major" "$minor" "$patch" "$preid" $((cur_count + 1))
    else
      printf "%s.%s.%s-%s.0" "$major" "$minor" $((patch + 1)) "$preid"
    fi
    return 0
  fi

  case "$vt" in
    patch) patch=$((patch + 1)) ;;
    minor) minor=$((minor + 1)); patch=0 ;;
    major) major=$((major + 1)); minor=0; patch=0 ;;
    none) ;;
  esac

  if [ -n "$rt" ]; then
    printf "%s.%s.%s-%s.0" "$major" "$minor" "$patch" "$preid"
  else
    printf "%s.%s.%s" "$major" "$minor" "$patch"
  fi
}

if [ "$releaseType" = "pre" ]; then
  preid="$branch"
else
  preid="$releaseType"
fi

new="$current"
if [ "$versionType" != "none" ]; then
  new=$(bump "$current" "$versionType" "$releaseType" "$preid")
fi
if [ "$versionType" = "none" ] && [ -n "$releaseType" ]; then
  new=$(bump "$current" "none" "$releaseType" "$preid")
fi

if [ "$new" = "$current" ]; then
  echo "Nothing to do (versionType=none, releaseType=rel). Use -v or -r."
  exit 0
fi

echo "Bumping $current → $new"

sed -i '' -E "s/(MARKETING_VERSION:[[:space:]]*\")[^\"]+(\")/\\1${new}\\2/" "$PROJECT_YML"

( cd "$ROOT/HostFlow" && xcodegen generate >/dev/null )

git -C "$ROOT" add "$PROJECT_YML" "$PBXPROJ"

case "$releaseType" in
  "")
    git -C "$ROOT" commit -m "chore(release): 💯 release $new"
    git -C "$ROOT" tag -a "$new" -m "🏷️ Release $new"
    ;;
  fix)
    git -C "$ROOT" commit -m "chore(version): 🔥🔧 hotfix version $new"
    ;;
  pre)
    git -C "$ROOT" commit -m "chore(version): 🆙 prerelease version $new"
    ;;
  rc)
    git -C "$ROOT" commit -m "chore(version): 🔜 release candidate version $new"
    ;;
esac

git -C "$ROOT" push --follow-tags
