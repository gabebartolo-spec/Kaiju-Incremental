#!/usr/bin/env python3
"""cs_magic_numbers.py: no NEW bare numbers in the Unity C# code (hard rule 4, D-480; U6 C7).

Numbers belong in data/ (data/tuning.json). Bare literals are counted per file in
tools/lint/cs_magic_baseline.txt (`path count`); a file's count may only go down:
  MN1  a file with more literals than its baseline row (a file with no row has baseline 0)   fails
  MN2  a file under its baseline row, or gone: lower the row in the same change (--update)    fails
`--update` is shrink-only: each row goes to min(row, today's count), a row at 0 or gone is dropped, and no
path is ever added or raised. `--write-baseline` seeds the file once, when the ratchet starts (from main's
C#); never to admit new numbers.

A literal is any decimal, real, hex or binary number in code (comments and strings blanked by cs_source),
except the integers 0-10 and 0.5, 0.25, 100, 1000 (any f/d/m/u/l suffix: 1f, 1.0 and 1.0f all read as 1).
Hex and binary literals are judged by value like the rest. Exempt: `const` and `static readonly`
declarations (to their own `;`; code after it on the line still counts), attribute brackets at the start of
a line (`[Name...]`; a collection expression `[12.5f, ...]` counts), `case ...:` labels and enum bodies.
Not seen: numbers inside interpolation holes (`$"{x * 1.5f}"`), which cs_source blanks with the string.
Scope: hand-written C# under unity/Assets (cs_source) minus Scripts/Sim/ and Editor/ (Godot ports, build scripts).

Usage: python3 tools/lint/cs_magic_numbers.py [--root DIR] [--update | --write-baseline]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cs_source  # noqa: E402

BASELINE = os.path.join("tools", "lint", "cs_magic_baseline.txt")
EXCLUDED = ("unity/Assets/Scripts/Sim/", "unity/Assets/Editor/")
ALLOWED = {float(n) for n in range(11)} | {0.5, 0.25, 100.0, 1000.0}
# Not after a word character or a lone `.` (member access, a real's fraction); after `..` (a range) it counts.
LITERAL = re.compile(
    r"(?<![\w])(?<!(?<!\.)\.)(?:0[xX][0-9a-fA-F_]+[uUlL]*|0[bB][01_]+[uUlL]*"
    r"|\d[\d_]*(?:\.\d[\d_]*)?(?:[eE][+-]?\d+)?[fFdDmMuUlL]*"
    r"|\.\d[\d_]*(?:[eE][+-]?\d+)?[fFdDmM]?)(?![\w])")
DECLARED = re.compile(r"\bconst\b|\bstatic\s+readonly\b|\breadonly\s+static\b")
ENUM = re.compile(r"\benum\s+\w+")
CASE = re.compile(r"\bcase\b[^:]*:")  # the label only: code after the colon still counts
ATTRIBUTE = re.compile(r"^\s*(?:\[\s*[A-Za-z_][^\]]*\]\s*)+")


def value(text):
    """The numeric value of a C# literal, suffix and digit separators dropped."""
    t = text.replace("_", "")
    if t[:2].lower() == "0x":
        return float(int(t[2:].rstrip("uUlL"), 16))
    if t[:2].lower() == "0b":
        return float(int(t[2:].rstrip("uUlL"), 2))
    return float(t.rstrip("fFdDmMuUlL"))


def _decl_end(line, i, depth):
    """(index of the `;` that ends a declaration, or -1; bracket depth), scanning line from i at depth."""
    for j in range(i, len(line)):
        c = line[j]
        if c in "{([":
            depth += 1
        elif c in "})]":
            depth -= 1
        elif c == ";" and depth <= 0:
            return j, 0
    return -1, depth


def _blank(line, a, b):
    return line[:a] + " " * (b - a) + line[b:]


def _undeclared(line, decl_depth):
    """(line with its const / static readonly parts blanked, None or the bracket depth of one still open)."""
    i = 0
    while True:
        if decl_depth is None:
            m = DECLARED.search(line, i)
            if not m:
                return line, None
            start, i, decl_depth = m.start(), m.end(), 0
        else:
            start = i
        end, decl_depth = _decl_end(line, i, decl_depth)
        if end < 0:
            return _blank(line, start, len(line)), decl_depth
        line, i, decl_depth = _blank(line, start, end + 1), end + 1, None


def literals(code):
    """(line, literal) for each counted literal in stripped code."""
    out = []
    decl_depth = None  # bracket depth inside a const / static readonly declaration still open
    enum_depth = None  # brace depth that ends the current enum body
    depth = 0
    for no, line in enumerate(code.split("\n"), 1):
        exempt = enum_depth is not None
        if enum_depth is None and ENUM.search(line):
            exempt = True
            enum_depth = depth
        depth += line.count("{") - line.count("}")
        if enum_depth is not None and depth <= enum_depth and "}" in line:
            enum_depth = None
        if exempt:
            continue
        code_part, decl_depth = _undeclared(line, decl_depth)
        code_part = CASE.sub(" ", ATTRIBUTE.sub(lambda m: " " * len(m.group(0)), code_part))
        for m in LITERAL.finditer(code_part):
            if value(m.group(0)) not in ALLOWED:
                out.append((no, m.group(0)))
    return out


def scan(root):
    """{path: [(line, literal)]} for every scanned file with at least one literal."""
    found = {}
    for path in cs_source.hand_written(root):
        if path.startswith(EXCLUDED):
            continue
        hits = literals(cs_source.strip(cs_source.read(root, path)))
        if hits:
            found[path] = hits
    return found


def read_baseline(root):
    base = {}
    path = os.path.join(root, BASELINE)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for row in f:
                row = row.strip()
                if row and not row.startswith("#"):
                    key, n = row.rsplit(" ", 1)
                    base[key] = int(n)
    return base


def write_baseline(root, counts):
    header = (
        "# Bare numeric literals per hand-written Unity C# file (hard rule 4, D-480): `path count`.\n"
        "# May only go down; new numbers go to data/. tools/lint/cs_magic_numbers.py --update lowers rows.\n"
    )
    os.makedirs(os.path.dirname(os.path.join(root, BASELINE)), exist_ok=True)
    with open(os.path.join(root, BASELINE), "w", encoding="utf-8", newline="\n") as f:
        f.write(header + "".join("%s %d\n" % (k, v) for k, v in sorted(counts.items())))


def main():
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else "."
    found = scan(root)
    counts = {k: len(v) for k, v in found.items()}
    total = sum(counts.values())
    if "--write-baseline" in sys.argv:  # one-off, when the ratchet starts; never to admit new numbers
        write_baseline(root, counts)
        print("baseline written: %d literals in %d files" % (total, len(found)))
        return 0
    base = read_baseline(root)
    if "--update" in sys.argv:  # shrink-only: lowers rows, drops rows at 0, never adds or raises one
        rows = {k: min(n, counts.get(k, 0)) for k, n in base.items()}
        rows = {k: n for k, n in rows.items() if n > 0}
        write_baseline(root, rows)
        print("baseline lowered: %d literals in %d files" % (sum(rows.values()), len(rows)))
        return 0
    bad = 0
    for path, hits in sorted(found.items()):
        allowed = base.get(path, 0)
        if len(hits) > allowed:
            cs_source.emit(path, hits[0][0], "MN1", "%d bare numbers, baseline %d: move the new ones to data/ "
                           "(tuning.json) or make them named constants" % (len(hits), allowed))
            for line, lit in hits:
                print("  %s:%d: %s" % (path, line, lit))
            bad += 1
    for path in sorted(base):
        n = counts.get(path, 0)
        if n < base[path]:
            cs_source.emit(path, 0, "MN2", "%d bare numbers, baseline %d: lower its row in this change "
                           "(tools/lint/cs_magic_numbers.py --update)" % (n, base[path]))
            bad += 1
    if bad:
        print("FAIL: %d C# file(s) off the magic-number baseline" % bad)
        return 1
    print("ok: %d bare numbers in %d C# files, each at its baseline" % (total, len(found)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
