# Lead handoff, 2026-10-21 (lead 9, session local_df2c2989, CLI 07ae5487; registered in context-guard-leads)
## Next lead: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then list_sessions. Director's /goal: playable build with building carving first draft.
## Plan = docs/ROADMAP.md "Post-demo plan" phases A-H; every comment in docs/roadmap/2026-10-20-build2-playtest.md
## (30 notes) and docs/roadmap/2026-10-20-director-comments.md (rows 1-19; 18-19 added in #115).

## Team (director 2026-10-21: "i will now allow you to use subagents. drive direction yourself"; "up to 8")
- Lead runs up to 8 subagents (Agent tool, builder type, own worktree; RULEBOOK Kaiju exception). The Sonnet helper
  sessions are gone (archived at 300k). Running 2026-10-21, each pushes a branch, no PR, reports to the lead:
  tree-apart (kerb-fixes.md part 2: tree bunching), swipe-occlusion (claw chews a building hidden behind its target),
  phase-b-boards (b2-19 voxel half/today/double + b2-20 non-voxel boards -> notes/phase-b/, director picks),
  b2-22 finish (demolished-neighbour capture + fixes), stadium-crowd (#17 dangling feet + b2-8 thinning),
  rubble-cap (b2-3 slow frames, 823-piece cap, 246 ms stadium hitch), turn-weight (Opus; comments #16),
  GitHub hygiene (owns merging #115/#116 on green + their building_stream conflict, branch/worktree cleanup).
- Notes: C:\Users\DANTE\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_cf0b00c9-bc39-4198-aaf9-942340291b1a\
  (freeze-trace, stadium-review, landmark-box/, kerb-fixes, red-115, b2-30/, phase-a-audit; builders add folders).
  Phase maps (FINAL): ...\local_962460da-...\phase-maps.md, phase-maps-copy.md.

## Merged: #113 river rise (6b119f7), #114 edge bollards (6494ba2), 2026-10-21; #109-#112 earlier.
## Open PRs (into claude/look-options; the hygiene agent merges on green with --match-head-commit)
- #115 stadium past the baby's edge + landmarks stream first + plaza pavement stops at the kerb + two fixture fixes
  (swipe check uses the nearest office tower; tank standoff proven with the kaiju standing still), head ac4a0bd.
- #116 b2-30/b2-29: staged start behind a loading screen, streaming stops on quit, hide-then-quit, head 87bf093.
- They conflict in BuildingStream._ready: keep b2-30's staged body and #115's `_landmarks_first(_rest)` after the
  now/_rest split, plus `_landmarks_first` and `queued()`.
- Build 3: CI run 39439422222 dispatched from claude/b2-30-run-start-freeze (look-options + #116; no stadium move).
  Smoke the exe, put it in C:/Users/DANTE/Documents/GitHub/Kaiju-Builds/, 5-line note (draft notes/phase-a-audit.md;
  line 5: the edge marker and the freeze fix are in, the stadium move follows).

## NEXT
1. Build 3 to him. As builders report: QC (2x crops, clips at game speed), open PRs in order (cap 3), merge on green.
2. Phase B: when the phase-b boards pass QC, ask him b2-19 and b2-20 (AskUserQuestion, labelled images first).
3. Director question at Phase C start (phase-maps.md): b2-4 "effortless carving even for a baby" vs D-091. Options
   A effortless + size shows in bite size (rec), B floor the slowdown (<=2x), C keep D-091, fix feel with VFX. Also drop
   VISION.md:26-27 tier-gate sentence (stale since D-091). Then b2-5 varied collapse directions.
4. Follow-up from kerb-fixes.md: 2-12 walker nodes of ordinary blocks lie in a road (untraced).

## Findings this session
- sim "a swiped tower topples sooner" and military "tanks hold standoff" went red from the stadium move (fixture luck:
  brick tower nearest; autoplay lingered at the old stage-2 stadium, 61 -> 0 samples): fixed in #115.
- Far landmarks drew as office boxes until streamed in (BuildingStream stand-ins); captures shot them at 4 frames.
- Swapping files in a worktree while its suites run poisons the run: never do it; use another worktree.
- Local `python -m gdtoolkit.linter` must run from the worktree root to read .gdlintrc (max line 100, max 4 args).
- Rulebook (2026-10-21): never serialise behind a diagnosis ("man youre so slow, why are you getting nothing done").
- Two long-running Godot prof.gd processes (tools/tmp_wp7, PIDs 925029/929069) are not ours: carve-wp7 worktree kept.

## Tools
- mog.sh in lead 9 scratchpad (07ae5487.../scratchpad/mog.sh <pr> <full sha>); copy it to yours.
- Captures: tools/capture/capture_landmarks.gd (--tier=, waits for the stream), capture_shaders.gd; override.cfg first.
- Native dll for local runs: copy Kaiju-Incremental-wt/carve-play/native/bin/*.dll into native/bin/.

Lead = "Kaiju: LEAD 9". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file. playbook: nothing new.
