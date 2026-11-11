#!/usr/bin/env python3
"""Every file under assets/, unity/Assets/ and unity/native/ is covered by a CLEARED (or DEV ONLY) row of
docs/LICENSING_REGISTER.md.

CLAUDE.md hard rule 5: nothing enters assets/ unless the register lists it CLEARED. Until debt row 6
(D-295, 2026-10-27) nothing read the register. This reads its table (Item | Path | Source | Licence |
Status), turns each Path cell's back-quoted paths into patterns and fails on any asset file no row covers.

    python tools/lint/licence_register.py             # CI (lint.yml) and tools/prepush.sh
    python tools/lint/licence_register.py --release   # also fail on a DEV ONLY or PENDING_RULING file (for an export)
    python tools/lint/licence_register.py --self-test # plant an uncovered file; it must fail

Patterns: `*` any characters except `/`, `**` any characters, `?` one, `{a,b}` alternatives. A `.import`
file follows its source file; `.gdignore` is engine metadata. Status words: CLEARED covers, DEV ONLY covers
for development builds (director D-261: Cascadeur trial animations), anything else (PENDING, BLOCKED)
covers nothing. A file matched by a DEV ONLY row is DEV ONLY even when a CLEARED row's glob also matches
it (D-261, D-301: Cascadeur trial clips ship nothing until the director buys the licence), so a broad CLEARED
glob such as assets/kaiju/*.kclip can never make a trial clip shippable. A CLEARED row needs a Source and a
Licence. Unity's .meta files are engine metadata and are skipped (U6 step 4: the Unity port ships too).
PENDING_RULING names any file whose row waits on the director's ruling (empty since D-479 cleared the Unity-generated
HDRP files): while unruled and uncovered they print as a
NOTICE, not an error, on a development run so the list is visible on every run; --release fails on them (an unruled
file cannot ship, hard rule 5). Once a row covers one the lint fails until it is dropped from the list (one gone from
the tree is a note). Exit 0 when all pass, 1 otherwise.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
REGISTER = "docs/LICENSING_REGISTER.md"
META = (".gdignore",)
# The trees the register covers: the Godot game's assets and the Unity port (D-470) that ships beside it.
ROOTS = ("assets", "unity/Assets", "unity/native")
# Unity's per-file metadata (GUID and import settings), never content.
UNITY_META = ".meta"
# Uncovered on purpose until the director rules on their row; empty while nothing waits.
PENDING_RULING: tuple[str, ...] = ()  # D-479 cleared the five Unity-generated HDRP files


def expand_braces(pattern: str) -> list[str]:
    m = re.search(r"\{([^{}]*)\}", pattern)
    if not m:
        return [pattern]
    out: list[str] = []
    for alt in m.group(1).split(","):
        out += expand_braces(pattern[: m.start()] + alt.strip() + pattern[m.end() :])
    return out


def to_regex(pattern: str) -> "re.Pattern[str]":
    rx = ""
    i = 0
    while i < len(pattern):
        ch = pattern[i]
        if pattern.startswith("**", i):
            rx += ".*"
            i += 2
            continue
        rx += "[^/]*" if ch == "*" else "[^/]" if ch == "?" else re.escape(ch)
        i += 1
    return re.compile("^" + rx + "$")


class Row:
    def __init__(self, item: str, paths: list[str], source: str, licence: str, status: str):
        self.item, self.source, self.licence, self.status = item, source, licence, status
        self.patterns = [to_regex(x) for p in paths for x in expand_braces(p)]
        self.texts = [x for p in paths for x in expand_braces(p)]
        word = status.strip().upper()
        self.kind = "cleared" if word.startswith("CLEARED") else "dev" if word.startswith("DEV ONLY") else "none"

    def covers(self, path: str) -> bool:
        return any(rx.match(path) for rx in self.patterns)


def parse_register(text: str) -> tuple[list[Row], list[str]]:
    rows: list[Row] = []
    problems: list[str] = []
    for n, line in enumerate(text.splitlines(), 1):
        if not line.startswith("| ") or line.startswith("| ---") or line.startswith("| Item "):
            continue
        cells = [c.strip() for c in line.strip().strip("|").split(" | ")]
        if len(cells) != 5:
            problems.append(f"{REGISTER}:{n}: a row needs 5 cells (Item | Path | Source | Licence | Status), has {len(cells)}")
            continue
        paths = [p for p in re.findall(r"`([^`]+)`", cells[1]) if any(p.startswith(r + "/") for r in ROOTS)]
        row = Row(cells[0], paths, cells[2], cells[3], cells[4])
        if row.kind == "cleared" and (len(row.source) < 10 or len(row.licence) < 3):
            problems.append(f"{REGISTER}:{n}: CLEARED row '{cells[0][:50]}' has no Source or Licence")
        rows.append(row)
    return rows, problems


def check(files: list[str], rows: list[Row]) -> tuple[list[str], list[str], list[str]]:
    """(uncovered files, files covered only by DEV ONLY rows, patterns that match no file)."""
    uncovered: list[str] = []
    dev_only: list[str] = []
    seen = set(files)
    for f in files:
        base = f[: -len(".import")] if f.endswith(".import") else f
        if os.path.basename(f) in META or (f.startswith("unity/") and f.endswith(UNITY_META)):
            continue
        if base != f and base not in seen:
            uncovered.append(f"{f} (its source file {base} is not in the tree)")
            continue
        hits = [r for r in rows if r.covers(base)]
        if any(r.kind == "dev" for r in hits):  # DEV ONLY wins over any CLEARED match (D-261, D-301)
            dev_only.append(f)
        elif not any(r.kind == "cleared" for r in hits):
            uncovered.append(f)
    stale = [
        t
        for r in rows
        if r.kind != "none"
        for t, rx in zip(r.texts, r.patterns)
        if not any(rx.match(f[: -len(".import")] if f.endswith(".import") else f) for f in files)
    ]
    return uncovered, dev_only, stale


def split_pending(
    uncovered: list[str], files: list[str], pending: tuple[str, ...]
) -> tuple[list[str], list[str], list[str], list[str]]:
    """(uncovered files not on the pending list, pending files still uncovered, pending files a row now covers,
    pending entries not in the tree)."""
    waiting = [f for f in uncovered if f in pending]
    covered = [p for p in pending if p in files and p not in waiting]
    gone = [p for p in pending if p not in files]
    return [f for f in uncovered if f not in pending], waiting, covered, gone


def release_blockers(dev_only: list[str], waiting: list[str]) -> list[str]:
    """What stops a release export: DEV ONLY files and PENDING_RULING files still without a row."""
    out = [f"{len(dev_only)} DEV ONLY files are in the tree; a release build may not ship them"] if dev_only else []
    if waiting:
        out.append(f"{len(waiting)} PENDING_RULING files cannot ship until a CLEARED row covers them: {', '.join(waiting)}")
    return out


def asset_files(root: str) -> list[str]:
    """Tracked and untracked-but-not-ignored files under ROOTS (so a new file is seen before it is committed)."""
    out = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard", "--", *ROOTS], capture_output=True, text=True, cwd=root
    )
    if out.returncode != 0:
        raise SystemExit(f"git ls-files failed: {out.stderr.strip()[:200]}")
    return sorted({p for p in out.stdout.split("\n") if p and os.path.exists(os.path.join(root, p))})


def self_test() -> int:
    table = (
        "| Item | Path | Source | Licence | Status |\n|---|---|---|---|---|\n"
        "| Fonts | `assets/fonts/kaiju_*.ttf` | drawn by us in tools/fonts | Ours | CLEARED |\n"
        "| Sfx | `assets/sfx/{a,b}.ogg` | generated, paid plan | paid terms | CLEARED |\n"
        "| Trial | `assets/trial/*.kclip` | Cascadeur Pro trial | trial, no commercial use | DEV ONLY |\n"
        "| Clips | `assets/clips/*.kclip` | our own keyed clips | Ours | CLEARED |\n"
        "| Trial clips | `assets/clips/trial_*.kclip` | Cascadeur Pro trial | trial, no commercial use | DEV ONLY |\n"
        "| Music | `assets/music/**` | not yet | n/a | PENDING |\n"
        "| Unity code | `unity/Assets/Scripts/**` | written for this game | Ours | CLEARED |\n"
    )
    rows, problems = parse_register(table)
    ok = not problems
    files = ["assets/fonts/kaiju_a.ttf", "assets/fonts/kaiju_a.ttf.import", "assets/sfx/a.ogg", "assets/sfx/b.ogg.import"]
    ok &= check(files + ["assets/sfx/b.ogg"], rows)[0] == []
    planted = check(files + ["assets/sfx/b.ogg", "assets/sfx/planted.ogg"], rows)[0]
    ok &= planted == ["assets/sfx/planted.ogg"]
    ok &= check(["assets/music/track.ogg"], rows)[0] == ["assets/music/track.ogg"]  # PENDING covers nothing
    dev = check(["assets/trial/x.kclip"], rows)
    ok &= dev[0] == [] and dev[1] == ["assets/trial/x.kclip"]
    both = check(["assets/clips/a.kclip", "assets/clips/trial_roar.kclip"], rows)  # DEV ONLY beats a CLEARED glob
    ok &= both[0] == [] and both[1] == ["assets/clips/trial_roar.kclip"]
    ok &= check(["assets/fonts/orphan.ttf.import"], rows)[0] != []  # an import file with no source
    ok &= bool(parse_register("| A | `assets/x` | s | l |\n")[1])  # a short row is reported
    unity = ["unity/Assets/Scripts/A.cs", "unity/Assets/Scripts/A.cs.meta", "unity/Assets/X.asset", "unity/Assets/Y.asset"]
    ok &= check(unity, rows)[0] == ["unity/Assets/X.asset", "unity/Assets/Y.asset"]  # a Unity row covers, .meta skipped
    pend = ("unity/Assets/X.asset", "unity/Assets/Scripts/A.cs", "unity/Assets/Gone.asset")
    left, waiting, covered, gone = split_pending(check(unity, rows)[0], unity, pend)
    ok &= left == ["unity/Assets/Y.asset"] and waiting == ["unity/Assets/X.asset"]
    ok &= covered == ["unity/Assets/Scripts/A.cs"] and gone == ["unity/Assets/Gone.asset"]
    ok &= len(release_blockers([], waiting)) == 1 and release_blockers([], []) == []  # a pending file blocks a release
    ok &= len(release_blockers(["assets/trial/x.kclip"], [])) == 1
    print("ok: a planted uncovered file, a PENDING row, a DEV ONLY file (also under a CLEARED glob), an orphan .import, a Unity .meta and the pending-ruling list (which blocks a release) are all handled" if ok else "FAIL: the register check is blind")
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    with open(os.path.join(ROOT, REGISTER), encoding="utf-8") as f:
        rows, problems = parse_register(f.read())
    files = asset_files(ROOT)
    uncovered, dev_only, stale = check(files, rows)
    uncovered, waiting, covered, gone = split_pending(uncovered, files, PENDING_RULING)
    gh = bool(os.environ.get("GITHUB_ACTIONS"))
    for f in waiting:
        msg = f"{f}: no row yet, waiting on the director's ruling (PENDING_RULING in tools/lint/licence_register.py)"
        print(f"::notice::{msg}" if gh else f"NOTICE: {msg}")
    for f in covered:
        msg = f"{f} is on PENDING_RULING but a CLEARED or DEV ONLY row covers it now: drop it from the list"
        print(f"::error::{msg}" if gh else f"ERROR: {msg}")
        problems.append(msg)
    for f in gone:
        print(f"note: {f} is on PENDING_RULING but not in the tree")
    for line in problems:
        print(f"::error::{line}" if gh else f"ERROR: {line}")
    for f in uncovered[:60]:
        msg = f"{f}: no CLEARED row in {REGISTER} covers this file (add one: Item | Path | Source | Licence | Status)"
        print(f"::error::{msg}" if gh else f"ERROR: {msg}")
    if len(uncovered) > 60:
        print(f"... and {len(uncovered) - 60} more")
    for t in stale[:20]:
        print(f"note: the register path `{t}` matches no file under {', '.join(ROOTS)}")
    if dev_only:
        print(f"note: {len(dev_only)} files are DEV ONLY (development builds only): {', '.join(dev_only[:5])}{' ...' if len(dev_only) > 5 else ''}")
    blockers = release_blockers(dev_only, waiting) if "--release" in argv else []
    for line in blockers:
        print(f"::error::{line}" if gh else f"ERROR: {line}")
    if blockers:
        return 1
    if problems or uncovered:
        print(f"licence register: {len(uncovered)} uncovered files, {len(problems)} row problems")
        return 1
    pending = f", {len(waiting)} waiting on a ruling" if waiting else ""
    print(f"ok: {len(files)} asset files (under {', '.join(ROOTS)}), every one covered by a CLEARED or DEV ONLY row ({len(rows)} rows){pending}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
