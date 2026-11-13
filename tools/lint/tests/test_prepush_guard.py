"""Smoke test for the PASS guard in tools/prepush.sh (the lead merges only on "prepush: PASS <sha>").

The defect (debt-ci-data, 2026-10-27 06:09): on Windows a step stopped with `taskkill /F` reports exit code 0
to the bash that waits for it (MSYS reads a terminated native or bash child as 0), so prepush printed
"prepush: PASS" for a run that never finished. A step now passes only on exit 0 AND its own success line as the
last line of its output: step 4 import (the engine prints nothing on success but its start-up progress, which
ends "[ DONE ] loading_editor_layout"), check_scripts.sh ("ok: check_scripts: <n> scripts, 0 failed"), step 4b
run_all.sh ("lint: ok") and step 5 run_tests.sh ("All checks passed (<n> suites)." with n the suites asked for).

Builds a scratch project (a git repo with an origin, stub lint tools, a stub Godot) around a copy of the
real prepush.sh and a stub for each step's tool, runs it, and checks the last line it prints: a normal pass ->
PASS <sha>; for each step a run killed from outside (taskkill /F on Windows, SIGKILL elsewhere), a run that
exits 0 with no success line, a success line with a non-zero exit, a failure summary, and a success line that
is not the last line -> FAIL <step>.

The scratch repo is built once and copied per case, and the 26 cases run four at a time in setUpClass; each
test then checks its own case's result.
"""

import concurrent.futures
import os
import re
import shutil
import signal
import subprocess
import time
import unittest
from pathlib import Path

import helpers

PREPUSH = Path(helpers.tool("tools", "prepush.sh"))
GIT = ["git", "-c", "core.autocrlf=false", "-c", "user.name=t", "-c", "user.email=t@example.com"]

# Each step's success line, and the last line prepush prints when the step fails.
SUITES_OK = "All checks passed (2 suites)."
COMPILE_OK = "ok: check_scripts: 3 scripts, 0 failed"
LINTS_OK = "lint: ok"
FAIL_LINE = {
    "suites": r"^prepush: FAIL suites \(alpha beta\b",
    "compile": r"^prepush: FAIL script compile$",
    "lints": r"^prepush: FAIL repo lints$",
    "import": r"^prepush: FAIL import \(exit \d",
}

# step -> the project() argument holding the stub for that step's tool
KEYWORD = {"suites": "run_tests", "compile": "check_scripts", "lints": "run_all", "import": "godot"}

# A hang guard only (seconds): a prepush on the stubs takes a few seconds, even under load.
RUN_TIMEOUT = 600

# Waits to be killed from outside; whatever follows the loop is never reached. $STUB_DIR is set by prepush_env.
WAIT_TO_BE_KILLED = (
    'echo $$ > "$STUB_DIR/rt.pid"\n'
    'cat /proc/$$/winpid > "$STUB_DIR/rt.winpid" 2> /dev/null\n'
    "for i in $(seq 1 300); do sleep 0.1; done\n"
)


def stubs_for(ok_line, failed_line):
    """Stub bodies for one step's tool: how it ends in each case the guard must tell apart."""
    return {
        "ok": f'echo "== stub"\necho "{ok_line}"\nexit 0\n',
        "silent": 'echo "== stub"\nexit 0\n',
        "marker_exit_1": f'echo "{ok_line}"\nexit 1\n',
        "failed_summary": f'echo "{failed_line}"\nexit 0\n',
        "marker_not_last": f'echo "{ok_line}"\necho "trailing noise"\nexit 0\n',
        "killed": WAIT_TO_BE_KILLED + f'echo "{ok_line}"\nexit 0\n',
    }


# Step 5's extra cases: a pass line with the wrong suite count.
SUITES = stubs_for(SUITES_OK, "Some checks FAILED (2 suites run). Logs: /tmp/x")
SUITES["short_count"] = 'echo "All checks passed (1 suites)."\nexit 0\n'
SUITES["too_many"] = 'echo "All checks passed (3 suites)."\nexit 0\n'
COMPILE = stubs_for(COMPILE_OK, "FAIL: a script does not parse or compile (exit 0)")
LINTS = stubs_for(LINTS_OK, "lint: FAIL tools/lint/check_uids.sh")

# The stub engine's import log, as the real one prints it (CRLF line ends, ANSI colour codes).
BANNER = "printf 'Godot Engine v4.7.2.stable.official.ed1daf0bf - https://godotengine.org\\r\\n\\r\\n'\n"
PROGRESS = "printf '[  16%% ] \\033[90m\\033[1mfirst_scan_filesystem\\033[22m | Loading...\\033[39m\\033[0m\\r\\n'\n"
DONE = "printf '\\033[92m[ DONE ]\\033[39m \\033[1mloading_editor_layout\\033[22m\\r\\n\\033[0m\\r\\n'\n"
IMPORT = {
    "ok": BANNER + PROGRESS + DONE + "exit 0\n",
    "silent": BANNER + "exit 0\n",
    "unfinished": BANNER + PROGRESS + "exit 0\n",
    "done_line_but_exit_1": BANNER + PROGRESS + DONE + "exit 1\n",
    "script_error": BANNER + 'echo "SCRIPT ERROR: Parse Error: Identifier not found"\n' + PROGRESS + DONE + "exit 0\n",
    "killed": BANNER + PROGRESS + WAIT_TO_BE_KILLED + DONE + "exit 0\n",
}


# Step 1b's tool (tools/native_dll.sh check|fetch): already main's build; stale until a fetch; stale for good (a
# running Godot holds the DLL, so the fetch's copy cannot replace it). $STUB_DIR is set by prepush_env.
NATIVE = {
    "ok": "exit 0\n",
    "stale_until_fetched": (
        'case "$1" in\n'
        'fetch) touch "$STUB_DIR/fetched" ;;\n'
        'check) [ -f "$STUB_DIR/fetched" ] || { echo "native_dll: FAIL stale"; exit 1; } ;;\n'
        "esac\nexit 0\n"
    ),
    "stale_after_fetch": '[ "$1" = check ] && { echo "native_dll: FAIL stale"; exit 1; }\nexit 0\n',
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


def write_tools(
    root,
    run_tests=SUITES["ok"],
    check_scripts=COMPILE["ok"],
    run_all=LINTS["ok"],
    godot=IMPORT["ok"],
    picks="",
    native_dll=NATIVE["ok"],
):
    """Writes the real tools/prepush.sh and a stub for everything it calls into root."""
    helpers.write(root, "tools/prepush.sh", PREPUSH.read_text(encoding="utf-8"))
    # prepush.sh sources tools/speed_gate.sh (D-299); the real one, made a no-op by SPEED_GATE in prepush_env.
    helpers.write(root, "tools/speed_gate.sh", Path(helpers.tool("tools", "speed_gate.sh")).read_text(encoding="utf-8"))
    for name in ("workflow_timeouts", "tuning_keys", "licence_register", "complexity_ratchet", "data_schemas"):
        helpers.write(root, f"tools/lint/{name}.py", "")
    # prepush_picks.py prints "suite<TAB>reason" lines; `picks` is the list of suites it picks.
    lines = "".join(f"{s}\\tchanged\\n" for s in picks)
    helpers.write(root, "tools/lint/prepush_picks.py", f'import sys\nsys.stdout.write("{lines}")\n')
    script(root, "tools/check_scripts.sh", check_scripts)
    script(root, "tools/lint/run_all.sh", run_all)
    script(root, "tools/native_dll.sh", native_dll)  # step 1b compares the DLL with main's CI build (needs gh)
    script(root, "godot_stub.sh", godot)
    script(root, "tools/run_tests.sh", run_tests)
    for suite in ("alpha", "beta", "gamma"):
        helpers.write(root, f"tests/run_{suite}_tests.gd", "")
    helpers.write(root, "tools/ci_timings.txt", "")


def project(root):
    """A scratch repo with an origin whose tools/prepush.sh is the real one and everything it calls is a stub;
    returns its sha. Built once per run: each case copies it (copy_case), since git init + commit + push costs
    seven process starts, which take seconds on Windows."""
    root = Path(root)
    write_tools(root)
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


def copy_case(template, dest, **stubs):
    """A copy of the template repo with `stubs` written over its tools. prepush reads only committed changes
    (git diff BASE...HEAD), so a stub changed in the working tree runs without a commit of its own."""
    shutil.copytree(template, dest)
    write_tools(dest, **stubs)
    return dest


def prepush_env(root):
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env["GODOT"] = str(Path(root) / "godot_stub.sh")
    env["SPEED_GATE"] = str(Path(root) / "no_speed_gate.sh")  # absent file: wait_speed_gate returns at once
    env["SUITES"] = "alpha beta"
    env["BASE"] = "origin/main"
    env["STUB_DIR"] = Path(root).as_posix()  # where a stub waiting to be killed leaves its pids
    return env


def last_line(out):
    return [line for line in out.splitlines() if line.strip()][-1]


def run_prepush(root, **env_extra):
    env = {**prepush_env(root), **env_extra}
    done = subprocess.run([find_bash(), "tools/prepush.sh"], cwd=root, env=env, capture_output=True, text=True, timeout=RUN_TIMEOUT)
    return done.returncode, done.stdout + done.stderr


def process_gone(winpid):
    """True when no Windows process has this pid (tasklist lists none)."""
    listing = subprocess.run(["tasklist", "/FI", f"PID eq {winpid}", "/NH"], capture_output=True, text=True).stdout
    return str(winpid) not in listing


def kill_tree(pid):
    """Stops a process and all it started, the way an agent does on Windows (taskkill /F) or elsewhere (SIGKILL).
    /T takes the stub's `sleep` too, so no orphan holds the temp folder open. A failed kill is fatal unless the
    process is already gone."""
    if os.name == "nt":
        done = subprocess.run(["taskkill", "/F", "/T", "/PID", str(pid)], capture_output=True, text=True)
        if done.returncode != 0 and not process_gone(pid):
            raise AssertionError(
                f"taskkill /F /T /PID {pid} failed ({done.returncode}): {done.stderr.strip()} {done.stdout.strip()}"
            )
        return
    try:
        os.kill(int(pid), signal.SIGKILL)
    except ProcessLookupError:
        pass


def stop_prepush(proc):
    """Cleanup that never raises: ends a prepush that is still running."""
    if proc.poll() is None:
        try:
            kill_tree(proc.pid)
        except AssertionError:
            proc.kill()
        proc.wait()


def kill_from_outside(root, proc):
    """Waits for the stub step to leave its pid, then kills it. Waits while prepush runs, up to the RUN_TIMEOUT
    hang guard; if prepush ends before the step is running, that is a plain failure carrying its output."""
    files = [Path(root) / "rt.pid"] + ([Path(root) / "rt.winpid"] if os.name == "nt" else [])
    deadline = time.monotonic() + RUN_TIMEOUT
    while not all(f.exists() and f.read_text().strip() for f in files):
        if proc.poll() is not None:
            out, _ = proc.communicate()
            raise AssertionError("prepush ended before the step to kill was running:\n" + out)
        if time.monotonic() > deadline:
            raise AssertionError(f"the step to kill never started within {RUN_TIMEOUT} s")
        time.sleep(0.05)
    kill_tree(files[-1].read_text().strip())


def run_prepush_and_kill_the_step(root):
    """Starts prepush, kills the stub step that is waiting to be killed, returns (exit code, output)."""
    proc = subprocess.Popen(
        [find_bash(), "tools/prepush.sh"],
        cwd=root,
        env=prepush_env(root),
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    try:
        kill_from_outside(root, proc)
        try:
            out, _ = proc.communicate(timeout=RUN_TIMEOUT)
        except subprocess.TimeoutExpired:
            stop_prepush(proc)
            out, _ = proc.communicate()
            raise AssertionError(f"prepush still running {RUN_TIMEOUT} s after its step was killed; output:\n{out}")
    finally:
        stop_prepush(proc)
    return proc.returncode, out


# Git Bash could not start a process (Windows short of resources when the PC is busy): prepush died before
# the step under test, so the run says nothing about the guard and is run again (2026-11-14: exit 254,
# "dofork: child -1 - CreateProcessW failed ... fork: File too large", on a different case each run).
FORK_FAILED = re.compile(r"CreateProcessW failed|dofork:|: fork: ")
TRIES = 3

# Cases run side by side (each prepush is mostly waiting on process starts): 26 runs one after another took
# 9-23 min on Windows, 4 at a time a quarter of that.
WORKERS = 4

# name -> (killed?, stubs for copy_case, extra env for prepush)
CASES = {
    "pass": (False, {}, {}),
    "picks_gamma": (False, {"picks": ["gamma"]}, {"SUITES": "alpha"}),
    "dll_stale_until_fetched": (False, {"native_dll": NATIVE["stale_until_fetched"]}, {}),
    "dll_stale_after_fetch": (False, {"native_dll": NATIVE["stale_after_fetch"]}, {}),
}
for _step, _stubs in (("suites", SUITES), ("import", IMPORT), ("compile", COMPILE), ("lints", LINTS)):
    for _name, _body in _stubs.items():
        if _name != "ok":
            CASES[f"{_step}:{_name}"] = (_name == "killed", {KEYWORD[_step]: _body}, {})


def run_case(base, name):
    """Runs one case on its own copy of the template; returns (exit code, output)."""
    killed, stubs, env_extra = CASES[name]
    for attempt in range(TRIES):
        root = copy_case(base / "template", base / f"case{list(CASES).index(name)}_{attempt}", **stubs)
        try:
            code, out = run_prepush_and_kill_the_step(root) if killed else run_prepush(root, **env_extra)
        except (AssertionError, subprocess.TimeoutExpired) as e:  # fails this case's test, not the whole class
            code, out = None, f"{type(e).__name__}: {e}"
        if code == 0 or not FORK_FAILED.search(out):
            break
    return code, out


class PrepushGuard(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls._scratch = helpers.scratch()
        base = cls._scratch.__enter__()
        cls.sha = project(base / "template")
        with concurrent.futures.ThreadPoolExecutor(WORKERS) as pool:
            futures = {name: pool.submit(run_case, base, name) for name in CASES}
        cls.results = {name: future.result() for name, future in futures.items()}

    @classmethod
    def tearDownClass(cls):
        cls._scratch.__exit__(None, None, None)

    def check_fail(self, step, out, code):
        self.assertEqual(code, 1, out)
        self.assertRegex(last_line(out), FAIL_LINE[step], out)
        self.assertNotIn("prepush: PASS", out)

    def case(self, step, stubs, name):
        """prepush with `name`'s stub as the step's tool (the other steps normal) fails at that step."""
        code, out = self.results[f"{step}:{name}"]
        self.check_fail(step, out, code)

    def killed(self, step, stubs):
        self.case(step, stubs, "killed")

    def test_normal_pass_prints_pass_and_the_sha(self):
        code, out = self.results["pass"]
        self.assertEqual(code, 0, out)
        self.assertEqual(last_line(out), f"prepush: PASS {self.sha}", out)

    def test_suites_prepush_picks_count_too(self):
        # SUITES names alpha, the picks add gamma: run_tests is asked for 2 suites and must say so.
        code, out = self.results["picks_gamma"]
        self.assertEqual(code, 0, out)
        self.assertEqual(last_line(out), f"prepush: PASS {self.sha}", out)
        self.assertIn("suites: alpha gamma", out)

    # step 5: the suites (run_tests.sh)
    def test_run_killed_from_outside_is_fail(self):
        self.killed("suites", SUITES)

    def test_exit_0_without_the_pass_line_is_fail(self):
        self.case("suites", SUITES, "silent")

    def test_pass_line_with_a_short_suite_count_is_fail(self):
        self.case("suites", SUITES, "short_count")

    def test_pass_line_with_a_wrong_suite_count_is_fail(self):
        self.case("suites", SUITES, "too_many")

    def test_pass_line_but_nonzero_exit_is_fail(self):
        self.case("suites", SUITES, "marker_exit_1")

    def test_failure_summary_with_exit_0_is_fail(self):
        self.case("suites", SUITES, "failed_summary")

    def test_pass_line_that_is_not_the_last_line_is_fail(self):
        self.case("suites", SUITES, "marker_not_last")

    # step 4: the project import (the stub engine prints a start-up log like the real one)
    def test_import_killed_from_outside_is_fail(self):
        self.killed("import", IMPORT)

    def test_import_exit_0_with_no_progress_log_is_fail(self):
        code, out = self.results["import:silent"]
        self.check_fail("import", out, code)
        self.assertEqual(last_line(out), "prepush: FAIL import (exit 0, never finished)", out)

    def test_import_exit_0_that_stops_before_the_done_line_is_fail(self):
        code, out = self.results["import:unfinished"]
        self.assertEqual(code, 1, out)
        self.assertEqual(last_line(out), "prepush: FAIL import (exit 0, never finished)", out)

    def test_import_done_line_but_nonzero_exit_is_fail(self):
        code, out = self.results["import:done_line_but_exit_1"]
        self.assertEqual(code, 1, out)
        self.assertEqual(last_line(out), "prepush: FAIL import (exit 1)", out)

    def test_import_script_error_is_still_fail(self):
        code, out = self.results["import:script_error"]
        self.assertEqual(code, 1, out)
        self.assertEqual(last_line(out), "prepush: FAIL import (exit 0)", out)

    # step 4: tools/check_scripts.sh (parse and compile every script)
    def test_compile_check_killed_from_outside_is_fail(self):
        self.killed("compile", COMPILE)

    def test_compile_check_exit_0_without_its_ok_line_is_fail(self):
        self.case("compile", COMPILE, "silent")

    def test_compile_check_ok_line_but_nonzero_exit_is_fail(self):
        self.case("compile", COMPILE, "marker_exit_1")

    def test_compile_check_failure_text_with_exit_0_is_fail(self):
        self.case("compile", COMPILE, "failed_summary")

    def test_compile_check_ok_line_that_is_not_the_last_line_is_fail(self):
        self.case("compile", COMPILE, "marker_not_last")

    # step 4b: tools/lint/run_all.sh (the repo lints)
    def test_repo_lints_killed_from_outside_is_fail(self):
        self.killed("lints", LINTS)

    def test_repo_lints_exit_0_without_lint_ok_is_fail(self):
        self.case("lints", LINTS, "silent")

    def test_repo_lints_ok_line_but_nonzero_exit_is_fail(self):
        self.case("lints", LINTS, "marker_exit_1")

    def test_repo_lints_failure_text_with_exit_0_is_fail(self):
        self.case("lints", LINTS, "failed_summary")

    def test_repo_lints_ok_line_that_is_not_the_last_line_is_fail(self):
        self.case("lints", LINTS, "marker_not_last")

    # step 1b: tools/native_dll.sh (the DLL against main's CI build), before every slow step
    def test_stale_dll_is_fetched_and_the_run_passes(self):
        code, out = self.results["dll_stale_until_fetched"]
        self.assertEqual(code, 0, out)
        self.assertEqual(last_line(out), f"prepush: PASS {self.sha}", out)
        self.assertIn("native DLL is not main's CI build: fetching it", out)

    def test_dll_still_stale_after_a_fetch_fails_before_the_import(self):
        code, out = self.results["dll_stale_after_fetch"]
        self.assertEqual(code, 1, out)
        self.assertRegex(last_line(out), r"^prepush: FAIL native DLL \(still not main's CI build", out)
        self.assertNotIn("== 2 ", out)
        self.assertNotIn("== 4 ", out)


if __name__ == "__main__":
    unittest.main()
