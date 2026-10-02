#!/usr/bin/env python3
"""Pin the Homebrew cask to a tagged DMG (no Homebrew/PyPI dependencies)."""
import argparse
import hashlib
from pathlib import Path
import re


def update_cask(tag: str, dmg: Path, cask: Path) -> None:
    if not re.fullmatch(r"v\d+\.\d+\.\d+", tag):
        raise ValueError("Release tag must be vMAJOR.MINOR.PATCH")
    digest = hashlib.sha256(dmg.read_bytes()).hexdigest()
    text = cask.read_text()
    replacements = {
        r"^  version .+$": f'  version "{tag[1:]}"',
        r"^  sha256 .+$": f'  sha256 "{digest}"',
        r"^  url .+$": '  url "https://github.com/jwafle/murmur/releases/download/v#{version}/Murmur.dmg"',
    }
    for pattern, replacement in replacements.items():
        text, count = re.subn(pattern, lambda _: replacement, text, flags=re.MULTILINE)
        if count != 1:
            raise ValueError(f"Expected exactly one cask field matching {pattern}")
    cask.write_text(text)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("tag")
    parser.add_argument("dmg", type=Path)
    parser.add_argument("cask", type=Path)
    args = parser.parse_args()
    update_cask(args.tag, args.dmg, args.cask)
