# City-calm handoff, 2026-10-18 05:00
## State: awaiting lead (#28 review fix pushed: tools/* excluded, re-export + smoke clean)

## Task
Role city-calm (helper). Lead: "Game demo planning" (local_106fc100).
1. DONE: calm streets, PR #26 (claude/city-calm-streets, head 55231be). Lead PASS; director
   04:35 "ship AFTER" = D-054; lead merges on green and logs D-054 in the board PR.
2. NOW: export-windows (demo P6 prep, D-050). Prove a local Windows export of
   claude/look-options: tools/export_windows.sh + tools/pck_check.py, smoke-launch the exe,
   PR into look-options, report to the lead with the head SHA.

## Branch and commit
claude/export-windows off origin/claude/look-options (444ed01), in the city-calm worktree
(.claude/worktrees/city-calm-streets-722ec5). ce97435 = the two tools (pushed).

## Unfinished changes
none uncommitted. out/windows/KaijuIncremental.exe (git-ignored) is built from ce97435.

## Evidence so far
notes = C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2-...\export-windows
- export_run_ce97435.log: exit 0, exe 126,668,576 B, pack 269 files; pack check passed
  (3 fonts carry their TTF bytes after RSCC/zstd decompress; 9 kvox byte for byte).
- Shown failing first: LFS pointer ttf + wrong kvox -> two FAIL lines, exit 1.
- pck_list.txt, export_run1_parser_bug.log (first parser misread the format-4 header).
- PR body draft: scratchpad pr_export.md (SMOKE_RESULT / EXPORT_RESULT placeholders).

## Next
0. NEXT TASK (lead 04:50): build.yml workflow_dispatch (input ref) running export_windows.sh +
   pck_check on CI, upload KaijuIncremental-<sha>.zip (7-day retention), keep main push trigger;
   proof = one dispatch on look-options, artifact downloaded + smoke-launched locally; PR.
1. DONE 04:41: smoke launch with scratchpad smoke_exe.sh <notes>/smoke. It does
   override.cfg beside the exe (mode=0, no_focus, -20000), seeded settings.cfg
   fullscreen=false, own APPDATA, --audio-driver Dummy, --write-movie PNG 1080p,
   --quit-after 450, and kills its own PID at 120 s. Pick a title frame and the log head.
2. Fill the PR body, open the PR into look-options, report to the lead (<=8 lines, head SHA).

## Attempts (fix-loop record)
pck parser: 1st misread the header (pos 28, should be 32) -> fixed; RSCC compression handled.

## Open decisions
none

## Running jobs
none.

## Findings for the lead
- (done in #28) exclude_filter now "tests/*, tools/*"; pack 269 -> 229 files; pck_check fails
  on any tools/ file in the pack.
- ci_capture.sh picks the newest workflow_dispatch run without filtering by branch; verify the
  run's headBranch.

## Rules learnt the hard way (under 10 lines)
- Branch off origin/claude/look-options, not the worktree's starting commit.
- `git lfs pull` before any suite or export in a fresh worktree; pulling mid-run makes the
  re-import segfault (exit 139). With LFS pointers, flow times out at 900 s.
- Template builds start fullscreen (settings.gd): seed user settings.cfg fullscreen=false
  before any windowed exe run.
