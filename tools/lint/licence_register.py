#!/usr/bin/env python3
"""Every file under assets/ is covered by a CLEARED (or DEV ONLY) row of docs/LICENSING_REGISTER.md.

CLAUDE.md hard rule 5: nothing enters assets/ unless the register lists it CLEARED. Until debt row 6
(D-295, 2026-10-27) nothing read the register. This reads its table (Item | Path | Source | Licence |
Status), turns each Path cell's back-quoted paths into patterns and fails on any asset file no row covers.

    python tools/lint/licence_register.py             # CI (lint.yml) and tools/prepush.sh
    python tools/lint/licence_register.py --release   # also fail when a DEV ONLY file is in the tree (for an export)
    python tools/lint/licence_register.py --self-test # plant an uncovered file; it must fail

Patterns: `*` any characters except `/`, `**` any characters, `?` one, `{a,b}` alternatives. A `.import`
file follows its source file; `.gdignore` is engine metadata. Status words: CLEARED covers, DEV ONLY covers
for development builds (director D-261: Cascadeur trial animations), anything else (PENDING, BLOCKED)
covers nothing. A CLEARED row needs a Source and a Licence. Exit 0 when all pass, 1 otherwise.
"""
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
REGISTER = "docs/LICENSING_REGISTER.md"
META = (".gdignore",)


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
        paths = [p for p in re.findall(r"`([^`]+)`", cells[1]) if p.startswith("assets/")]
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
        if os.path.basename(f) in META:
            continue
        if base != f and base not in seen:
            uncovered.append(f"{f} (its source file {base} is not in the tree)")
            continue
        hits = [r for r in rows if r.covers(base)]
        if any(r.kind == "cleared" for r in hits):
            continue
        if any(r.kind == "dev" for r in hits):
            dev_only.append(f)
        else:
            uncovered.append(f)
    stale = [
        t
        for r in rows
        if r.kind != "none"
        for t, rx in zip(r.texts, r.patterns)
        if not any(rx.match(f[: -len(".import")] if f.endswith(".import") else f) for f in files)
    ]
    return uncovered, dev_only, stale


def asset_files(root: str) -> list[str]:
    """Tracked and untracked-but-not-ignored files under assets/ (so a new file is seen before it is committed)."""
    out = subprocess.run(
        ["git", "ls-files", "-co", "--exclude-standard", "--", "assets"], capture_output=True, text=True, cwd=root
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
        "| Music | `assets/music/**` | not yet | n/a | PENDING |\n"
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
    ok &= check(["assets/fonts/orphan.ttf.import"], rows)[0] != []  # an import file with no source
    ok &= bool(parse_register("| A | `assets/x` | s | l |\n")[1])  # a short row is reported
    print("ok: a planted uncovered file, a PENDING row, a DEV ONLY file and an orphan .import are all handled" if ok else "FAIL: the register check is blind")
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    with open(os.path.join(ROOT, REGISTER), encoding="utf-8") as f:
        rows, problems = parse_register(f.read())
    files = asset_files(ROOT)
    uncovered, dev_only, stale = check(files, rows)
    gh = bool(os.environ.get("GITHUB_ACTIONS"))
    for line in problems:
        print(f"::error::{line}" if gh else f"ERROR: {line}")
    for f in uncovered[:60]:
        msg = f"{f}: no CLEARED row in {REGISTER} covers this file (add one: Item | Path | Source | Licence | Status)"
        print(f"::error::{msg}" if gh else f"ERROR: {msg}")
    if len(uncovered) > 60:
        print(f"... and {len(uncovered) - 60} more")
    for t in stale[:20]:
        print(f"note: the register path `{t}` matches no file in assets/")
    if dev_only:
        print(f"note: {len(dev_only)} files are DEV ONLY (development builds only): {', '.join(dev_only[:5])}{' ...' if len(dev_only) > 5 else ''}")
    if "--release" in argv and dev_only:
        print(f"::error::{len(dev_only)} DEV ONLY files are in the tree; a release build may not ship them" if gh else "ERROR: DEV ONLY files in a release tree")
        return 1
    if problems or uncovered:
        print(f"licence register: {len(uncovered)} uncovered files, {len(problems)} row problems")
        return 1
    print(f"ok: {len(files)} asset files, every one covered by a CLEARED or DEV ONLY row ({len(rows)} rows)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
