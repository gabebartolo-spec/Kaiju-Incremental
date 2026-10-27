"""Smoke test for the check-status filter in tools/gh/merge_on_green.sh (the lead merges only on its word).

The defect (lead, 2026-10-27): the filter counted every run in a PR's statusCheckRollup, so a check that failed
once and then passed on a re-run (GitHub keeps both) counted as red and the merge waited forever. It must count
only the newest run of each check (same workflow and name; a status context by its context name).

Runs the real script in a scratch repo (an origin with main and refs/pull/7/head, stub cheap-gate tools) with a
stub `gh` on PATH: `gh pr view` answers the head sha and evaluates the script's own --jq filter with the real
`jq` on a rollup fixture, `gh pr merge` prints "stub merged". Needs `jq` (MIT; preinstalled on GitHub's ubuntu
runners; on this PC at C:/Users/DANTE/bin/jq.exe). The old filter, as main had it, is kept below to show the
fixture is red on it.
"""

import json
import os
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path

import helpers

SCRIPT = Path(helpers.tool("tools", "gh", "merge_on_green.sh"))
GIT = ["git", "-c", "core.autocrlf=false", "-c", "user.name=t", "-c", "user.email=t@example.com"]
PR = "7"

# The filter on main before this fix: every run in the rollup counted.
OLD_FILTER = (
    '[.statusCheckRollup[]|(if (.status // "COMPLETED") != "COMPLETED" then "PENDING" '
    'elif (.conclusion // "") == "" then (.state // "PENDING") else .conclusion end)]'
    '|map(ascii_upcase)|group_by(.)|map("\\(.[0])=\\(length)")|join(" ")'
)

GH_STUB = r"""#!/usr/bin/env bash
here="$(cd "$(dirname "$0")/.." && pwd)"
if [ "$1 $2" = "pr merge" ]; then echo "stub merged"; exit 0; fi
if [ "$1 $2" != "pr view" ]; then echo "gh stub: unexpected $*" >&2; exit 99; fi
field=""; expr=""
while [ $# -gt 0 ]; do
	case "$1" in --json) field="$2"; shift ;; --jq) expr="$2"; shift ;; esac
	shift
done
case "$field" in
	headRefOid) cat "$here/head_sha.txt" ;;
	statusCheckRollup) printf '%s' "$expr" > "$here/filter.jq"; jq -r -f "$here/filter.jq" "$here/rollup.json" ;;
	*) echo "gh stub: unexpected field $field" >&2; exit 99 ;;
esac
"""


def find_bash():
    git_bash = Path(r"C:\Program Files\Git\bin\bash.exe")
    if os.name == "nt" and git_bash.exists():
        return str(git_bash)  # not the WSL bash.exe on PATH
    return shutil.which("bash") or "bash"


def run_git(root, *args):
    done = subprocess.run([*GIT, "-C", str(root), *args], check=True, capture_output=True, text=True)
    return done.stdout.strip()


def filter_in(text):
    """The --jq filter of the status line in the script."""
    found = re.search(r"--json statusCheckRollup --jq '(.*)'\)\s*$", text, re.M)
    assert found, "no `--json statusCheckRollup --jq '...'` line in merge_on_green.sh"
    return found.group(1)


def project(root, rollup, old_filter=False):
    """A scratch repo with the script, an origin holding main and refs/pull/7/head; returns the PR head sha."""
    root = Path(root)
    text = SCRIPT.read_text(encoding="utf-8")
    if old_filter:
        text = text.replace(filter_in(text), OLD_FILTER)
    helpers.write(root, "tools/gh/merge_on_green.sh", text)
    for tool in ("tools/lint/run_all.sh",):
        helpers.write(root, tool, "#!/usr/bin/env bash\nexit 0\n")
    for tool in ("tools/lint/data_schemas.py", "tools/lint/licence_register.py"):
        helpers.write(root, tool, "")
    origin = root.parent / (root.name + "_origin.git")
    subprocess.run(["git", "init", "-q", "--bare", str(origin)], check=True)
    run_git(root, "init", "-q")
    run_git(root, "add", "-A")
    run_git(root, "commit", "-q", "-m", "base")
    run_git(root, "branch", "-M", "main")
    run_git(root, "remote", "add", "origin", str(origin))
    run_git(root, "push", "-q", "origin", "main")
    helpers.write(root, "change.txt", "the PR\n")
    run_git(root, "add", "change.txt")
    run_git(root, "commit", "-q", "-m", "the PR")
    sha = run_git(root, "rev-parse", "HEAD")
    run_git(root, "push", "-q", "origin", f"HEAD:refs/pull/{PR}/head")
    run_git(root, "reset", "-q", "--hard", "origin/main")
    stub = helpers.write(root, "bin/gh", GH_STUB)
    stub.chmod(0o755)
    helpers.write(root, "head_sha.txt", sha + "\n")
    helpers.write(root, "rollup.json", json.dumps({"statusCheckRollup": rollup}))
    return sha


def run_script(root, sha):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env["PATH"] = str(Path(root) / "bin") + os.pathsep + env["PATH"]
    env.update({"POLL": "0", "MAX_LOOKS": "2", "PYTHON": sys.executable})
    done = subprocess.run(
        [find_bash(), "tools/gh/merge_on_green.sh", PR, sha],
        cwd=root,
        env=env,
        capture_output=True,
        text=True,
        timeout=120,
    )
    return done.returncode, done.stdout + done.stderr


def check_run(name, conclusion, started, workflow="tests", status="COMPLETED"):
    run = {"__typename": "CheckRun", "name": name, "workflowName": workflow, "status": status, "startedAt": started}
    run["conclusion"] = conclusion
    return run


def status_context(context, state, started):
    return {"__typename": "StatusContext", "context": context, "state": state, "startedAt": started}


EARLY, LATE = "2026-10-27T10:00:00Z", "2026-10-27T11:00:00Z"


class MergeOnGreenFilter(unittest.TestCase):
    def setUp(self):
        self.assertIsNotNone(shutil.which("jq"), "jq is not on PATH: install it (MIT; https://jqlang.org)")

    def go(self, rollup, old_filter=False):
        with helpers.scratch() as root:
            sha = project(root, rollup, old_filter)
            return run_script(root, sha)

    def test_the_fixture_is_red_on_the_old_filter(self):
        # A shard failed, was re-run and passed: GitHub lists both. Main's filter called that red.
        rollup = [check_run("shard 1", "FAILURE", EARLY), check_run("shard 1", "SUCCESS", LATE), check_run("lint", "SUCCESS", LATE)]
        code, out = self.go(rollup, old_filter=True)
        self.assertEqual(code, 1, out)
        self.assertIn("RED: FAILURE=1 SUCCESS=2", out)

    def test_a_superseded_failed_run_does_not_count(self):
        rollup = [check_run("shard 1", "FAILURE", EARLY), check_run("shard 1", "SUCCESS", LATE), check_run("lint", "SUCCESS", LATE)]
        code, out = self.go(rollup)
        self.assertEqual(code, 0, out)
        self.assertIn("MERGED 7 (SUCCESS=2)", out)

    def test_run_order_in_the_list_does_not_matter(self):
        rollup = [check_run("shard 1", "SUCCESS", LATE), check_run("shard 1", "FAILURE", EARLY)]
        code, out = self.go(rollup)
        self.assertEqual(code, 0, out)
        self.assertIn("MERGED 7 (SUCCESS=1)", out)

    def test_a_newest_failure_after_an_older_pass_is_still_red(self):
        rollup = [check_run("shard 1", "SUCCESS", EARLY), check_run("shard 1", "FAILURE", LATE), check_run("lint", "SUCCESS", LATE)]
        code, out = self.go(rollup)
        self.assertEqual(code, 1, out)
        self.assertIn("RED: FAILURE=1 SUCCESS=1", out)
        self.assertNotIn("MERGED", out)

    def test_a_rerun_still_running_is_pending_not_green(self):
        rollup = [check_run("shard 1", "FAILURE", EARLY), check_run("shard 1", "", LATE, status="IN_PROGRESS")]
        code, out = self.go(rollup)
        self.assertEqual(code, 3, out)
        self.assertIn("TIMEOUT: PENDING=1", out)

    def test_the_same_name_in_two_workflows_is_two_checks(self):
        rollup = [check_run("build", "SUCCESS", LATE, workflow="tests"), check_run("build", "FAILURE", LATE, workflow="lint")]
        code, out = self.go(rollup)
        self.assertEqual(code, 1, out)
        self.assertIn("RED: FAILURE=1 SUCCESS=1", out)

    def test_status_contexts_are_grouped_by_their_context_name(self):
        rollup = [status_context("ci/x", "FAILURE", EARLY), status_context("ci/x", "SUCCESS", LATE), check_run("lint", "SUCCESS", LATE)]
        code, out = self.go(rollup)
        self.assertEqual(code, 0, out)
        self.assertIn("MERGED 7 (SUCCESS=2)", out)


if __name__ == "__main__":
    unittest.main()
