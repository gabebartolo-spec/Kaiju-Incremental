# City-calm handoff, 2026-10-18 05:05
## State: running a check (build.yml dispatch dry run on CI, run 39056399854)

## Task
Role city-calm (helper). Lead: "Game demo planning" (local_106fc100).
- DONE: #26 calm streets (merged 55231be, D-054).
- DONE: #28 export-windows (head 5cb8ad9, lead PASS, lead merges on green).
- NOW: ci-export (demo P6). build.yml workflow_dispatch for any ref (input `ref`) runs
  tools/export_windows.sh + pack check on CI, uploads KaijuIncremental-<sha> (7 days); keep
  the main push trigger. Proof: one dispatch on look-options, artifact downloaded and
  smoke-launched locally (GPU slot: ask the lead; lighting until 05:20, voxel-edges 05:40).

## Branch and commit
claude/ci-export stacked on 5cb8ad9 (#28), in worktree .claude/worktrees/city-calm-streets-722ec5.
8793b28 = build.yml change (pushed). After #28 merges: merge origin/claude/look-options in
(no rebase/force-push), then open the PR into look-options.

## Unfinished changes
none uncommitted.

## Evidence so far
notes = C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2-...\export-windows
- Dry-run dispatch on claude/ci-export: run 39056399854 (pending).

## Next
1. Dry run green -> wait for #28 merge -> `gh workflow run build.yml --ref claude/ci-export
   -f ref=claude/look-options` (workflow file from this branch, code from look-options).
2. gh run download -> notes/ci-export/; smoke-launch it with scratchpad smoke_exe.sh (point EXE
   at the download) after the lead's GPU go.
3. PR into look-options, report to the lead with the head SHA.

## Attempts (fix-loop record)
none yet

## Open decisions
none

## Running jobs
gh run watch 39056399854 (background).

## Findings for the lead
- ci_capture.sh picks the newest workflow_dispatch run without filtering by branch; verify the
  run's headBranch.

## Rules learnt the hard way (under 10 lines)
- Branch off origin/claude/look-options, not the worktree's starting commit.
- `git lfs pull` before any suite or export in a fresh worktree; pulling mid-run makes the
  re-import segfault (exit 139). With LFS pointers, flow times out at 900 s.
- Template builds start fullscreen (settings.gd): seed user settings.cfg fullscreen=false
  before any windowed exe run.
- The exported pack stores resources RSCC/zstd-compressed: Python 3.14 compression.zstd.
