#!/usr/bin/env python3
"""complexity_ratchet.py: no NEW function over 40 lines or cyclomatic complexity over 12.

The limits are the project's own (.gdlintrc header, docs/05); gdlint cannot check either (audit
2026-10-21 #25). Scans sim/, scenes/ and autoload/. Today's offenders are listed in
tools/lint/complexity_baseline.txt (one `path::function lines cc` row each); the file may only
shrink:
  CR1  a function over a limit that is not in the baseline           (new offender)
  CR2  a baselined function that grew in lines or complexity
  CR3  a baselined function now within both limits, or gone: delete its row (or run --shrink)
`--shrink` rewrites the baseline keeping only the rows still over a limit, at their current numbers;
it never adds a row. A renamed or moved offender counts as new on purpose: fix it, do not rename it.

Counting (a scanner, not a parser; close enough to hold a line):
  lines  from the `func` line to its last code line (blank and comment-only lines at the end drop);
  cc     1 + each if/elif/for/while/match arm + each `and`/`or`/`&&`/`||` + each inline `x if c else y`.

Usage: python3 tools/lint/complexity_ratchet.py [--root DIR] [--shrink]
"""
import os
import re
import sys

MAX_LINES = 40
MAX_CC = 12
DIRS = ["sim", "scenes", "autoload"]
BASELINE = os.path.join("tools", "lint", "complexity_baseline.txt")
FUNC = re.compile(r"^(\t*)(?:static\s+)?func\s+(\w+)\s*\(")
BRANCH = re.compile(r"^\s*(?:if|elif|for|while)\b")
LOGIC = re.compile(r"\b(?:and|or)\b|&&|\|\|")
TERNARY = re.compile(r"\S\s+if\s+.+\s+else\s+")


def strip(line):
    """The code of a line: no comment, strings blanked (so a '#', 'if' or 'and' in text is ignored)."""
    out = []
    quote = ""
    for ch in line.rstrip("\n"):
        if quote:
            out.append(" ")
            if ch == quote:
                quote = ""
        elif ch in "\"'":
            quote = ch
            out.append(" ")
        elif ch == "#":
            break
        else:
            out.append(ch)
    return "".join(out)


def indent(line):
    return len(line) - len(line.lstrip("\t"))


def functions(path):
    with open(path, encoding="utf-8") as f:
        lines = f.read().split("\n")
    out = []
    i = 0
    while i < len(lines):
        m = FUNC.match(lines[i])
        if not m:
            i += 1
            continue
        base = len(m.group(1))
        j = i + 1
        last = i
        while j < len(lines):
            code = strip(lines[j])
            if code.strip():
                if indent(code) <= base:
                    break
                last = j
            j += 1
        out.append((m.group(2), i + 1, last - i + 1, _cc(lines[i : last + 1])))
        i = last + 1
    return out


def _cc(body):
    cc = 1
    match_arm_indent = []  # indents of the arms of the match blocks we are inside
    for line in body:
        code = strip(line)
        if not code.strip():
            continue
        ind = indent(code)
        while match_arm_indent and ind < match_arm_indent[-1]:
            match_arm_indent.pop()
        if match_arm_indent and ind == match_arm_indent[-1]:
            cc += 1  # a match arm
        stripped = code.strip()
        if BRANCH.match(code):
            cc += 1
        if stripped.startswith("match "):
            match_arm_indent.append(ind + 1)
        cc += len(LOGIC.findall(code))
        if TERNARY.search(code) and not BRANCH.match(code):
            cc += 1
    return cc


def scan(root):
    found = {}
    for d in DIRS:
        for dirpath, _, files in os.walk(os.path.join(root, d)):
            for fn in sorted(files):
                if fn.endswith(".gd"):
                    path = os.path.join(dirpath, fn)
                    rel = os.path.relpath(path, root).replace("\\", "/")
                    for name, line, n, cc in functions(path):
                        if n > MAX_LINES or cc > MAX_CC:
                            found["%s::%s" % (rel, name)] = (n, cc, line)
    return found


def read_baseline(root):
    base = {}
    path = os.path.join(root, BASELINE)
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            for row in f:
                row = row.strip()
                if row and not row.startswith("#"):
                    key, n, cc = row.rsplit(" ", 2)
                    base[key] = (int(n), int(cc))
    return base


def main():
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else "."
    found = scan(root)
    base = read_baseline(root)
    if "--shrink" in sys.argv:
        header = (
            "# Functions over %d lines or complexity %d, as of the ratchet's start. May only shrink:\n"
            "# tools/lint/complexity_ratchet.py --shrink drops fixed rows and lowers numbers.\n"
            % (MAX_LINES, MAX_CC)
        )
        rows = ["%s %d %d" % (k, v[0], v[1]) for k, v in sorted(found.items()) if k in base]
        with open(os.path.join(root, BASELINE), "w", encoding="utf-8", newline="\n") as f:
            f.write(header + "\n".join(rows) + "\n")
        print("baseline shrunk to %d rows" % len(rows))
        return 0
    bad = 0
    for key, (n, cc, line) in sorted(found.items()):
        path = key.split("::")[0]
        if key not in base:
            print("%s:%d: [error] CR1 %s is new over the limit (%d lines, cc %d; limits %d and %d)"
                  % (path, line, key.split("::")[1], n, cc, MAX_LINES, MAX_CC))
            bad += 1
        elif n > base[key][0] or cc > base[key][1]:
            print("%s:%d: [error] CR2 %s grew (%d lines, cc %d; baseline %d and %d)"
                  % (path, line, key.split("::")[1], n, cc, base[key][0], base[key][1]))
            bad += 1
    for key in sorted(base):
        if key not in found:
            print("%s:0: [error] CR3 %s is within the limits or gone: remove its baseline row (--shrink)"
                  % (key.split("::")[0], key.split("::")[1]))
            bad += 1
    if bad:
        print("FAIL: %d complexity ratchet problem(s)" % bad)
        return 1
    print("ok: %d offenders, all in the baseline and none grown" % len(found))
    return 0


if __name__ == "__main__":
    sys.exit(main())
