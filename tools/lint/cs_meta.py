#!/usr/bin/env python3
"""cs_meta.py: every Unity asset and folder in git has its .meta in git too (U6 C3; check_uids.sh for Unity).

Unity writes <file>.meta (and <folder>.meta) holding the asset's GUID; scenes and prefabs point at scripts
and assets by that GUID. A file committed without its .meta gets a fresh GUID on every PC and the
references break; a .meta left behind by a deleted file is noise that comes back as a merge conflict.
Reads the git index under unity/Assets (and each tracked .meta's working-tree copy for its guid):
  META-MISSING    a tracked file, or a folder holding tracked files (a .meta counts), with no tracked .meta
  META-ORPHAN     a tracked .meta whose file is not tracked and whose folder holds no tracked file
  META-DUP-GUID   one guid in two .meta files
ALLOWED_ORPHANS lists .meta files kept on purpose for a file git ignores (built on each PC).

Usage: python3 tools/lint/cs_meta.py [--root DIR]
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import cs_source  # noqa: E402

## kaiju_core.dll is built per PC by unity/native/build.bat and gitignored; its import settings stay tracked.
ALLOWED_ORPHANS = {"unity/Assets/Plugins/x86_64/kaiju_core.dll.meta"}
GUID = re.compile(r"^guid:\s*([0-9a-fA-F]+)", re.M)


def tracked(root):
    done = subprocess.run(["git", "-C", root, "ls-files", "-z", "--", cs_source.ASSETS],
                          capture_output=True, text=True, encoding="utf-8", check=True)
    return [p for p in done.stdout.split("\0") if p]


def check(root):
    """Findings as (path, rule, message), and the number of assets and folders checked."""
    files = tracked(root)
    have = set(files)
    assets = [p for p in files if not p.endswith(".meta")]
    folders = set()
    for p in files:
        d = os.path.dirname(p)
        while d.startswith(cs_source.ASSETS + "/"):
            folders.add(d)
            d = os.path.dirname(d)
    found = []
    for p in sorted(assets) + sorted(folders):
        if p + ".meta" not in have:
            found.append((p, "META-MISSING", "has no tracked %s.meta: open the project in Unity once and commit it" % p))
    for p in sorted(files):
        if p.endswith(".meta") and p not in ALLOWED_ORPHANS:
            src = p[:-len(".meta")]
            if src not in have and src not in folders:
                found.append((p, "META-ORPHAN", "%s is not tracked (nor a folder holding tracked files): delete the .meta"
                              % src))
    owner = {}
    for p in sorted(files):
        if p.endswith(".meta") and os.path.isfile(os.path.join(root, p)):
            with open(os.path.join(root, p), encoding="utf-8", errors="replace") as f:
                m = GUID.search(f.read())
            if m:
                g = m.group(1).lower()
                if g in owner:
                    found.append((p, "META-DUP-GUID", "shares guid %s with %s: delete one .meta and reimport" % (g, owner[g])))
                else:
                    owner[g] = p
    return found, len(assets) + len(folders)


def main():
    root = sys.argv[sys.argv.index("--root") + 1] if "--root" in sys.argv else "."
    found, checked = check(root)
    for path, rule, message in found:
        cs_source.emit(path, 0, rule, message)
    if found:
        print("FAIL: %d .meta problem(s)" % len(found))
        return 1
    print("ok: %d tracked assets and folders under %s, each with one tracked .meta and a unique guid"
          % (checked, cs_source.ASSETS))
    return 0


if __name__ == "__main__":
    sys.exit(main())
