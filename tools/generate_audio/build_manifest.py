#!/usr/bin/env python3
"""
Build audio_manifest.json from .progress.json for the Flutter app.

Reads audio_out/.progress.json and produces a story-key keyed manifest that the
app can drop into assets/ and use directly with the story keys it already
constructs (e.g. '1.1.2' for Hindi story #1 in category #1).

Usage:
    python build_manifest.py
    python build_manifest.py --langs=hu --base-url=https://pub-XXX.r2.dev/v1
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
DEFAULT_PROGRESS = SCRIPT_DIR / "audio_out" / ".progress.json"
DEFAULT_OUT = SCRIPT_DIR / "audio_manifest.json"
DEFAULT_BASE_URL = "https://pub-18b8b7f021394fefb831920c904f83e7.r2.dev/v1"

# Maps language code -> the suffix the Flutter app uses in story keys
# (see story_list_screen.dart _storyKey: '$base' for en, '$base.1' for gu,
#  '$base.2' for hu, '$base.3' for sa)
LANG_SUFFIX = {"gu": "1", "hu": "2"}


def main():
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--progress", type=Path, default=DEFAULT_PROGRESS,
                   help="Path to .progress.json. Default: audio_out/.progress.json")
    p.add_argument("--out", type=Path, default=DEFAULT_OUT,
                   help="Output path for the manifest. Default: audio_manifest.json")
    p.add_argument("--base-url", default=DEFAULT_BASE_URL,
                   help="Public base URL for the R2 bucket including version prefix")
    p.add_argument("--langs", default="hu",
                   help="Comma-separated langs to include. Default: hu")
    p.add_argument("--require-uploaded", type=Path, default=None,
                   help="Optional: only include entries whose Opus file exists in this dir. "
                        "Use to filter out non-uploaded items.")
    args = p.parse_args()

    langs = [l.strip() for l in args.langs.split(",") if l.strip()]
    for l in langs:
        if l not in LANG_SUFFIX:
            raise SystemExit(f"unsupported lang: {l} (supported: {list(LANG_SUFFIX)})")

    with open(args.progress, "r", encoding="utf-8") as f:
        progress = json.load(f)

    manifest = {}
    skipped_missing_file = 0
    for sid, entry in progress.items():
        # sid looks like "01_01" -> category=1, story=1
        cat_str, story_str = sid.split("_")
        cat = int(cat_str)
        story = int(story_str)
        voice = entry.get("voice", "unknown")

        for lang in langs:
            if lang not in entry:
                continue
            # Construct the story key the app already uses
            base = f"{cat}.{story}"
            story_key = f"{base}.{LANG_SUFFIX[lang]}"
            # R2 path: v1/hu/01_01.opus  ->  full URL via --base-url
            filename = f"{cat_str}_{story_str}.opus"
            url = f"{args.base_url.rstrip('/')}/{lang}/{filename}"

            if args.require_uploaded:
                opus_file = args.require_uploaded / f"{lang}_{cat_str}_{story_str}.opus"
                if not opus_file.exists():
                    skipped_missing_file += 1
                    continue

            manifest[story_key] = {
                "url": url,
                "voice": voice,
            }

    # Sort by chapter then story for readability
    def sort_key(item):
        k = item[0]
        parts = k.split(".")
        return (int(parts[0]), int(parts[1]), int(parts[2]))

    sorted_manifest = dict(sorted(manifest.items(), key=sort_key))

    out_data = {
        "version": "v1",
        "base_url": args.base_url,
        "format": "opus",
        "languages": langs,
        "count": len(sorted_manifest),
        "stories": sorted_manifest,
    }

    with open(args.out, "w", encoding="utf-8") as f:
        json.dump(out_data, f, indent=2, ensure_ascii=False)

    print(f"Wrote {args.out}")
    print(f"  entries: {len(sorted_manifest)}")
    print(f"  languages: {langs}")
    if skipped_missing_file:
        print(f"  skipped (no local .opus file): {skipped_missing_file}")
    print(f"  size: {args.out.stat().st_size // 1024} KB")
    if sorted_manifest:
        first_key = next(iter(sorted_manifest))
        print(f"  sample: {first_key} -> {sorted_manifest[first_key]}")


if __name__ == "__main__":
    main()
