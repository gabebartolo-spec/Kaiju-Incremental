---
name: kaiju-godot-tests
description: Extends the general game-architecture skill (tests and CI shape) with this repo's runners, function counting and timed shards. How to run, add and debug Kaiju Incremental Godot test suites and CI without tripping over other agents on the same PC - tools/run_tests.sh, isolated user data, every test function counted, shards from timings, pinned seeds, one Godot process per agent, reading a red CI run. Use it whenever you run tools/run_tests.sh or a Godot --script, add or change a suite or a test function, read a red or cancelled CI run, or see a failure that might not be your change's fault.
---

# Running Godot tests in Kaiju Incremental

The rules are `game-architecture` §6 and `github-hygiene` §7; this file is the repo's
specifics.

## The command

```bash
GODOT="C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe" tools/run_tests.sh smoke
```

`GODOT` is the console build so output reaches the shell. The script imports the project
(fails on any SCRIPT ERROR), runs each named suite `tests/run_<suite>_tests.gd` headless with a
time limit, and with no suite named also runs the harness self-test (`tools/test_run_tests.sh`).
Every run gets its own temp user-data dir. `SUITES_ONLY=1` / `EXTRAS_ONLY=1` split the work the
way CI does. The local loop: `tools/run_tests.sh --quick <suite>` skips the re-import after one
full run (scripts changed, no assets). Run only the suites you touched; leave the full set to CI.
Output is quiet by default: failures and one summary line; `--verbose` (or `VERBOSE=1`, as CI
uses) prints every suite's line.

- One Godot process per agent; never kill by image name; stop only your recorded PID.
- A fresh worktree has no `.godot/`; its first run imports everything. Revert `*.import` churn
  before you commit; stage by name.

## Adding a suite or checks

- Runner: `tests/run_<suite>_tests.gd` extending `tests/lib/runner.gd`: override `suite_name()`
  and `run_checks()`, keep each test in a `_check_*` method and call it from `run_checks()` as
  `await _t("_check_x")` (args: `await _t("_check_x", [a, b])`); a `tests/lib` helper runs as
  `await _h("Label", func() -> void: Helper.new(check).run())`. Call `check(condition,
  expectation)` once per check.
- Nothing to register (director 2026-10-19, no hand-kept registries): suites are found by filename,
  and the suite line "K of M functions" fails, by name, a `_check_*` method never called or a test
  that made no check. There are no floors and no shard list. Add a row to `tests/README.md`.
- Shards come from `tools/ci_timings.txt` via `tools/plan_ci_shards.sh` (longest suite first into
  the lightest of shards x lanes bins; each shard runs `lanes` suites at once, `LANES` in
  `tools/run_tests.sh`). A new suite counts as 60 s until the next re-measure; re-measure at least
  weekly or after adding a slow suite from real CI runs: `python tools/ci_retime.py` (reads the
  shard logs of the last green runs with gh), and raise `shards` when the heaviest shard passes
  about 8 minutes.
- A suite longer than a lane's share (the heaviest are `streamview` and `flow`) is split with a
  `split <suite> <n>` line in `tools/ci_timings.txt`: CI runs it as `<suite>@1/n` ... `<suite>@n/n`
  and part K runs the `_t`/`_h` calls of `run_checks()` whose position is K-1 modulo n
  (`tests/lib/functions_ran.gd`), so together the parts run each call once. Anything `run_checks()`
  does outside `_t`/`_h` runs in every part; a check made there fails the part. Locally the suite
  still runs whole (`tools/run_tests.sh flow`); `flow@1/2` runs one part, and `flow@1/1` runs the
  whole suite and prints each call's time (`CALL <n> <name> <ms> ms`), to balance a split.
- Seeds pinned; a suite with no randomness says `## Seeded by design: <why>`.
- Autoloads in a `--script`: `load()` them after the first frame; never name them statically.
- New checks prove themselves: show each failing on a known-bad fixture first.

## When a test fails

1. Fails on `origin/main` too (scratch worktree, same suite)? Then it is main, not you.
2. Someone else running Godot? Rerun with your own user data.
3. Passes on rerun? Unpinned randomness: pin it.
4. A SCRIPT ERROR fails the run even when every check passed. Fix it; do not mute it. So does the
   engine's exit report "N ObjectDB instances were leaked" / "N resources still in use at exit": a
   RampageSim a test drops is cut at the quit (tests/lib/runner.gd, SimTeardown), but any other
   object a test builds and drops in a ring must be freed by the test (`log_smoke.sh --leaks`).
After two similar failed fixes, stop and gather different evidence.

## CI

`tests.yml`: `plan` (shards from timings; docs-only and draft PRs skip the Godot jobs; a push to
main whose tree a green PR run already tested skips its re-test, `tools/ci_reuse_pr_run.sh`) ->
`preflight` (import and compile only, red in about a minute) -> shards + harness self-test ->
`test`, the required check. A PR run targets 10-12 minutes, job start to the `test` result (the
longest suite, `streamview`, is the floor). Pushes to main are
never cancelled; slow suites (`pr_skip` in `tools/ci_timings.txt`) run on main only.
`lint.yml`: doc caps, gdlint/gdformat, gitleaks, project lints when `tools/lint/run_all.sh`
exists. `build.yml`: the Windows export on every push to main.

## Learnings

Proven findings for this project live in `references/learnings.md`. General lessons go to
`game-architecture/references/learnings.md`.
