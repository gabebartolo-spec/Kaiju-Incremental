# Lead handoff, 2026-10-21 (lead 9 stood down at 500k; session local_df2c2989, CLI 07ae5487)
## Lead 10: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then the notes folder below. Director's /goal: playable build with building carving first draft.
## Plan = docs/ROADMAP.md "Post-demo plan" phases A-H; research picks "R n.m" -> docs/research/2026-10-21/ (01-22).
## Comments: docs/roadmap/2026-10-20-build2-playtest.md, 2026-10-20-director-comments.md, 2026-10-21-director-comments.md.

## Director state: AFK ~5 h from about 02:30 local 2026-10-21 (comments #11): "the gpu, cpu and ram are all yours ...
## please continue working until usage runs out". Subagents allowed, up to 8 (RULEBOOK Kaiju exception), lead drives.

## Team: lead 9's subagents die with lead 9's session. Each was told to finish its milestone, push, and write
## notes\<task>\handoff.md. Re-brief from those notes; restart any that has work left as a fresh subagent.
- Notes: C:\Users\DANTE\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_cf0b00c9-bc39-4198-aaf9-942340291b1a\
- hygiene\state.md: GitHub hygiene agent. Standing rule: merge any green PR into look-options at its exact head,
  max 3 open. Queue: #117 (swipe occlusion + tank crab fix e60182b), #119 tree-apart, then claude/stadium-crowd 54f7d27
  (resynced, QC passed), then claude/b2-22-party-facades 71e704e (resynced, QC passed).
- rubble\HANDOFF.md: b2-3 slow frames part 2 (claude/rubble-cap). Bar: worst sim.step < 100 ms. Plan: spread
  promotion 1/step, skip wasted fast settles, native settle flood if > 200 ms; remove PROF timers.
- walk-motion\handoff.md: milestone 1 = claude/turn-weight mergeable (047574a + look-options; two red checks to
  diagnose: sim swipe fixture, military standoff). Milestone 2 (walk: shoulders/head, stride, footfall, step-turns,
  R 11.1-11.4, 14.1-14.3) NOT started: brief it to a fresh Opus builder.
- light-pool\: claude/light-pool (R 12.1, 12.2). quick-wins\: claude/audio-duck (R 8.1), claude/tentacle-substep
  (R 9.1). handover-fixes\: claude/handover-fixes (R 20.3 dropped inputs, R 20.5 reveal fixed ticks, R 19.1 zoom data).
  walkers\: claude/walkers-on-pavement (walker nodes in roads, off #115).
- research\: topics 23 mecha boss, 24 rooftop mortars in progress; write them into ROADMAP H when done.

## Merged 2026-10-21: #113, #114, #116, #115 (479a15d), #118 (4 CI shards, slowest 9m32).
## Build 3 = Kaiju-Builds/carve-build3-87bf093 (demo smoke PASS, director told). Build 4: when #117 merges.

## Phase B, ready for the director when he is back (ask-the-director: images first, one question each)
- b2-19 (voxel count half/today/double): boards in notes\phase-b\ PASS lead QC (matched sim ticks). Ask with
  b2-19_1/_2 (game camera) and _6/_7 (close), plus the cost line: double unplayable (5.6 fps, 13 s stall), half
  no cheaper, at game camera nearly alike. Recommend B today.
- b2-20 (voxel vs smooth): FIX before asking: smooth kaiju head goes flat (skin bridges the jaw: mesh per bone),
  cars shrink to blobs, idle shots show the kaiju from behind. Destruction stays cubes (honest limit: label it).
  Branch claude/phase-b-boards 8c2e6e2 (never merge); tools/capture/phase_b_overlay.sh.
- Other open director questions: listed at the end of ROADMAP "Post-demo plan".

## NEXT
1. Read every notes\*\handoff.md; QC finished work (2x crops, clips); queue PRs via hygiene; refill slots from ROADMAP
   "Any phase, now" (no-empty-space suite R 6.1, presets R 18.1) and Phase C/D items.
2. Fix b2-20 board, then ask b2-19 then b2-20. Phase C start question: b2-4 effortless carving vs D-091.
3. Build 4 after #117. Board PR: DECISIONS lightning breath (comments #7), STATUS b2-21/29/30 done.

## Findings (lead 9)
- Seed-sensitive checks (swipe topple, tank standoff, tank crab) flip when the city or walk changes: probe the unit,
  fix the behaviour or re-pin the fixture, never the threshold. A first "arrive early" tank fix made it worse.
- b2-3: worst frames are sim.step (settle flood, promote), not rubble; the 823 rubble cap is not wired in the game.
- Subagents die with the lead's session: brief them to write notes\<task>\handoff.md at every milestone.

## Tools
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detached; commit docs [skip ci], push HEAD:claude/look-options).
- Probe pattern: tools/tmp_crab_probe.gd (uncommitted, in .claude/worktrees/agent-abf46f19a3619b8c5).
- Release smoke: APPDATA=<scratch> godot_console --headless --main-pack <exe> --script tools/release/demo_smoke.gd.
- Native dll for local runs: copy Kaiju-Incremental-wt/carve-play/native/bin/*.dll into native/bin/.

Lead = "Kaiju: LEAD 10". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file. playbook: nothing new.
