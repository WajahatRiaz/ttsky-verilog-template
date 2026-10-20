#!/usr/bin/env python3
"""Fail if git-tracked text files are not valid UTF-8."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

SKIP_SUFFIXES = {
    ".png",
    ".gif",
    ".jpg",
    ".jpeg",
    ".webp",
    ".ico",
    ".pdf",
    ".fst",
    ".gds",
    ".vcd",
    ".zip",
    ".bin",
    ".woff",
    ".woff2",
}

TEXT_SUFFIXES = {
    ".v",
    ".vh",
    ".sv",
    ".yaml",
    ".yml",
    ".json",
    ".md",
    ".py",
    ".txt",
    ".tcl",
    ".csv",
    ".sh",
    ".f",
}


def main() -> int:
    files = subprocess.check_output(
        ["git", "ls-files"], cwd=ROOT, text=True
    ).splitlines()
    errors: list[str] = []
    for name in files:
        path = ROOT / name
        if not path.is_file():
            continue
        suffix = path.suffix.lower()
        if suffix in SKIP_SUFFIXES:
            continue
        if suffix not in TEXT_SUFFIXES and suffix != "":
            continue
        try:
            path.read_bytes().decode("utf-8")
        except UnicodeDecodeError as exc:
            errors.append(f"{name}: {exc}")
    if errors:
        print("Invalid UTF-8 in tracked text files:", file=sys.stderr)
        for line in errors:
            print(line, file=sys.stderr)
        return 1
    print(f"UTF-8 OK ({len(files)} tracked paths scanned)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
