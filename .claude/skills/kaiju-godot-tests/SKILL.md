---
name: kaiju-godot-tests
description: Extends the general game-architecture skill (tests and CI shape) with this repo's runners, floors and shards. How to run, add and debug Kaiju Incremental Godot test suites and CI without tripping over other agents on the same PC - tools/run_tests.sh, isolated user data, check floors, pinned seeds, one Godot process per agent, reading a red CI run. Use it whenever you run tools/run_tests.sh or a Godot --script, add or change a suite or a floor, read a red or cancelled CI run, or see a failure that might not be your change's fault.
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
way CI does.

- One Godot process per agent; never kill by image name; stop only your recorded PID.
- A fresh worktree has no `.godot/`; its first run imports everything. Revert `*.import` churn
  before you commit; stage by name.

## Adding a suite or checks

- Runner: `tests/run_<suite>_tests.gd` extending `tests/lib/runner.gd`: override `suite_name()`
  and `run_checks()`, call `check(condition, expectation)` once per check.
- Register in four places: `ALL_SUITES` in `tools/run_tests.sh`; a line in `tools/ci_shards.txt`;
  a floor in `tests/expected_checks.txt`; a row in `tests/README.md`. Then
  `bash tools/check_ci_shards.sh`.
- Floors only go up; count checks per rule, not per data entry, so content never moves a floor.
- Seeds pinned; a suite with no randomness says `## Seeded by design: <why>`.
- Autoloads in a `--script`: `load()` them after the first frame; never name them statically.
- New checks prove themselves: show each failing on a known-bad fixture first.

## When a test fails

1. Fails on `origin/main` too (scratch worktree, same suite)? Then it is main, not you.
2. Someone else running Godot? Rerun with your own user data.
3. Passes on rerun? Unpinned randomness: pin it.
4. A SCRIPT ERROR fails the run even when every check passed. Fix it; do not mute it.
After two similar failed fixes, stop and gather different evidence.

## CI

`tests.yml`: `plan` (floors never lowered, every suite in a shard; docs-only and draft PRs skip
the Godot jobs) -> shards -> `test`, the required check. Pushes to main are never cancelled.
`lint.yml`: doc caps, gdlint/gdformat, gitleaks, project lints when `tools/lint/run_all.sh`
exists. `build.yml`: the Windows export on every push to main.

## Learnings

Proven findings for this project live in `references/learnings.md`. General lessons go to
`game-architecture/references/learnings.md`.
