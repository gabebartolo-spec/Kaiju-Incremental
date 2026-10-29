#!/usr/bin/env python3
"""Picks the suites a pull request's re-push runs (director 2026-10-30): the ones that failed or never ran last time,
plus every one whose code changed since. Main always runs everything (tools/ci_reuse_pr_run.sh never reuses a run
that ran a selection).

Run by the tests.yml plan job on a pull request, checkout at the merge commit (HEAD^1 the base, HEAD^2 the head),
with GH_TOKEN, GITHUB_REPOSITORY and GITHUB_RUN_ID set:

    python3 tools/ci_select_suites.py <pr number>

Prints two marker lines the next run reads back from this job's log, then the answer:
    CI-TESTED <base sha> <head sha>      what this run tests
    CI-PASSED <suite> ...                 suites passed earlier and untouched since (carried, not re-run)
    CI-SELECTION all | some              whether it runs every suite (main reuses only an "all" run)
and writes only=ALL | NONE | <suite> ... to $GITHUB_OUTPUT.

A suite counts as touched when a changed .gd/.tscn/.tres file is in its closure: the files its runner reaches by
res:// path or by class_name, the autoloads included. Any other changed file (data, assets, tools scripts, the
workflow, the timings) or any doubt (no earlier run, an API error, a commit that will not fetch) runs everything.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
LINE = re.compile(r"^(?:\S+\s)?(pass|PASS)\s+([a-z0-9_]+(?:@\d+/\d+)?)\s+\d+s\s", re.M)
MARK = re.compile(r"^(?:\S+\s)?(CI-TESTED|CI-PASSED)( .*)?$", re.M)
CODE = (".gd", ".tscn", ".tres")
# Suites that load every script by its path at run time, so any code change reaches them.
WHOLE_TREE = {"smoke"}


def sh(*args: str) -> str:
    out = subprocess.run(list(args), capture_output=True, text=True, cwd=ROOT)
    if out.returncode != 0:
        raise RuntimeError(f"{' '.join(args)[:120]}: {out.stderr.strip()[:300]}")
    return out.stdout


def api(path: str) -> str:
    return sh("gh", "api", f"repos/{os.environ['GITHUB_REPOSITORY']}/{path}")


def planned() -> list[str]:
    """Every suite (a split one as its parts) the PR shards would run, from the shard plan."""
    matrix = json.loads(sh("bash", "tools/plan_ci_shards.sh", "--matrix"))
    return sorted(s for row in matrix["include"] for s in row["suites"].split())


def last_run(pr: str) -> dict | None:
    """The newest finished or cancelled tests.yml run of this pull request before this one."""
    branch = json.loads(api(f"pulls/{pr}"))["head"]["ref"]
    runs = json.loads(api(f"actions/workflows/tests.yml/runs?event=pull_request&branch={branch}&per_page=20"))
    here = os.environ.get("GITHUB_RUN_ID", "")
    done = [r for r in runs["workflow_runs"] if str(r["id"]) != here and r["status"] == "completed"]
    return max(done, key=lambda r: r["created_at"]) if done else None


def earlier(run: dict) -> tuple[str, str, set[str]]:
    """What that run tested (base, head) and every suite it passed or carried."""
    jobs = json.loads(api(f"actions/runs/{run['id']}/jobs?per_page=60"))["jobs"]
    passed: set[str] = set()
    tested = ("", "")
    for job in jobs:
        if job["name"] != "plan" and not job["name"].startswith("shard "):
            continue
        if job["conclusion"] in (None, "skipped"):
            continue
        log = api(f"actions/jobs/{job['id']}/logs")
        if job["name"] == "plan":
            for kind, rest in MARK.findall(log):
                words = (rest or "").split()
                if kind == "CI-TESTED" and len(words) == 2:
                    tested = (words[0], words[1])
                elif kind == "CI-PASSED":
                    passed.update(words)
        else:
            passed.update(name for _, name in LINE.findall(log))
    return tested[0], tested[1], passed


def changed(a: str, b: str) -> list[str]:
    if a == b:
        return []
    sh("git", "fetch", "-q", "--depth=1", "origin", a)
    return [p for p in sh("git", "diff", "--name-only", a, b).split("\n") if p]


def closures(suites: set[str]) -> dict[str, set[str]]:
    """Each suite's files: its runner, the autoloads, and all they reach by res:// path or class_name."""
    files = [f for f in sh("git", "ls-files", *(f"*{e}" for e in CODE)).split("\n") if f]
    text = {f: open(os.path.join(ROOT, f), encoding="utf-8", errors="replace").read() for f in files}
    classes = {}
    for f, body in text.items():
        for name in re.findall(r"^class_name\s+(\w+)", body, re.M):
            classes[name] = f
    words = re.compile(r"\b(" + "|".join(sorted(classes, key=len, reverse=True)) + r")\b")
    refs = {}
    for f, body in text.items():
        out = {p for p in re.findall(r"res://([\w./-]+)", body) if p in text}
        out |= {classes[n] for n in words.findall(body)}
        refs[f] = out
    project = open(os.path.join(ROOT, "project.godot"), encoding="utf-8").read()
    autoloads = {p for p in re.findall(r"res://([\w./-]+)", project) if p in text}
    result = {}
    for suite in suites:
        seen: set[str] = set()
        todo = [f"tests/run_{suite}_tests.gd", *autoloads]
        while todo:
            f = todo.pop()
            if f in seen or f not in refs:
                continue
            seen.add(f)
            todo.extend(refs[f] - seen)
        result[suite] = seen
    return result


def select(pr: str) -> tuple[list[str], list[str]]:
    """(suites to run, suites carried as passed); every suite when in doubt."""
    everything = planned()
    run = last_run(pr)
    if run is None:
        return everything, []
    base0, head0, passed = earlier(run)
    if not base0:
        return everything, []
    paths = changed(base0, "HEAD^1") + changed(head0, "HEAD^2")
    paths = [p for p in paths if not p.startswith("docs/") and not p.endswith(".md")]
    if any(not p.endswith(CODE) or not os.path.exists(os.path.join(ROOT, p)) for p in paths):
        return everything, []
    names = {s.split("@")[0] for s in everything}
    reach = closures(names)
    touched = {s for s in names if (s in WHOLE_TREE and paths) or reach[s] & set(paths)}
    keep = [s for s in everything if s in passed and s.split("@")[0] not in touched]
    return [s for s in everything if s not in keep], keep


def main(argv: list[str]) -> int:
    pr = argv[0] if argv else ""
    head = sh("git", "rev-parse", "HEAD^1").strip(), sh("git", "rev-parse", "HEAD^2").strip()
    try:
        run, keep = select(pr) if pr else (planned(), [])
    except (RuntimeError, KeyError, ValueError) as err:
        print(f"Suite selection fell back to every suite: {err}")
        run, keep = planned(), []
    print(f"CI-TESTED {head[0]} {head[1]}")
    print("CI-PASSED " + " ".join(keep))
    only = "ALL" if not keep else (" ".join(run) or "NONE")
    print("CI-SELECTION " + ("all" if only == "ALL" else "some"))
    print(f"Running {len(run)} suites; {len(keep)} passed earlier and are untouched since: {' '.join(keep) or '-'}")
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write(f"only={only}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
