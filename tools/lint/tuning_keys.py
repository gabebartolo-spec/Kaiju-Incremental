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

Usage: python3 tools/lint/tuning_keys.py [--root DIR]
"""
import json
import os
import re
import sys

NAMES = r"(?:_?tuning|_?cfg|_?config|_?conf)"
# a name, then any run of ["k"] / .get("k"
READ = re.compile(r"\b(" + NAMES + r")((?:\[\"[^\"]+\"\]|\.get\(\"[^\"]+\"[^)]*\))+)")
KEY = re.compile(r"\[\"([^\"]+)\"\]|\.get\(\"([^\"]+)\"")
SECTION = re.compile(r"Content\.section\(\"([^\"]+)\"\)((?:\[\"[^\"]+\"\]|\.get\(\"[^\"]+\"[^)]*\))*)")
TUNING_CALL = re.compile(r"Content\.tuning\(\)((?:\[\"[^\"]+\"\]|\.get\(\"[^\"]+\"[^)]*\))+)")
WRITE = re.compile(r"\[\"([^\"]+)\"\]\s*=[^=]")
DIRS = ["sim", "scenes", "autoload", "tools"]


def gd_files(root):
    for d in DIRS:
        for dirpath, _, files in os.walk(os.path.join(root, d)):
            for fn in files:
                if fn.endswith(".gd"):
                    yield os.path.join(dirpath, fn)


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
    for path in gd_files(root):
        with open(path, encoding="utf-8") as f:
            for line in f:
                written.update(WRITE.findall(line.split("#", 1)[0]))
    known = tuning_keys | other_keys | written
    misses = []
    reads = 0
    for path in gd_files(root):
        with open(path, encoding="utf-8") as f:
            for n, line in enumerate(f, 1):
                code = line.split("#", 1)[0]
                for m in SECTION.finditer(code):
                    reads += 1
                    if m.group(1) not in tuning:
                        misses.append((path, n, m.group(1), "Content.section"))
                    for k in KEY.finditer(m.group(2)):
                        key = k.group(1) or k.group(2)
                        if key not in known:
                            misses.append((path, n, key, "section read"))
                chains = [m.group(2) for m in READ.finditer(code)]
                chains += [m.group(1) for m in TUNING_CALL.finditer(code)]
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
