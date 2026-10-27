#!/usr/bin/env python3
"""Every GitHub Actions job names a timeout-minutes (debt row 4, 2026-10-27).

A job with no timeout runs up to GitHub's six hours when a step hangs, holding a runner and
the PR's required check. This reads .github/workflows/*.yml as text (no YAML library) and
lists each job whose block has no `timeout-minutes:` line.

    python tools/lint/workflow_timeouts.py             # check the repo's workflows
    python tools/lint/workflow_timeouts.py --self-test # prove the check fails on a planted job

Exit 0 when every job has a timeout, 1 otherwise.
"""
import glob
import os
import re
import sys

JOB = re.compile(r"^  ([A-Za-z0-9_-]+):\s*(#.*)?$")
TIMEOUT = re.compile(r"^    timeout-minutes:\s*\S+")


def jobs_without_timeout(text: str) -> list[str]:
    """Names of the jobs under `jobs:` in one workflow file's text that lack a timeout."""
    lines = text.splitlines()
    missing: list[str] = []
    in_jobs = False
    current = ""
    has = False
    for line in lines:
        if re.match(r"^jobs:\s*$", line):
            in_jobs = True
            continue
        if in_jobs and re.match(r"^\S", line) and not line.startswith("#"):
            in_jobs = False  # the next top-level key ends the jobs block
        if not in_jobs:
            continue
        m = JOB.match(line)
        if m:
            if current and not has:
                missing.append(current)
            current, has = m.group(1), False
        elif TIMEOUT.match(line):
            has = True
    if current and not has:
        missing.append(current)
    return missing


def self_test() -> int:
    good = "name: x\njobs:\n  a:\n    runs-on: ubuntu-latest\n    timeout-minutes: 5\n    steps: []\n"
    bad = good + "  b:\n    runs-on: ubuntu-latest\n    steps: []\n"
    ok = jobs_without_timeout(good) == [] and jobs_without_timeout(bad) == ["b"]
    print("ok: a planted job without a timeout is reported" if ok else "FAIL: the check is blind")
    return 0 if ok else 1


def main(argv: list[str]) -> int:
    if "--self-test" in argv:
        return self_test()
    root = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
    bad = 0
    files = sorted(glob.glob(os.path.join(root, ".github", "workflows", "*.yml")))
    for path in files:
        with open(path, encoding="utf-8") as f:
            for job in jobs_without_timeout(f.read()):
                print(f"::error file={os.path.basename(path)}::job '{job}' has no timeout-minutes")
                bad = 1
    if not bad:
        print(f"every job in {len(files)} workflows has a timeout-minutes")
    return bad


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
