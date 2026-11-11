#!/usr/bin/env python3
"""tuning_keys.py: every string key the code reads from tuning data exists in data/tuning.json.

A misspelt key fails only at runtime, in whatever run reaches it (audit 2026-10-21 #5). This reads
sim/, scenes/, autoload/ and tools/ and checks, by name, the reads on variables that hold tuning
(tuning, cfg, config and their _prefixed forms, Content.tuning()) and Content.section("x"):
  - Content.section("x")            x is a top-level key of data/tuning.json;
  - tuning["a"]["b"] / cfg["a"] / cfg.get("a", ...) / Num.f(cfg["a"])   each key is a key somewhere in
    data/tuning.json (any depth; a key a sub-table is also a key there counts).
A key can also be written in data/*.json other than tuning.json (a cfg that holds a species or
upgrade row), or be added by code (x["k"] = ..., as Content merges landmark_shapes in); those count. Anything else is listed with file:line. Exit 1 on any miss.
The Unity port's hand-written C# (unity/Assets/Scripts minus Sim/Game, the gd2cs output) is read the
same way (U6 C6): Content.Section("x") / Content.Tuning(), // comments, and also *Cfg names (cityCfg).

Usage: python3 tools/lint/tuning_keys.py [--root DIR]
"""
import json
import os
import re
import sys

NAMES = r"(?:_?tuning|_?cfg|_?config|_?conf)"
CS_NAMES = NAMES[:-1] + r"|[a-z]\w*Cfg)"
CHAIN = r"((?:\[\"[^\"]+\"\]|\.get\(\"[^\"]+\"[^)]*\))+)"
KEY = re.compile(r"\[\"([^\"]+)\"\]|\.get\(\"([^\"]+)\"")
WRITE = re.compile(r"\[\"([^\"]+)\"\]\s*=[^=]")
DIRS = ["sim", "scenes", "autoload", "tools"]
CS_DIR = os.path.join("unity", "Assets", "Scripts")
CS_GENERATED = os.path.join(CS_DIR, "Sim", "Game")


class Lang:
    """How one language spells a comment, a section read, a whole-tuning read and a tuning variable."""

    def __init__(self, comment, section, tuning, names):
        self.comment = comment
        # a name, then any run of ["k"] / .get("k"
        self.read = re.compile(r"\b(" + names + r")" + CHAIN)
        self.section = re.compile(r"Content\." + section + r"\(\"([^\"]+)\"\)" + CHAIN[:-2] + "*)")
        self.tuning_call = re.compile(r"Content\." + tuning + r"\(\)" + CHAIN)


GD = Lang("#", "section", "tuning", NAMES)
CS = Lang("//", "Section", "Tuning", CS_NAMES)


def source_files(root):
    """(path, Lang) of every file read: GDScript under DIRS, hand-written C# under CS_DIR."""
    for d in DIRS:
        for dirpath, _, files in os.walk(os.path.join(root, d)):
            for fn in files:
                if fn.endswith(".gd"):
                    yield os.path.join(dirpath, fn), GD
    generated = os.path.join(root, CS_GENERATED)
    for dirpath, _, files in os.walk(os.path.join(root, CS_DIR)):
        if os.path.commonpath([dirpath, generated]) == generated:
            continue
        for fn in files:
            if fn.endswith(".cs"):
                yield os.path.join(dirpath, fn), CS


def all_keys(node, out):
    if isinstance(node, dict):
        for k, v in node.items():
            out.add(k)
            all_keys(v, out)
    elif isinstance(node, list):
        for v in node:
            all_keys(v, out)


def main():
    root = "."
    if "--root" in sys.argv:
        root = sys.argv[sys.argv.index("--root") + 1]
    with open(os.path.join(root, "data", "tuning.json"), encoding="utf-8") as f:
        tuning = json.load(f)
    tuning_keys = set()
    all_keys(tuning, tuning_keys)
    other_keys = set()
    for name in os.listdir(os.path.join(root, "data")):
        if name.endswith(".json") and name != "tuning.json":
            with open(os.path.join(root, "data", name), encoding="utf-8") as f:
                all_keys(json.load(f), other_keys)
    written = set()
    for path, lang in source_files(root):
        with open(path, encoding="utf-8-sig") as f:
            for line in f:
                written.update(WRITE.findall(line.split(lang.comment, 1)[0]))
    known = tuning_keys | other_keys | written
    misses = []
    reads = 0
    for path, lang in source_files(root):
        with open(path, encoding="utf-8-sig") as f:
            for n, line in enumerate(f, 1):
                code = line.split(lang.comment, 1)[0]
                for m in lang.section.finditer(code):
                    reads += 1
                    if m.group(1) not in tuning:
                        misses.append((path, n, m.group(1), "Content.section"))
                    for k in KEY.finditer(m.group(2)):
                        key = k.group(1) or k.group(2)
                        if key not in known:
                            misses.append((path, n, key, "section read"))
                chains = [m.group(2) for m in lang.read.finditer(code)]
                chains += [m.group(1) for m in lang.tuning_call.finditer(code)]
                for chain in chains:
                    for k in KEY.finditer(chain):
                        reads += 1
                        key = k.group(1) or k.group(2)
                        if key not in known:
                            misses.append((path, n, key, "tuning read"))
    for path, n, key, what in misses:
        print("%s:%d: [error] TK1 %s of \"%s\" is not a key in data/*.json" % (path.replace("\\", "/"), n, what, key))
    if misses:
        print("FAIL: %d tuning key read(s) without a key in the data (of %d checked)" % (len(misses), reads))
        return 1
    print("ok: %d tuning key reads, every key is in the data" % reads)
    return 0


if __name__ == "__main__":
    sys.exit(main())
