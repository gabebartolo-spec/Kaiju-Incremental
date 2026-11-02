"""triage.py: what a red CI run broke, in one short report, and whether main breaks the same way.

    python tools/triage.py                 the latest failed tests.yml run of this branch
    python tools/triage.py 41451649821     that run
    python tools/triage.py --pr 538        the latest failed run of that PR's branch
    python tools/triage.py --rerun         ... then run the failing suites here (tools/run_tests.sh)

For each failing suite: its summary line, each distinct failed check (with a count when it
repeats) and each distinct script error. Then the same suites on main's latest finished tests.yml
run: "also red on main" means the PR did not cause it. Other failed jobs (lint, build) are listed
by job and step. Needs gh. Reads only; --rerun starts headless suites only.
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import Counter, OrderedDict

# tools/run_tests.sh lines, after the Actions prefix ("<job>\t<step>\t<timestamp> ").
SUITE_LINE = re.compile(r"^(pass|FAIL)\s+(\S+)\s+(\d+)s\s+(.*)$")
GROUP_LINE = re.compile(r"^##\[group\](\S+) log \(failures and errors\)")
PREFIX = re.compile(r"^[^\t]*\t[^\t]*\t\S+Z ?")
MAX_LINES = 8  # distinct failures / errors shown per suite


def gh(*args: str) -> str:
    out = subprocess.run(["gh", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if out.returncode != 0:
        sys.exit(f"gh {' '.join(args)} failed: {out.stderr.strip()}")
    return out.stdout


def current_branch() -> str:
    return subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"], capture_output=True, text=True
    ).stdout.strip()


def latest_run(branch: str, status: str) -> dict | None:
    runs = json.loads(
        gh("run", "list", "--workflow", "tests.yml", "--branch", branch, "--status", status, "-L", "1",
           "--json", "databaseId,headSha,displayTitle,createdAt")
    )
    return runs[0] if runs else None


def parse(log: str) -> dict[str, dict]:
    """suite -> {status, secs, summary, fails: Counter, errors: Counter}"""
    suites: dict[str, dict] = OrderedDict()
    group = None
    for raw in log.splitlines():
        line = PREFIX.sub("", raw).rstrip()
        m = SUITE_LINE.match(line)
        if m:
            status, name, secs, summary = m.groups()
            suites.setdefault(name, {"fails": Counter(), "errors": Counter()})
            suites[name].update(status=status, secs=int(secs), summary=summary)
            group = None
            continue
        g = GROUP_LINE.match(line)
        if g:
            group = g.group(1)
            suites.setdefault(group, {"fails": Counter(), "errors": Counter(), "status": "FAIL"})
            continue
        if line.startswith("##[endgroup]"):
            group = None
        elif group and line.startswith("FAIL:"):
            suites[group]["fails"][line[5:].strip()] += 1
        elif group and line.startswith("SCRIPT ERROR:"):
            suites[group]["errors"][line[13:].strip()] += 1
    return suites


def failed_jobs(run_id: str) -> list[str]:
    data = json.loads(gh("run", "view", run_id, "--json", "jobs"))
    out = []
    for job in data["jobs"]:
        if job.get("conclusion") == "failure":
            steps = [s["name"] for s in job.get("steps", []) if s.get("conclusion") == "failure"]
            out.append(f"{job['name']}: {', '.join(steps) or '(no step named)'}")
    return out


def show(counter: Counter, label: str) -> None:
    for i, (text, n) in enumerate(counter.most_common()):
        if i == MAX_LINES:
            print(f"    ... {len(counter) - MAX_LINES} more distinct {label}")
            break
        print(f"    {label[:-1] if label.endswith('s') else label}: {text}" + (f"  (x{n})" if n > 1 else ""))


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("run", nargs="?", help="Actions run id (default: latest failed run of this branch)")
    ap.add_argument("--pr", help="a PR number: its branch's latest failed run")
    ap.add_argument("--rerun", action="store_true", help="run the failing suites locally afterwards")
    a = ap.parse_args()

    run_id = a.run
    if not run_id:
        branch = (
            json.loads(gh("pr", "view", a.pr, "--json", "headRefName"))["headRefName"] if a.pr else current_branch()
        )
        run = latest_run(branch, "failure")
        if not run:
            print(f"no failed tests.yml run on {branch}")
            return 0
        run_id = str(run["databaseId"])
        print(f"run {run_id} on {branch} ({run['headSha'][:9]}, {run['createdAt']}): {run['displayTitle']}")

    suites = parse(gh("run", "view", run_id, "--log-failed"))
    red = [n for n, s in suites.items() if s.get("status") == "FAIL"]
    jobs = failed_jobs(run_id)

    main_red: set[str] = set()
    main_run = latest_run("main", "completed")
    if main_run and red:
        main_suites = parse(gh("run", "view", str(main_run["databaseId"]), "--log-failed"))
        main_red = {n for n, s in main_suites.items() if s.get("status") == "FAIL"}

    if not red:
        print("no failing suite found in the log")
    for name in red:
        s = suites[name]
        tag = "also red on main" if name in main_red else "NEW (green or absent on main)"
        print(f"\nFAIL {name} ({s.get('secs', '?')} s), {tag}\n    {s.get('summary', '')}")
        show(s["fails"], "fails")
        show(s["errors"], "errors")
    if main_run and red:
        print(f"\n(main compared: run {main_run['databaseId']}, {main_run['headSha'][:9]})")
    if jobs:
        print("\nfailed jobs: " + "; ".join(jobs))

    if a.rerun and red:
        cmd = ["bash", "tools/run_tests.sh", "--quick", *red]
        print("\n$ " + " ".join(cmd), flush=True)
        return subprocess.run(cmd).returncode
    return 1 if red else 0


if __name__ == "__main__":
    sys.exit(main())
