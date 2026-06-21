#!/usr/bin/env python3
"""Create a new Marktlotse release: bump the version and roll the changelog.

Usage:
    tools/release.py <auto|major|minor|patch|X.Y.Z> [--tag] [--dry-run]

What it does:
  * Reads the current MARKETING_VERSION from the Xcode project.
  * Computes the next semantic version. With `auto`, the bump is derived from the
    Conventional Commits (https://www.conventionalcommits.org) made since the last
    `vX.Y.Z` tag:
        - a commit with `!` after the type/scope or a `BREAKING CHANGE:` footer
          -> major
        - `feat:`            -> minor
        - `fix:` / `perf:`   -> patch
        - everything else    -> no bump on its own
    The highest level among the commits wins.
  * Writes the new MARKETING_VERSION to every build configuration and bumps
    CURRENT_PROJECT_VERSION (the App Store build number) by one.
  * Moves everything under the CHANGELOG "Unreleased" heading into a new dated
    "[X.Y.Z] - YYYY-MM-DD" section and leaves a fresh, empty Unreleased section.
    If Unreleased is empty, the notes are generated from the same commits.
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

# Conventional Commit subject: type(scope)!: description
COMMIT_RE = re.compile(
    r"^(?P<type>[a-zA-Z]+)(?:\((?P<scope>[^)]+)\))?(?P<bang>!)?:\s*(?P<desc>.+)$"
)
BREAKING_FOOTER_RE = re.compile(r"^BREAKING[ -]CHANGE:", re.MULTILINE)

# Bump levels, ordered so max() picks the strongest.
_LEVELS = {None: 0, "patch": 1, "minor": 2, "major": 3}
_LEVEL_NAMES = {v: k for k, v in _LEVELS.items()}
# How notes are grouped in the generated changelog.
_GROUP = {"feat": "Added", "fix": "Fixed", "perf": "Changed"}


def fail(message: str) -> "NoReturn":  # type: ignore[name-defined]
    print(f"error: {message}", file=sys.stderr)
    sys.exit(1)


def git(*args: str) -> str:
    """Run a git command in the repo and return stripped stdout ('' on failure)."""
    result = subprocess.run(
        ["git", "-C", str(ROOT), *args],
        capture_output=True, text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else ""


def last_release_tag() -> str | None:
    """Most recent vX.Y.Z tag reachable from HEAD, or None if there are none."""
    return git("describe", "--tags", "--match", "v[0-9]*", "--abbrev=0") or None


def commits_since(tag: str | None) -> list[dict]:
    """Parse the Conventional Commits between `tag` (exclusive) and HEAD."""
    spec = f"{tag}..HEAD" if tag else "HEAD"
    # Records separated by \x1e, fields (subject, body) by \x1f.
    raw = git("log", spec, "--no-merges", "--format=%s%x1f%b%x1e")
    commits = []
    for record in raw.split("\x1e"):
        record = record.strip("\n")
        if not record:
            continue
        subject, _, body = record.partition("\x1f")
        match = COMMIT_RE.match(subject.strip())
        breaking = bool(BREAKING_FOOTER_RE.search(body))
        if match:
            commits.append({
                "type": match["type"].lower(),
                "scope": match["scope"],
                "breaking": breaking or bool(match["bang"]),
                "desc": match["desc"].strip(),
            })
        else:
            # Non-conventional subject: keep it only as a possible breaking flag.
            commits.append({
                "type": None, "scope": None,
                "breaking": breaking, "desc": subject.strip(),
            })
    return commits


def detect_bump(commits: list[dict]) -> str | None:
    """Strongest SemVer bump implied by the commits, or None if nothing bumps."""
    level = 0
    for c in commits:
        if c["breaking"]:
            level = max(level, _LEVELS["major"])
        elif c["type"] == "feat":
            level = max(level, _LEVELS["minor"])
        elif c["type"] in ("fix", "perf"):
            level = max(level, _LEVELS["patch"])
    return _LEVEL_NAMES[level]


def notes_from_commits(commits: list[dict]) -> str:
    """Build Keep-a-Changelog notes grouped by type from conventional commits."""
    groups: dict[str, list[str]] = {"Added": [], "Changed": [], "Fixed": []}
    for c in commits:
        section = _GROUP.get(c["type"] or "")
        if not section and not c["breaking"]:
            continue
        section = section or "Changed"
        scope = f"**{c['scope']}:** " if c["scope"] else ""
        flag = " **[BREAKING]**" if c["breaking"] else ""
        groups[section].append(f"- {scope}{c['desc']}{flag}")
    parts = [f"### {name}\n" + "\n".join(items)
             for name, items in groups.items() if items]
    return "\n\n".join(parts)


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


def roll_changelog(text: str, version: str, date: str,
                   fallback_notes: str = "") -> tuple[str, str]:
    """Return (new_changelog, notes_for_this_version).

    Manually maintained Unreleased notes take precedence; if that section is
    empty, `fallback_notes` (e.g. generated from commits) is used instead.
    """
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
        body = fallback_notes.strip()
    if not body.strip():
        fail("no change notes: the Unreleased section is empty and no "
             "feat/fix/breaking commits were found to generate them from")

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
    parser.add_argument("bump", help="auto | major | minor | patch | X.Y.Z")
    parser.add_argument("--tag", action="store_true", help="commit and create a git tag")
    parser.add_argument("--dry-run", action="store_true", help="show changes only")
    args = parser.parse_args()

    pbx = PBXPROJ.read_text()
    current = read_current(pbx)

    # Releases are measured against the last released git tag, not the version
    # sitting in the project (which is the *in-development* version).
    tag = last_release_tag()
    last_released = normalize(tag[1:]) if tag else None

    auto_notes = ""

    if last_released is None:
        # First release ever: ship the current project version as-is (e.g. 1.0.0).
        # A bump keyword has nothing to bump from, so it is ignored; an explicit
        # X.Y.Z still lets you choose a different first version.
        if SEMVER_RE.match(args.bump):
            new = normalize(args.bump)
        else:
            new = current
            print(f"First release: no prior tag — releasing the current version "
                  f"{'.'.join(map(str, new))} as-is (bump '{args.bump}' ignored).")
        if args.bump == "auto":
            auto_notes = notes_from_commits(commits_since(None))
    else:
        bump = args.bump
        if bump == "auto":
            commits = commits_since(tag)
            detected = detect_bump(commits)
            if detected is None:
                print(f"No feat/fix/breaking commits since {tag}; nothing to release.")
                return
            print(f"Detected {detected} bump from {len(commits)} commit(s) since {tag}.")
            bump = detected
            auto_notes = notes_from_commits(commits)
        new = next_version(last_released, bump)
        if new <= last_released:
            fail(f"new version {'.'.join(map(str, new))} is not greater than the "
                 f"last released {'.'.join(map(str, last_released))} ({tag})")

    version = ".".join(map(str, new))
    build = next_build(pbx)
    date = _dt.date.today().isoformat()

    new_pbx = MARKETING_RE.sub(f"MARKETING_VERSION = {version};", pbx)
    new_pbx = BUILD_RE.sub(f"CURRENT_PROJECT_VERSION = {build};", new_pbx)

    changelog = CHANGELOG.read_text()
    new_changelog, notes = roll_changelog(changelog, version, date, auto_notes)
    new_changelog = update_link_refs(new_changelog, version)

    baseline = ".".join(map(str, last_released)) if last_released else "(first release)"
    print(f"Version: {baseline} -> {version} (build {build})")
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
