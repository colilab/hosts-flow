#!/usr/bin/env python3
"""Append a new <item> to the Sparkle appcast on the gh-pages branch.

Usage:
    append_appcast.py <entry.json> <appcast.xml> <tag> <repo> <notes-html-file>

<entry.json>  : appcast-entry.json produced by Scripts/build-release.sh.
<appcast.xml> : the feed file to mutate in place.
<tag>         : the git tag / GitHub release tag (e.g. "1.0.1").
<repo>        : "owner/name" — used to build the asset download URL.
<notes-html>  : file with the release body already converted to HTML.

The item is inserted right before </channel>. Sparkle selects the highest
sparkle:version regardless of item order, so ordering is not load-bearing.
A tag already present in the feed is a no-op (idempotent re-runs).
"""

import json
import re
import sys
from datetime import datetime, timezone
from email.utils import format_datetime


def main() -> int:
    entry_path, appcast_path, tag, repo, notes_path = sys.argv[1:6]

    with open(entry_path, encoding="utf-8") as fh:
        entry = json.load(fh)

    with open(appcast_path, encoding="utf-8") as fh:
        appcast = fh.read()

    enclosure_url = (
        f"https://github.com/{repo}/releases/download/{tag}/{entry['dmgFilename']}"
    )

    if enclosure_url in appcast:
        print(f"appcast already contains {tag} — nothing to do")
        return 0

    try:
        with open(notes_path, encoding="utf-8") as fh:
            notes_html = fh.read().strip()
    except OSError:
        notes_html = ""

    pub_date = format_datetime(datetime.now(timezone.utc))

    item = f"""    <item>
      <title>{entry['shortVersion']}</title>
      <pubDate>{pub_date}</pubDate>
      <sparkle:version>{entry['version']}</sparkle:version>
      <sparkle:shortVersionString>{entry['shortVersion']}</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>{entry['minimumSystemVersion']}</sparkle:minimumSystemVersion>
      <description><![CDATA[{notes_html}]]></description>
      <enclosure
        url="{enclosure_url}"
        sparkle:edSignature="{entry['edSignature']}"
        length="{entry['length']}"
        type="application/octet-stream" />
    </item>
"""

    if "</channel>" not in appcast:
        print("ERROR: appcast.xml has no </channel> — is the feed valid?", file=sys.stderr)
        return 1

    # Consume any indentation on the </channel> line so the new <item> lands at
    # a clean 4-space indent regardless of how the closing tag was formatted.
    appcast = re.sub(r"[ \t]*</channel>", item + "  </channel>", appcast, count=1)

    with open(appcast_path, "w", encoding="utf-8") as fh:
        fh.write(appcast)

    print(f"appended appcast item for {tag}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
