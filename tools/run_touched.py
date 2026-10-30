#!/usr/bin/env python3
"""Runs, locally, only the test suites a change touches (D-403, which relaxes D-383): before a push, not instead of CI.

By default the nearest suites run: from each changed file, back along the references, the first suites reached
(nearest()). With --all, a suite runs when a changed .gd/.tscn/.tres file is in its closure: the files its runner reaches by res:// path
or by class_name, read from code only (comments and plain strings do not count, so a class named in a doc line does
not pull the whole tree in). A changed data or asset file counts as the code files that name it by res:// path; a
file no code names (tools, workflows) runs nothing here and is reported. The slow pr_skip suites never run here
(D-382: main runs them). Engine suites (the "engine" line in
tools/ci_timings.txt: scene, camera and capture) run only when touched and --engine is given; windowed or not, they
start Godot, so they follow the machine rules in CLAUDE.md.

    python tools/run_touched.py                 # vs origin/main, sim suites only
    python tools/run_touched.py --list          # print the suites, run nothing
    python tools/run_touched.py --all           # every suite whose closure holds a changed file (a core sim file reaches most)
    python tools/run_touched.py --engine        # touched engine suites too
    python tools/run_touched.py --base <ref>    # vs another base
"""
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
CODE = (".gd", ".tscn", ".tres")
STRING = re.compile(r'"(?:[^"\\]|\\.)*"')
RUNNER = re.compile(r"^tests/run_(\w+)_tests\.gd$")


def git(*args: str) -> str:
    return subprocess.run(["git", *args], capture_output=True, text=True, cwd=ROOT, check=True).stdout


def read(path: str) -> str:
    with open(os.path.join(ROOT, path), encoding="utf-8", errors="replace") as fh:
        return fh.read()


def code_only(body: str) -> str:
    """The text with comments and non-res:// strings blanked, so only real references remain."""
    out = []
    for line in body.split("\n"):
        line = STRING.sub(lambda m: m.group(0) if "res://" in m.group(0) else '""', line)
        out.append(line.split("#", 1)[0])
    return "\n".join(out)


def timings_line(key: str) -> set[str]:
    with open(os.path.join(ROOT, "tools/ci_timings.txt"), encoding="utf-8") as fh:
        return {w for line in fh if line.split()[:1] == [key] for w in line.split()[1:]}


def graph() -> dict[str, set[str]]:
    files = [f for f in git("ls-files", *(f"*{e}" for e in CODE)).split("\n") if f]
    text = {f: code_only(read(f)) for f in files}
    classes = {n: f for f, b in text.items() for n in re.findall(r"^class_name\s+(\w+)", b, re.MULTILINE)}
    words = re.compile(r"\b(" + "|".join(sorted(classes, key=len, reverse=True)) + r")\b")
    refs = {
        f: ({p for p in re.findall(r"res://([\w./-]+)", b) if p in text} | {classes[n] for n in words.findall(b)}) - {f}
        for f, b in text.items()
    }
    return refs


def closures(refs: dict[str, set[str]]) -> dict[str, set[str]]:
    result = {}
    for f in refs:
        m = RUNNER.match(f)
        if not m:
            continue
        seen: set[str] = set()
        todo = [f]
        while todo:
            x = todo.pop()
            if x not in seen:
                seen.add(x)
                todo.extend(refs.get(x, set()) - seen)
        result[m.group(1)] = seen
    return result


def changed(base: str) -> list[str]:
    merge_base = git("merge-base", base, "HEAD").strip()
    paths = set(git("diff", "--name-only", merge_base).split())
    return sorted(p for p in paths if not p.startswith("docs/") and not p.endswith(".md"))


def nearest(refs: dict[str, set[str]], paths: set[str]) -> set[str]:
    """The suites closest to the change: walk back from the changed files one reference at a time and stop at the
    first step that reaches any suite runner (a leaf file finds its own suite; a core sim file finds the few suites
    that check it most directly, not the ~80 that reach it somewhere)."""
    users: dict[str, set[str]] = {}
    for f, out in refs.items():
        for g in out:
            users.setdefault(g, set()).add(f)
    seen, layer = set(paths), set(paths)
    while layer:
        # A hop from a test helper to the test that uses it is free: tests/lib is part of the suite, not distance.
        grow = {u for f in layer if f.startswith("tests/") for u in users.get(f, ()) if u.startswith("tests/")} - seen
        while grow:
            layer |= grow
            seen |= grow
            grow = {u for f in grow for u in users.get(f, ()) if u.startswith("tests/")} - seen
        hits = {m.group(1) for f in layer if (m := RUNNER.match(f))}
        if hits:
            return hits
        layer = {u for f in layer for u in users.get(f, ())} - seen
        seen |= layer
    return set()


def seeds(refs: dict[str, set[str]], paths: list[str]) -> tuple[set[str], list[str]]:
    """The code files to walk back from: a changed code file itself; for any other file (data, assets), the code
    files that name it by res:// path. Returns them and the changed files no code names (CI covers those)."""
    code = {p for p in paths if p in refs}
    lost = []
    for p in paths:
        if p in refs:
            continue
        users = {f for f in refs if f"res://{p}" in read(f)}
        if users:
            code |= users
        else:
            lost.append(p)
    return code, lost


def pick(paths: list[str], engine: bool, everything: bool) -> tuple[list[str], list[str]]:
    refs = graph()
    code, lost = seeds(refs, paths)
    if everything:
        reach = closures(refs)
        touched = {s for s, files in reach.items() if files & code}
    else:
        touched = nearest(refs, code)
    skip = timings_line("pr_skip") | (set() if engine else timings_line("engine"))
    return sorted(s for s in touched if s not in skip), lost


def main(argv: list[str]) -> int:
    base = argv[argv.index("--base") + 1] if "--base" in argv else "origin/main"
    paths = changed(base)
    if not paths:
        print("No code change against " + base + ": nothing to run.")
        return 0
    suites, lost = pick(paths, "--engine" in argv, "--all" in argv)
    print(f"{len(paths)} changed files; {len(suites)} suites: {' '.join(suites) or '-'}")
    if lost:
        print(f"No suite reads {len(lost)} of them (CI covers these): {' '.join(lost[:8])}{' ...' if len(lost) > 8 else ''}")
    if "--list" in argv or not suites:
        return 0
    return subprocess.run(["bash", "tools/run_tests.sh", *suites], cwd=ROOT, env={**os.environ, "SUITES_ONLY": "1"}, check=False).returncode


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
