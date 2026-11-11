#!/usr/bin/env python3
"""cs_complexity_ratchet.py: no NEW C# file over 400 lines, method over 40 lines or cyclomatic complexity over 12.

The C# port of complexity_ratchet.py plus gdlint's max-file-lines (U6 C2), with the same limits (.gdlintrc,
docs/05). Scans hand-written C# under unity/Assets (Sim/Game is gd2cs output and excluded). Today's
offenders are listed in tools/lint/cs_complexity_baseline.txt, one `path::Method lines cc` row per method
and one `path::<file> lines 0` row per file; the file may only shrink:
  CR1  a file or method over a limit that is not in the baseline           (new offender)
  CR2  a baselined file or method that grew in lines or complexity
  CR3  a baselined file or method now within the limits, or gone: delete its row (or run --shrink)
`--shrink` rewrites the baseline keeping only the rows still over a limit, at their current numbers; it
never adds a row. A renamed or moved offender counts as new on purpose: split it, do not rename it.
Overloads in one file are keyed Name, Name~2, Name~3 in file order.

Counting (a brace scanner over code with comments and strings blanked; close enough to hold a line):
  file    its line count;
  lines   non-blank lines from the signature to the closing brace (local functions count in their host);
  cc      1 + each if/for/foreach/while/case/catch + each && / || / ?? + each ?: ternary (and `T?`).
A block-bodied property or indexer accessor is a member of its own, keyed Prop.get / Prop.set / Prop.init
(an indexer is `this`). Expression-bodied members (=>) are not scanned.

Usage: python3 tools/lint/cs_complexity_ratchet.py [--root DIR] [--shrink]
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cs_source  # noqa: E402

MAX_FILE_LINES = 400
MAX_LINES = 40
MAX_CC = 12
BASELINE = os.path.join("tools", "lint", "cs_complexity_baseline.txt")
FILE_KEY = "<file>"
MODIFIERS = (r"(?:(?:public|private|protected|internal|static|override|virtual|abstract|sealed|async|unsafe|new"
             r"|extern|partial|readonly)\s+)*")
# A return or property type: a plain or generic type, or a tuple type such as (int, int) or (int a, int b)?.
TYPE = r"(?:\([\w<>\[\],.? ]+\)[?\[\]]*|\w[\w<>\[\],.? ]*?)"
METHOD = re.compile(r"^\s*" + MODIFIERS + TYPE + r"\s+(\w+)\s*(?:<[^>]*>)?\s*\([^;]*$")
# A property or indexer head (no parameter list, no ;, no =); its accessors are keyed Name.get / Name.set.
PROPERTY = re.compile(r"^\s*" + MODIFIERS + TYPE + r"\s+(this\s*\[[^\]]*\]|\w+)\s*(?:\{[^;=]*)?$")
ACCESSOR = re.compile(r"^\s*(?:(?:public|private|protected|internal)\s+)*(get|set|init)\s*(?:\{|$)")
NOT_METHOD = {"if", "for", "foreach", "while", "switch", "using", "lock", "catch", "return", "new", "else", "when",
              "nameof", "typeof", "fixed"}
BRANCH = re.compile(r"\b(?:if|for|foreach|while|case|catch)\b|&&|\|\||\?\?|(?<![?.])\?(?![?.\[])")


def file_lines(text):
    return len(text.split("\n")) - (1 if text.endswith("\n") else 0)


def methods(code):
    """(name, first line, non-blank lines, cc) of each block-bodied method or accessor in stripped code."""
    lines = code.split("\n")
    out = []
    i = 0
    prop = "?"
    while i < len(lines):
        a = ACCESSOR.match(lines[i])
        p = PROPERTY.match(lines[i]) if not a and "(" not in lines[i].split("{")[0] else None
        if p:
            prop = "this" if p.group(1).startswith("this") else p.group(1)
        m = METHOD.match(lines[i])
        name = "%s.%s" % (prop, a.group(1)) if a else (m.group(1) if m else None)
        if not a and (not m or name in NOT_METHOD or "=" in lines[i].split("(")[0]):
            i += 1
            continue
        j = i
        while j < len(lines) and "{" not in lines[j] and ";" not in lines[j] and "=>" not in lines[j]:
            j += 1
        if j >= len(lines) or "{" not in lines[j] or "=>" in lines[j].split("{")[0]:
            i += 1
            continue
        depth, k, started = 0, j, False
        while k < len(lines):
            depth += lines[k].count("{") - lines[k].count("}")
            started = started or "{" in lines[k]
            if started and depth <= 0:
                break
            k += 1
        body = lines[i:k + 1]
        n = len([b for b in body if b.strip()])
        cc = 1 + sum(len(BRANCH.findall(b)) for b in body)
        out.append((name, i + 1, n, cc))
        i = k + 1
    return out


def scan(root):
    """{key: (lines, cc, line)} for every file and method over a limit."""
    found = {}
    for path in cs_source.hand_written(root):
        text = cs_source.read(root, path)
        n = file_lines(text)
        if n > MAX_FILE_LINES:
            found["%s::%s" % (path, FILE_KEY)] = (n, 0, 1)
        seen = {}
        for name, line, n, cc in methods(cs_source.strip(text)):
            seen[name] = seen.get(name, 0) + 1
            key = "%s::%s" % (path, name if seen[name] == 1 else "%s~%d" % (name, seen[name]))
            if n > MAX_LINES or cc > MAX_CC:
                found[key] = (n, cc, line)
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


def write_baseline(root, rows):
    header = (
        "# C# files over %d lines (`path::%s lines 0`) and methods over %d lines or complexity %d\n"
        "# (`path::Method lines cc`), as of the ratchet's start. May only shrink:\n"
        "# tools/lint/cs_complexity_ratchet.py --shrink drops fixed rows and lowers numbers.\n"
        % (MAX_FILE_LINES, FILE_KEY, MAX_LINES, MAX_CC)
    )
    with open(os.path.join(root, BASELINE), "w", encoding="utf-8", newline="\n") as f:
        f.write(header + "".join("%s %d %d\n" % (k, v[0], v[1]) for k, v in sorted(rows.items())))


def limits(key):
    if key.endswith("::" + FILE_KEY):
        return "limit %d lines" % MAX_FILE_LINES
    return "limits %d lines and cc %d" % (MAX_LINES, MAX_CC)


def main():
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else "."
    found = scan(root)
    base = read_baseline(root)
    if "--shrink" in sys.argv:
        rows = {k: v[:2] for k, v in found.items() if k in base}
        write_baseline(root, rows)
        print("baseline shrunk to %d rows" % len(rows))
        return 0
    if "--write-baseline" in sys.argv:  # one-off, when the ratchet starts; never to admit a new offender
        write_baseline(root, {k: v[:2] for k, v in found.items()})
        print("baseline written: %d rows" % len(found))
        return 0
    bad = 0
    for key, (n, cc, line) in sorted(found.items()):
        path, name = key.split("::")
        if key not in base:
            cs_source.emit(path, line, "CR1", "%s is new over the limit (%d lines, cc %d; %s)" % (name, n, cc, limits(key)))
            bad += 1
        elif n > base[key][0] or cc > base[key][1]:
            cs_source.emit(path, line, "CR2", "%s grew (%d lines, cc %d; baseline %d and %d)"
                           % (name, n, cc, base[key][0], base[key][1]))
            bad += 1
    for key in sorted(base):
        if key not in found:
            path, name = key.split("::")
            cs_source.emit(path, 0, "CR3", "%s is within the limits or gone: remove its baseline row (--shrink)" % name)
            bad += 1
    if bad:
        print("FAIL: %d C# complexity ratchet problem(s)" % bad)
        return 1
    print("ok: %d C# offenders, all in the baseline and none grown" % len(found))
    return 0


if __name__ == "__main__":
    sys.exit(main())
