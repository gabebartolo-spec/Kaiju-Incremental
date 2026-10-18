# Phase 0 gate audit: deliberately broken PRs

Date: 2026-10-18. Base: `claude/look-options` at 3766569.
Each defect was one minimal change in a throwaway PR (now closed, remote branch deleted). A case
passes the audit when CI goes red. Workflows: `tests.yml` (plan, shards, harness self-test,
`test`), `lint.yml` (doc-caps, project-lints, gdlint, gitleaks).

| Case | PR | Run | Result | Check that went red |
|---|---|---|---|---|
| 1 lowered floor (smoke 30 -> 29), draft | #67 | tests 39116469034 | CAUGHT | `plan` (check_floors.sh: "floor lowered: suite smoke is 30 ... 29"), so `test` red |
| 2 new suite file `run_audit_tests.gd` only, draft | #68 | tests 39116481946 | NOT CAUGHT | none, all green |
| 2b same suite plus ALL_SUITES and shard entries, no floor line, ready | #69 | tests 39116492128 | CAUGHT | `shard 1` ("expected_checks.txt has no floor for 'audit'"), so `test` red |
| 3 untyped `var x = 1` in scenes/fire.gd, ready | #70 | tests 39116501604 | CAUGHT | `shard 1` and `harness self-test` ("Variable x has no static type", warning as error); gdlint stayed green |
| 4 planted `KAIJU_TEST_SECRET_` + 16 chars, draft | #71 | lint 39116517801 | CAUGHT | `gitleaks` (rule kaiju-test-secret) |

## Findings

1. A test file dropped into `tests/` and not added to `ALL_SUITES` in `tools/run_tests.sh`
   never runs, is never compared with a floor, and CI stays green (case 2). The "no floor"
   rule only fires for suites already in ALL_SUITES; nothing compares `tests/run_*_tests.gd`
   with ALL_SUITES, so a suite can go missing silently. Not fixed.
2. Draft PRs skip the shards and the self-test, and the required `test` check passes on them
   (cases 1, 2 and 4 were drafts; only plan and lint ran). Cases 2b and 3 had to be ready
   PRs to exercise the Godot checks. Untyped code in a draft is green until marked ready
   (by design in tests.yml, but worth knowing for branch protection).
3. Untyped declarations are caught only by Godot's compile in the shards and the harness
   self-test; gdlint does not flag them.
4. Case 4 works because `.gitleaks.toml` adds the `kaiju-test-secret` rule; the default
   rules would excuse the planted value.
