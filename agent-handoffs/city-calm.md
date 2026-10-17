# City-calm handoff, 2026-10-18 05:10
## State: awaiting lead (PR #30 open; local smoke of the CI artifact waits for the GPU go ~05:40)

## Task
Role city-calm (helper). Lead: "Game demo planning" (local_106fc100).
- DONE: #26 calm streets (merged 55231be, D-054).
- DONE: #28 export-windows (merged 5cb8ad9): tools/export_windows.sh, tools/pck_check.py,
  exclude_filter "tests/*, tools/*".
- NOW: ci-export (demo P6, D-050). build.yml workflow_dispatch input `ref`; export via
  tools/export_windows.sh + pack check on CI; dispatched run uploads KaijuIncremental-<sha>
  (7 days); main push trigger unchanged. Proof: one dispatch on look-options, artifact
  downloaded and smoke-launched locally. PR into look-options.

## Branch and commit
claude/ci-export, worktree .claude/worktrees/city-calm-streets-722ec5.
8793b28 = build.yml change; b75a6ac = merge of look-options 87fba2d (pushed).

## Unfinished changes
none uncommitted (this handoff aside).

## Evidence so far
notes = C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2-...\ci-export
- Dry run on claude/ci-export: run 39056399854 green; artifact KaijuIncremental-8793b28;
  exe 126,591,656 B, 229 files, no tools/, headless launch loaded main.tscn.
- look-options run 39056638725 green at 87fba2d: 235 files, pack check ok, main.tscn reached;
  artifact KaijuIncremental-87fba2d downloaded to notes/ci-export/artifact/ (126,598,360 B).
- PR #30 open (head 01d6e1e), body says the smoke is pending.
- PR body draft: scratchpad pr_ci_export.md (LOOK_RUN / SMOKE placeholders).

## Next
1. DONE: run checked, PR #30 opened, lead told.
2. At the lead's GPU go (~05:40): bash scratchpad/smoke_exe.sh <notes>/ci-export/smoke
   <path to downloaded exe>; check a title frame and godot.log; fill SMOKE; gh pr edit; report.

## Attempts (fix-loop record)
none

## Open decisions
none

## Running jobs
none.

## Findings for the lead
- pck_check's tools/ assertion caught 40 dev-tool files in the demo pack before the filter
  change (#28): reading the real pack beats trusting the preset.
- ci_capture.sh picks the newest workflow_dispatch run without filtering by branch; verify the
  run's headBranch.

## Rules learnt the hard way (under 10 lines)
- Branch off origin/claude/look-options, not the worktree's starting commit.
- `git lfs pull` before any suite or export in a fresh worktree; pulling mid-run makes the
  re-import segfault (exit 139). With LFS pointers, flow times out at 900 s.
- Template builds start fullscreen (settings.gd): seed user settings.cfg fullscreen=false
  before any windowed exe run.
- The exported pack stores resources RSCC/zstd-compressed: Python 3.14 compression.zstd.
