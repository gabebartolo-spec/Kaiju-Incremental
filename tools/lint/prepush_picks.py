#!/usr/bin/env python3
"""prepush_picks.py: which test suites a change can affect (used by tools/prepush.sh step 5).

Builds a reference graph over the project (res:// paths, class_name uses, autoload names, and
data/tuning.json top-level sections read as section("x") / ["x"]) and walks it from each
tests/run_<suite>_tests.gd runner, through the tests/lib helpers it loads and on into the sim/,
scenes/ and autoload/ code those use. A suite is picked when anything it can reach changed, or
its own runner changed. Conservative on purpose: a name match anywhere in code counts, so an
unsure case includes the suite (a missed suite is a red CI run, a spare one costs minutes).

Usage: prepush_picks.py [--root DIR] [--timings FILE] <changed file>...   (or names on stdin)
       BASE_REF=origin/main is used to read old data/tuning.json values and find changed sections.
Prints "suite<TAB>reason" per picked suite, then "# expected: N suites, ~S s" with --timings.
"""
import json
import os
import re
import subprocess
import sys
from collections import deque

CODE_DIRS = ["sim", "scenes", "autoload", "tests", "data"]
EXTS = (".gd", ".tscn", ".tres", ".json", ".gdshader")
RES = re.compile(r"res://([A-Za-z0-9_./\-]+)")
CLASS = re.compile(r"^\s*class_name\s+([A-Za-z_]\w*)", re.M)
# How many code files deep a suite is followed from its runner and tests/lib helpers: 1 = the
# code they name directly (what a runner loads is what it tests; deeper reach is a hub like
# Content or CityGen that nearly every suite touches, which would pick them all).
DEPTH = int(os.environ.get("PREPUSH_DEPTH", "1"))
IDENT = re.compile(r"[A-Za-z_]\w*")


def strip_comments(text):
    return re.sub(r"(?m)^\s*#.*$", "", text)


def load(root):
    files = {}
    for d in CODE_DIRS:
        for dp, _, fns in os.walk(os.path.join(root, d)):
            for fn in fns:
                if fn.endswith(EXTS):
                    p = os.path.relpath(os.path.join(dp, fn), root).replace("\\", "/")
                    with open(os.path.join(root, p), encoding="utf-8", errors="replace") as f:
                        files[p] = f.read()
    return files


def autoloads(root):
    out = {}
    path = os.path.join(root, "project.godot")
    if os.path.exists(path):
        text = open(path, encoding="utf-8").read()
        for m in re.finditer(r'^(\w+)="\*?res://([^"]+)"', text, re.M):
            out[m.group(1)] = m.group(2)
    return out


def changed_sections(root, base_ref, name):
    """Top-level keys of data/<name> whose value differs from base_ref (added ones too)."""
    try:
        old = json.loads(subprocess.check_output(
            ["git", "-C", root, "show", f"{base_ref}:data/{name}"], stderr=subprocess.DEVNULL))
        new_ref = os.environ.get("NEW_REF")
        if new_ref:
            new = json.loads(subprocess.check_output(
                ["git", "-C", root, "show", f"{new_ref}:data/{name}"], stderr=subprocess.DEVNULL))
        else:
            with open(os.path.join(root, "data", name), encoding="utf-8") as f:
                new = json.load(f)
    except Exception:
        return None
    if not isinstance(old, dict) or not isinstance(new, dict):
        return None
    return sorted(k for k in set(old) | set(new) if old.get(k) != new.get(k))


def build(root, files):
    classes = {}
    for p, t in files.items():
        if p.endswith(".gd"):
            m = CLASS.search(t)
            if m:
                classes[m.group(1)] = p
    classes.update(autoloads(root))
    edges = {}
    for p, t in files.items():
        code = strip_comments(t) if p.endswith(".gd") else t
        out = {m.group(1) for m in RES.finditer(code) if m.group(1) in files}
        if p.endswith(".gd"):
            for ident in set(IDENT.findall(code)):
                q = classes.get(ident)
                if q and q != p:
                    out.add(q)
        edges[p] = out
    return edges


def section_readers(files, section):
    pat = re.compile(r'(?:section\(|\[)\s*"%s"' % re.escape(section))
    return {p for p, t in files.items() if p.endswith(".gd") and pat.search(t)}


def accessors(text, stem):
    """Names of the static funcs in a loader file that reach a var named after the data file."""
    funcs = {}
    text = strip_comments(text)
    for m in re.finditer(r"(?ms)^(?:static )?func (\w+)\(.*?(?=^(?:static )?func |\Z)", text):
        funcs[m.group(1)] = m.group(0)
    seen = {n for n, b in funcs.items() if not n.startswith("_") and re.search(r"_?%s\w*" % re.escape(stem), b)}
    grew = True
    while grew:
        grew = False
        for n, b in funcs.items():
            if n not in seen and any(re.search(r"%s\(" % re.escape(a), b) for a in seen):
                seen.add(n)
                grew = True
    return seen


def data_hits(files, root, base_ref, c, hits):
    name = c[len("data/"):]
    secs = changed_sections(root, base_ref, name) if name == "tuning.json" else None
    if secs is not None:
        for s in secs:
            for p in section_readers(files, s):
                hits.setdefault(p, f'{c} section "{s}"')
        return
    stem = name[:-5]
    for p, t in list(files.items()):
        if not (p.endswith(".gd") and (name in t or ('"%s"' % stem) in t)):
            continue
        acc = accessors(t, stem)
        cls = CLASS.search(t)
        if not acc or not cls:
            hits.setdefault(p, c)
            continue
        # a loader other code calls through: the callers are what read the data
        pat = re.compile(r"%s\.(?:%s)" % (cls.group(1), "|".join(sorted(acc))))
        for q, u in files.items():
            if q != p and q.endswith(".gd") and pat.search(strip_comments(u)):
                hits.setdefault(q, f"{c} via {cls.group(1)}")


def main(argv):
    root, timings, changed = ".", None, []
    i = 0
    while i < len(argv):
        if argv[i] == "--root":
            root = argv[i + 1]
            i += 2
        elif argv[i] == "--timings":
            timings = argv[i + 1]
            i += 2
        else:
            changed.append(argv[i])
            i += 1
    if not changed:
        changed = [ln.strip() for ln in sys.stdin if ln.strip()]
    base_ref = os.environ.get("BASE_REF", "origin/main")
    files = load(root)
    edges = build(root, files)
    hits = {}
    for c in changed:
        c = c.replace("\\", "/")
        if c.endswith((".uid", ".import")):
            c = c[: c.rfind(".")]
        if c in files:
            hits[c] = c
        if c.startswith("data/") and c.endswith(".json"):
            data_hits(files, root, base_ref, c, hits)
    runners = sorted(p for p in files if re.fullmatch(r"tests/run_\w+_tests\.gd", p))
    picked = []
    for r in runners:
        suite = r[len("tests/run_"):-len("_tests.gd")]
        parent = {r: None}
        hops = {r: 0}  # code hops away from the test files; tests/ nodes are free
        q = deque([r])
        found = None
        while q:
            n = q.popleft()
            if n in hits:
                found = n
                break
            for m in sorted(edges.get(n, ())):
                step = 0 if (n.startswith("tests/") and m.startswith("tests/")) else 1
                h = hops[n] + step
                if m not in parent and h <= DEPTH:
                    parent[m] = n
                    hops[m] = h
                    q.append(m)
        if found is None:
            continue
        chain, n = [], found
        while n is not None:
            chain.append(n)
            n = parent[n]
        chain.reverse()
        why = " -> ".join(chain) if len(chain) <= 3 else f"{chain[0]} -> {chain[1]} -> ... -> {chain[-1]}"
        if hits[found] != found:
            why += f" [{hits[found]}]"
        picked.append((suite, why))
    for s, w in picked:
        print(f"{s}\t{w}")
    if timings and os.path.exists(timings):
        t = {}
        with open(timings) as f:
            for ln in f:
                parts = ln.split()
                if len(parts) >= 2 and parts[1].replace(".", "").isdigit():
                    # a suite CI runs in parts ("flow@1/2") costs the sum of its parts
                    base = parts[0].split("@")[0]
                    t[base] = t.get(base, 0) + float(parts[1])
        print(f"# expected: {len(picked)} suites, ~{int(sum(t.get(s, 60) for s, _ in picked))} s")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
