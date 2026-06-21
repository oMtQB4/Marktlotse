#!/usr/bin/env python3
"""Create a new Marktlotse release: bump the version and roll the changelog.

Usage:
    tools/release.py <major|minor|patch|X.Y.Z> [--tag] [--dry-run]

What it does:
  * Reads the current MARKETING_VERSION from the Xcode project.
  * Computes the next semantic version (or uses the explicit X.Y.Z you pass).
  * Writes the new MARKETING_VERSION to every build configuration and bumps
    CURRENT_PROJECT_VERSION (the App Store build number) by one.
  * Moves everything under the CHANGELOG "Unreleased" heading into a new dated
    "[X.Y.Z] - YYYY-MM-DD" section and leaves a fresh, empty Unreleased section.
  * Prints the release notes for the new version (paste into App Store Connect's
    "What's New").
  * With --tag, commits the version/changelog changes and creates tag vX.Y.Z.

--dry-run prints what would change without touching any files.
"""

from __future__ import annotations

import argparse
import datetime as _dt
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PBXPROJ = ROOT / "Marktlotse.xcodeproj" / "project.pbxproj"
CHANGELOG = ROOT / "CHANGELOG.md"

MARKETING_RE = re.compile(r"MARKETING_VERSION = ([^;]+);")
BUILD_RE = re.compile(r"CURRENT_PROJECT_VERSION = ([^;]+);")
SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def normalize(version: str) -> tuple[int, int, int]:
    """Parse a version string into (major, minor, patch), padding short forms."""
    parts = version.strip().split(".")
    if not all(p.isdigit() for p in parts) or not 1 <= len(parts) <= 3:
        fail(f"cannot parse version '{version}'")
    while len(parts) < 3:
        parts.append("0")
    major, minor, patch = (int(p) for p in parts[:3])
    return major, minor, patch


def next_version(current: tuple[int, int, int], bump: str) -> tuple[int, int, int]:
    major, minor, patch = current
    if bump == "major":
        return major + 1, 0, 0
    if bump == "minor":
        return major, minor + 1, 0
    if bump == "patch":
        return major, minor, patch + 1
    if SEMVER_RE.match(bump):
        return normalize(bump)
    fail(f"expected major|minor|patch or an explicit X.Y.Z version, got '{bump}'")


def read_current(pbx: str) -> tuple[int, int, int]:
    versions = set(MARKETING_RE.findall(pbx))
    if not versions:
        fail("no MARKETING_VERSION found in project.pbxproj")
    if len(versions) > 1:
        fail(f"inconsistent MARKETING_VERSION across configs: {sorted(versions)}")
    return normalize(versions.pop())


def next_build(pbx: str) -> int:
    builds = [int(b) for b in BUILD_RE.findall(pbx) if b.isdigit()]
    return (max(builds) + 1) if builds else 1


def roll_changelog(text: str, version: str, date: str) -> tuple[str, str]:
    """Return (new_changelog, notes_for_this_version)."""
    marker = "## [Unreleased]"
    if marker not in text:
        fail("CHANGELOG.md has no '## [Unreleased]' section")

    start = text.index(marker) + len(marker)
    rest = text[start:]
    # The Unreleased body runs until the next version heading or, if this is the
    # first release, until the link-reference block at the bottom of the file.
    boundary = re.search(r"\n(## \[|\[[^\]]+\]:\s)", rest)
    end = boundary.start() if boundary else len(rest)
    body = rest[:end].strip("\n")

    if not body.strip():
        fail("the Unreleased section is empty — add change notes before releasing")

    released = f"## [{version}] - {date}\n\n{body}"
    tail = rest[end:].lstrip("\n")
    new_text = (
        text[: text.index(marker)]
        + f"{marker}\n\n{released}\n\n"
        + tail
    )
    return new_text, body


def update_link_refs(text: str, version: str) -> str:
    """Best-effort update of the compare/tag link references at the file bottom."""
    text = re.sub(
        r"\[Unreleased\]: (.*/compare/)v[\d.]+\.\.\.HEAD",
        rf"[Unreleased]: \1v{version}...HEAD",
        text,
    )
    if f"[{version}]:" not in text and "/releases/tag/" in text:
        anchor = re.search(r"\n\[[\d.]+\]: (.*/releases/tag/)v[\d.]+", text)
        if anchor:
            base = anchor.group(1)
            insert = f"\n[{version}]: {base}v{version}"
            unrel = re.search(r"\n\[Unreleased\]: .*", text)
            if unrel:
                pos = unrel.end()
                text = text[:pos] + insert + text[pos:]
    return text


def main() -> None:
    parser = argparse.ArgumentParser(description="Bump version and roll the changelog.")
    parser.add_argument("bump", help="major | minor | patch | X.Y.Z")
    parser.add_argument("--tag", action="store_true", help="commit and create a git tag")
    parser.add_argument("--dry-run", action="store_true", help="show changes only")
    args = parser.parse_args()

    pbx = PBXPROJ.read_text()
    current = read_current(pbx)
    new = next_version(current, args.bump)
    if new <= current:
        fail(f"new version {'.'.join(map(str, new))} is not greater than "
             f"current {'.'.join(map(str, current))}")

    version = ".".join(map(str, new))
    build = next_build(pbx)
    date = _dt.date.today().isoformat()

    new_pbx = MARKETING_RE.sub(f"MARKETING_VERSION = {version};", pbx)
    new_pbx = BUILD_RE.sub(f"CURRENT_PROJECT_VERSION = {build};", new_pbx)

    changelog = CHANGELOG.read_text()
    new_changelog, notes = roll_changelog(changelog, version, date)
    new_changelog = update_link_refs(new_changelog, version)

    print(f"Version: {'.'.join(map(str, current))} -> {version} (build {build})")
    print(f"Date:    {date}")
    print("\nRelease notes (for App Store \"What's New\"):\n")
    print(notes)
    print()

    if args.dry_run:
        print("dry run: no files written.")
        return

    PBXPROJ.write_text(new_pbx)
    CHANGELOG.write_text(new_changelog)
    print(f"Updated {PBXPROJ.relative_to(ROOT)} and {CHANGELOG.relative_to(ROOT)}.")

    if args.tag:
        tag = f"v{version}"
        subprocess.run(["git", "-C", str(ROOT), "add",
                        str(PBXPROJ), str(CHANGELOG)], check=True)
        subprocess.run(["git", "-C", str(ROOT), "commit",
                        "-m", f"chore(release): {tag}"], check=True)
        subprocess.run(["git", "-C", str(ROOT), "tag", "-a", tag,
                        "-m", f"Marktlotse {version}"], check=True)
        print(f"Committed and tagged {tag}. Push with: git push && git push origin {tag}")
    else:
        print("Review the changes, then commit. (Re-run with --tag to auto-commit "
              "and tag.)")


if __name__ == "__main__":
    main()
