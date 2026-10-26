"""Smoke test for the PASS guard in tools/prepush.sh (the lead merges only on "prepush: PASS <sha>").

The defect (debt-ci-data, 2026-10-27 06:09): on Windows a run_tests.sh stopped with `taskkill /F` reports
exit code 0 to the bash that waits for it, so prepush printed "prepush: PASS" for a run that never
finished. PASS now also needs run_tests.sh's own last line, "All checks passed (<n> suites).", with n the
number of suites prepush asked for.

Builds a scratch project (a git repo with an origin, stub lint tools, a stub Godot) around a copy of the
real prepush.sh and a stub tools/run_tests.sh, runs it, and checks the last line it prints:
a normal pass -> PASS <sha>; a run killed from outside (taskkill /F on Windows, SIGKILL elsewhere), a run
that exits 0 with no pass line, a pass line with a short suite count, a pass line with a non-zero exit, a
failure summary, and a pass line that is not the last line -> FAIL suites (...).
"""

import os
import shutil
import signal
import subprocess
import time
import unittest
from pathlib import Path

import helpers

PREPUSH = Path(helpers.tool("tools", "prepush.sh"))
GIT = ["git", "-c", "core.autocrlf=false", "-c", "user.name=t", "-c", "user.email=t@example.com"]

# Stub run_tests.sh bodies. $@ is "--quick <suites>".
STUBS = {
    "ok": 'echo "== stub suites"\necho "All checks passed (2 suites)."\nexit 0\n',
    "no_pass_line": 'echo "== stub suites"\nexit 0\n',
    "short_count": 'echo "All checks passed (1 suites)."\nexit 0\n',
    "too_many": 'echo "All checks passed (3 suites)."\nexit 0\n',
    "pass_line_exit_1": 'echo "All checks passed (2 suites)."\nexit 1\n',
    "failed_summary": 'echo "Some checks FAILED (2 suites run). Logs: /tmp/x"\nexit 0\n',
    "pass_line_not_last": 'echo "All checks passed (2 suites)."\necho "trailing noise"\nexit 0\n',
    # Waits to be killed from outside; the pass line after the loop is never reached.
    "killed": (
        'echo $$ > "$(dirname "$0")/../rt.pid"\n'
        'cat /proc/$$/winpid > "$(dirname "$0")/../rt.winpid" 2> /dev/null\n'
        "for i in $(seq 1 300); do sleep 0.1; done\n"
        'echo "All checks passed (2 suites)."\nexit 0\n'
    ),
}


def find_bash():
    git_bash = Path(r"C:\Program Files\Git\bin\bash.exe")
    if os.name == "nt" and git_bash.exists():
        return str(git_bash)  # not the WSL bash.exe on PATH
    return shutil.which("bash") or "bash"


def script(root, rel, body):
    path = helpers.write(root, rel, "#!/usr/bin/env bash\n" + body)
    path.chmod(0o755)
    return path


def project(root, run_tests_body, picks=""):
    """A scratch repo whose tools/prepush.sh is the real one and everything it calls is a stub."""
    root = Path(root)
    helpers.write(root, "tools/prepush.sh", PREPUSH.read_text(encoding="utf-8"))
    for name in ("tuning_keys", "licence_register", "complexity_ratchet", "data_schemas"):
        helpers.write(root, f"tools/lint/{name}.py", "")
    # prepush_picks.py prints "suite<TAB>reason" lines; `picks` is the list of suites it picks.
    lines = "".join(f"{s}\\tchanged\\n" for s in picks)
    helpers.write(root, "tools/lint/prepush_picks.py", f'import sys\nsys.stdout.write("{lines}")\n')
    script(root, "tools/check_scripts.sh", "exit 0\n")
    script(root, "tools/lint/run_all.sh", "exit 0\n")
    script(root, "godot_stub.sh", "exit 0\n")
    script(root, "tools/run_tests.sh", run_tests_body)
    for suite in ("alpha", "beta", "gamma"):
        helpers.write(root, f"tests/run_{suite}_tests.gd", "")
    helpers.write(root, "tools/ci_timings.txt", "")
    origin = root.parent / (root.name + "_origin.git")
    subprocess.run(["git", "init", "-q", "--bare", str(origin)], check=True)
    git = [*GIT, "-C", str(root)]
    subprocess.run([*git, "init", "-q"], check=True)
    subprocess.run([*git, "add", "-A"], check=True)
    subprocess.run([*git, "commit", "-q", "-m", "base"], check=True)
    subprocess.run([*git, "branch", "-M", "main"], check=True)
    subprocess.run([*git, "remote", "add", "origin", str(origin)], check=True)
    subprocess.run([*git, "push", "-q", "origin", "main"], check=True)
    sha = subprocess.run([*git, "rev-parse", "HEAD"], check=True, capture_output=True, text=True).stdout.strip()
    return sha


def prepush_env(root):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env["GODOT"] = str(Path(root) / "godot_stub.sh")
    env["SUITES"] = "alpha beta"
    env["BASE"] = "origin/main"
    return env


def last_line(out):
    return [line for line in out.splitlines() if line.strip()][-1]


def run_prepush(root):
    done = subprocess.run(
        [find_bash(), "tools/prepush.sh"], cwd=root, env=prepush_env(root), capture_output=True, text=True, timeout=120
    )
    return done.returncode, done.stdout + done.stderr


def kill_from_outside(root):
    """Stops the stub run_tests.sh the way an agent does on Windows (taskkill /F) or elsewhere (SIGKILL)."""
    pid_file = Path(root) / "rt.pid"
    winpid_file = Path(root) / "rt.winpid"
    deadline = time.time() + 60
    while time.time() < deadline and not (pid_file.exists() and pid_file.read_text().strip()):
        time.sleep(0.05)
    if os.name == "nt":
        while time.time() < deadline and not (winpid_file.exists() and winpid_file.read_text().strip()):
            time.sleep(0.05)
        subprocess.run(["taskkill", "/F", "/PID", winpid_file.read_text().strip()], check=True, capture_output=True)
    else:
        os.kill(int(pid_file.read_text().strip()), signal.SIGKILL)


class PrepushGuard(unittest.TestCase):
    def check_fail(self, out, code):
        self.assertEqual(code, 1, out)
        self.assertRegex(last_line(out), r"^prepush: FAIL suites \(alpha beta\b", out)
        self.assertNotIn("prepush: PASS", out)

    def test_normal_pass_prints_pass_and_the_sha(self):
        with helpers.scratch() as root:
            sha = project(root, STUBS["ok"])
            code, out = run_prepush(root)
        self.assertEqual(code, 0, out)
        self.assertEqual(last_line(out), f"prepush: PASS {sha}", out)

    def test_suites_prepush_picks_count_too(self):
        # SUITES names alpha, the picks add gamma: run_tests is asked for 2 suites and must say so.
        with helpers.scratch() as root:
            sha = project(root, STUBS["ok"], picks=["gamma"])
            env = prepush_env(root)
            env["SUITES"] = "alpha"
            done = subprocess.run([find_bash(), "tools/prepush.sh"], cwd=root, env=env, capture_output=True, text=True, timeout=120)
        out = done.stdout + done.stderr
        self.assertEqual(done.returncode, 0, out)
        self.assertEqual(last_line(out), f"prepush: PASS {sha}", out)
        self.assertIn("suites: alpha gamma", out)

    def test_run_killed_from_outside_is_fail(self):
        with helpers.scratch() as root:
            project(root, STUBS["killed"])
            proc = subprocess.Popen(
                [find_bash(), "tools/prepush.sh"],
                cwd=root,
                env=prepush_env(root),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
            )
            try:
                kill_from_outside(root)
                out, _ = proc.communicate(timeout=120)
            finally:
                if proc.poll() is None:
                    proc.kill()
        self.check_fail(out, proc.returncode)

    def test_exit_0_without_the_pass_line_is_fail(self):
        with helpers.scratch() as root:
            project(root, STUBS["no_pass_line"])
            code, out = run_prepush(root)
        self.check_fail(out, code)

    def test_pass_line_with_a_short_suite_count_is_fail(self):
        with helpers.scratch() as root:
            project(root, STUBS["short_count"])
            code, out = run_prepush(root)
        self.check_fail(out, code)

    def test_pass_line_with_a_wrong_suite_count_is_fail(self):
        with helpers.scratch() as root:
            project(root, STUBS["too_many"])
            code, out = run_prepush(root)
        self.check_fail(out, code)

    def test_pass_line_but_nonzero_exit_is_fail(self):
        with helpers.scratch() as root:
            project(root, STUBS["pass_line_exit_1"])
            code, out = run_prepush(root)
        self.check_fail(out, code)

    def test_failure_summary_with_exit_0_is_fail(self):
        with helpers.scratch() as root:
            project(root, STUBS["failed_summary"])
            code, out = run_prepush(root)
        self.check_fail(out, code)

    def test_pass_line_that_is_not_the_last_line_is_fail(self):
        with helpers.scratch() as root:
            project(root, STUBS["pass_line_not_last"])
            code, out = run_prepush(root)
        self.check_fail(out, code)


if __name__ == "__main__":
    unittest.main()
