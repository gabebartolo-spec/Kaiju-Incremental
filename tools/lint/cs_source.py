"""cs_source.py: shared reading of the Unity port's hand-written C# for the cs_* lints (U6).

Hand-written = every .cs under unity/Assets except unity/Assets/Scripts/Sim/Game/ (gd2cs output: the
translator owns it, and its `--check` keeps it byte-identical to the GDScript sim). Not a lint itself.
"""
import os
import re

ASSETS = "unity/Assets"
GENERATED = "unity/Assets/Scripts/Sim/Game/"


def rel(root, path):
    return os.path.relpath(path, root).replace("\\", "/")


def hand_written(root):
    """Repo-relative paths of the hand-written C# files under unity/Assets, sorted."""
    out = []
    for dirpath, _, files in os.walk(os.path.join(root, ASSETS)):
        for fn in files:
            if fn.endswith(".cs"):
                path = rel(root, os.path.join(dirpath, fn))
                if not path.startswith(GENERATED):
                    out.append(path)
    return sorted(out)


def read(root, path):
    with open(os.path.join(root, path), encoding="utf-8-sig") as f:
        return f.read().replace("\r\n", "\n")


def _string_end(src, i, verbatim):
    """Index just past the string literal whose opening quote is at i."""
    n = len(src)
    i += 1
    while i < n:
        if not verbatim and src[i] == "\\":
            i += 2
            continue
        if src[i] == '"':
            if verbatim and i + 1 < n and src[i + 1] == '"':
                i += 2
                continue
            return i + 1
        if not verbatim and src[i] == "\n":
            return i  # an unterminated regular string ends at the line (keeps the scan line-true)
        i += 1
    return n


def strip(src):
    """The code of a C# source: comments and string/char literals blanked, line structure kept.

    A string becomes "" (plus its newlines), so text such as "if a && b" or a number in a string is not
    code; interpolation holes are blanked with the string (a scanner, not a parser).
    """
    out = []
    i, n = 0, len(src)
    while i < n:
        if src.startswith("//", i):
            j = src.find("\n", i)
            i = n if j < 0 else j
            continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", src[i:j]))
            i = j
            continue
        m = re.match(r'(\$@|@\$|\$|@)?"', src[i:i + 3])
        if m:
            verbatim = "@" in (m.group(1) or "")
            j = _string_end(src, i + len(m.group(0)) - 1, verbatim)
            out.append('""' + "\n" * src[i:j].count("\n"))
            i = j
            continue
        if src[i] == "'":
            j = i + 1
            j += 2 if j < n and src[j] == "\\" else 1
            while j < n and src[j] not in "'\n" and j - i < 10:  # 'A'
                j += 1
            if j < n and src[j] == "'":
                out.append("' '")
                i = j + 1
                continue
        out.append(src[i])
        i += 1
    return "".join(out)


def emit(path, line, rule, message):
    """Prints one finding as file:line: [error] RULE message (and a GitHub annotation under Actions)."""
    print("%s:%d: [error] %s %s" % (path, line, rule, message))
    if os.environ.get("GITHUB_ACTIONS"):
        print("::error file=%s,line=%d::%s %s" % (path, line, rule, message))
