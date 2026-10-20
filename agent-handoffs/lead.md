# Lead handoff, 2026-10-21 (lead 9, session local_df2c2989, CLI 07ae5487; registered in context-guard-leads)
## Next lead: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then list_sessions. Director's /goal: playable build with building carving first draft.
## Plan = docs/ROADMAP.md "Post-demo plan" phases A-H (research picks "R n.m" -> docs/research/2026-10-21/);
## comments: docs/roadmap/2026-10-20-build2-playtest.md, 2026-10-20-director-comments.md, 2026-10-21-director-comments.md.

## Team (director 2026-10-21: "i will now allow you to use subagents. drive direction yourself"; "up to 8")
- Lead runs up to 8 subagents (Agent tool, builder type, own worktree; RULEBOOK Kaiju exception). Each pushes a
  branch, no PR, reports to the lead. Subagents die with this session: a new lead re-briefs from the branches.
- Running: tree-apart (claude/tree-apart feb34bc: 0 pairs < 2.5 m but drops 8-10% of trees; sent back to MOVE trees,
  within 3%, + before/after captures in notes/tree-apart/) · phase-b-boards (claude/phase-b-boards, never merge;
  b2-19 board FIX sent: match frames at one sim tick, C's patchy glass; b2-20 rendering) · b2-22 finish · stadium-crowd
  (#17 + b2-8) · rubble-cap (claude/rubble-cap: redirected to spread promotion + incremental settle flood; bar worst
  sim.step < 100 ms) · turn-weight (Opus, ~250k: finish, report, stop) · walkers-on-pavement (claude/walkers-on-pavement
  off #115) · GitHub hygiene (merges on green, resyncs, branch/worktree cleanup; then #118 shard balance).
- Queued, needs a fresh builder: walk motion (claude/walk-motion off turn-weight's branch; brief in the 2026-10-21
  comments #4 + ROADMAP D "How (research), walk/turn"; R 11.1-11.4, 14.1-14.3; clips at game speed).
- Notes: C:\Users\DANTE\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_cf0b00c9-bc39-4198-aaf9-942340291b1a\

## Merged 2026-10-21: #113, #114, #116 (636734f), #115 stadium (479a15d), #118 CI 4 shards (slowest 9m32).
## Build 3 = carve-build3-87bf093 in C:/Users/DANTE/Documents/GitHub/Kaiju-Builds/ (demo smoke PASS; told him).
## Open PRs (hygiene agent merges any green PR at its exact head unless the lead says hold):
## - #117 swipe occlusion + tank crab fix e60182b (convoy.gd _onto_axis; attempt 1 "arrive early" made it worse and
##   was reverted; local sim+military green, probe tools/tmp_crab_probe.gd 0 crabs). CI running.
## - #119 tree-apart (resynced 6d0695d). Next PR queued: claude/stadium-crowd 867e006 (lead QC passed).
## Director AFK ~5 h (comments #11): whole PC ours, keep 8 builders busy until usage runs out.
## Builders: phase-b-boards (b2-19 FIX round), b2-22, rubble part 2 (fresh; native flood if >200 ms), turn-weight
## (finishing ~264k, then walk-motion goes to a fresh builder), walkers-on-pavement, light-pool, audio-duck +
## tentacle-substep, hygiene, research (19 camera, 20 set pieces). Research 01-18 all in ROADMAP ("R n.m").

## NEXT
1. When #117 merges, rebuild (build 4 candidate: stadium move + swipe fix + whatever lands).
2. Phase B: when the boards pass QC, ask him b2-19 then b2-20 (AskUserQuestion, labelled images first).
3. Phase C start question (phase-maps.md): b2-4 effortless carving vs D-091 (A rec / B floor <=2x / C keep D-091);
   drop VISION.md:26-27 tier-gate sentence. Then b2-5.
4. Builders' reports: QC (2x crops, clips), PRs in order (cap 3), merge on green; refill free slots from the ROADMAP
   "Any phase, now" line (light distance fade, light pool, audio duck, tentacle substep, no-empty-space suite).
5. Board PR: DECISIONS line for the lightning breath (comments 2026-10-21 #7) and STATUS b2-21/b2-29/b2-30 done.

## Findings this session
- b2-3 slow frames: every worst frame is sim.step (VoxelFrame.settle flood 50-60%, Carving._promote 20-25%); the
  823-piece rubble cap is not wired into the game (only carve-play's CarveCity). Stadium 246 ms = 8 neighbours promote.
- Seed-sensitive checks (swipe topple, tank standoff, tank crab) flip when the city or the walk changes: diagnose the
  tank/building in the probe, fix the behaviour or the fixture's luck, never the threshold.
- Swapping files in a worktree while its suites run poisons the run; lint from the worktree root (.gdlintrc).
- CI shard 2 takes ~24 min (sim 536 s + destruction + growth + military): not a hang; #118 rebalances.

## Tools
- mog.sh in lead 9 scratchpad (07ae5487.../scratchpad/mog.sh <pr> <full sha>); copy it to yours.
- Captures: tools/capture/capture_landmarks.gd (--tier=), capture_shaders.gd; off-screen override.cfg first.
- Release smoke: APPDATA=<scratch> godot_console --headless --main-pack <exe> --script tools/release/demo_smoke.gd.
- Native dll for local runs: copy Kaiju-Incremental-wt/carve-play/native/bin/*.dll into native/bin/.
- Lead docs worktree: Kaiju-Incremental-wt/lead-docs (detached; commit docs [skip ci], push HEAD:claude/look-options).

Lead = "Kaiju: LEAD 9". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file. playbook: nothing new.
