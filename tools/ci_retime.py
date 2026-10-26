#!/usr/bin/env python3
"""Re-measures tools/ci_timings.txt from real CI runs (the shard plan is only as good as these numbers).

The sequential and lane times a suite takes on a GitHub runner are in the shard logs of past tests.yml runs
("pass  sim  166s  ..."). This reads the last N successful runs (default 6) of tests.yml on main and on
pull requests, averages each suite's seconds, and rewrites the suite lines of tools/ci_timings.txt; the
"shards", "lanes", "split" and "pr_skip" lines and the comment header are kept (the header's run ids are updated).
Needs the gh CLI, logged in. Run at least weekly and after adding a slow suite (debt row 4, D-295):

    python tools/ci_retime.py            # last 6 successful runs
    python tools/ci_retime.py 10         # last 10
    python tools/ci_retime.py 40355996670 40347766476   # these runs

Then look at `bash tools/plan_ci_shards.sh`: raise "shards" when the heaviest shard passes about 8 minutes.
"""
import datetime
import json
import os
import re
import subprocess
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
TIMINGS = os.path.join(ROOT, "tools", "ci_timings.txt")
LINE = re.compile(r"(?:pass|PASS|FAIL)\s+([a-z0-9_]+(?:@\d+/\d+)?)\s+(\d+)s\s")


def gh(*args: str) -> str:
    out = subprocess.run(["gh", *args], capture_output=True, text=True, cwd=ROOT)
    if out.returncode != 0:
        raise SystemExit(f"gh {' '.join(args)} failed: {out.stderr.strip()[:300]}")
    return out.stdout


def run_ids(argv: list[str]) -> list[str]:
    if argv and all(a.isdigit() and len(a) > 6 for a in argv):
        return argv
    n = int(argv[0]) if argv else 6
    listing = json.loads(
        gh("run", "list", "--workflow=tests.yml", "--status=success", "--limit", str(n * 3), "--json", "databaseId,event")
    )
    # only runs that ran the shards (a docs-only or reused run finishes in under a minute)
    return [str(r["databaseId"]) for r in listing][: n * 3]


def shard_logs(run: str) -> list[str]:
    repo = json.loads(gh("repo", "view", "--json", "nameWithOwner"))["nameWithOwner"]
    jobs = json.loads(gh("api", f"repos/{repo}/actions/runs/{run}/jobs?per_page=60"))["jobs"]
    logs = []
    for job in jobs:
        if job["name"].startswith("shard ") and job["conclusion"] == "success":
            logs.append(gh("run", "view", run, "--log", "--job", str(job["id"])))
    return logs


def main(argv: list[str]) -> int:
    want = int(argv[0]) if argv and not (argv[0].isdigit() and len(argv[0]) > 6) else 6
    secs: dict[str, list[int]] = {}
    used: list[str] = []
    for run in run_ids(argv):
        logs = shard_logs(run)
        if not logs:
            continue
        used.append(run)
        for log in logs:
            for m in LINE.finditer(log):
                secs.setdefault(m.group(1), []).append(int(m.group(2)))
        if len(used) >= want:
            break
    if not used:
        raise SystemExit("no successful run with shard logs found")
    keep = []
    if os.path.exists(TIMINGS):
        with open(TIMINGS, encoding="utf-8") as f:
            keep = [ln.rstrip("\n") for ln in f if re.match(r"(shards|lanes|split|pr_skip)\s", ln)]
    # only suites that still have a runner
    have = {n[len("run_") : -len("_tests.gd")] for n in os.listdir(os.path.join(ROOT, "tests")) if re.match(r"run_.*_tests\.gd$", n)}
    rows = sorted(((s, round(sum(v) / len(v))) for s, v in secs.items() if s.split("@")[0] in have), key=lambda r: (-r[1], r[0]))
    head = [
        f"# Seconds per suite on a CI runner (mean of {len(used)} runs: {', '.join(used)}), {datetime.date.today()}.",
        "# Nobody edits this per PR: a new suite counts as DEFAULT_SECS until the next re-measure (python tools/ci_retime.py, at least weekly).",
        "# tools/plan_ci_shards.sh packs the suites into shards x lanes bins; each shard runs its lanes at once (tools/run_tests.sh LANES).",
    ]
    with open(TIMINGS, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(head + keep + [f"{s} {t}" for s, t in rows]) + "\n")
    missing = sorted(have - {s.split("@")[0] for s, _ in rows})
    print(f"wrote {len(rows)} suites from runs {', '.join(used)}; total {sum(t for _, t in rows)} s")
    if missing:
        print("no timing for: " + ", ".join(missing) + " (count as the default until a run includes them)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
