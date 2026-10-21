# Lead handoff, 2026-10-21 (lead 10; CLI session 1df8b1cf, registered in ~/.claude/context-guard-leads/)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then the notes folder below. Director's /goal: playable build with building carving first draft.
## Plan = docs/ROADMAP.md "Post-demo plan" phases A-H; research picks "R n.m" -> docs/research/2026-10-21/ (01-24).
## Comments: docs/roadmap/2026-10-20-build2-playtest.md, 2026-10-20-director-comments.md, 2026-10-21-director-comments.md.

## Director state: AFK until about 07:30 local 2026-10-21: "the gpu, cpu and ram are all yours ... please continue
## working until usage runs out". Subagents allowed, up to 8 (RULEBOOK Kaiju exception), lead drives.

## Notes folders
- NEW (lead 10's agents): C:\Users\DANTE\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_df2c2989-951e-4b20-9998-9c23b0a37f42\
  BRIEF-COMMON.md = the shared rules every subagent reads; each agent writes <task>\handoff.md at milestones.
- OLD (lead 9's agents): ...\local_cf0b00c9-bc39-4198-aaf9-942340291b1a\ (research, phase-b boards, rubble logs).

## Director is BACK at the PC (from ~03:30; plays League at times: focus guard blocks windowed Godot -> CI captures).
## Team (lead 10's subagents, die with this session; re-brief from NEW notes <task>\handoff.md):
- prs (Sonnet): PR queue, squash-only (`gh pr merge N --squash --match-head-commit`), cap 3: parse-step 1605c88,
  light-pool, audio-duck, tentacle-substep, graphics-presets 9f37429 (+D-109 lead Medium 4K +6.5%), bridge-land 2ceb079
  (QC PASS), kaiju-double 47ac4da (QC PASS), later walkers-on-pavement, turn-weight, ci-sim-split (after turn-weight + b2-3).
- parse-step: turn-weight: military fixture fixed (42a3a99); tank threat fell 41-50% with the arcing walk -> fixing
  FiringPosts to lead the target (bar within 15% of base 4e401c6, two variants max). Sim split green, re-timed shards.
- phase-b: b2-20 boards in NEW notes phase-b\ pass lead QC; clip rendering -> then ASK the director b2-20.
- walkers: deterministic diagonal fill, then comments #17 emerge facing the city + shoreline + wider river (claude/emerge-shore),
  then R 6.1 no-empty-space suite.
- rubble3: b2-3 part 3 worst step 71-79 ms (bar met), pushing; then D-110 destructible slabs (claude/rubble-break).
- view-spikes: fall_land 349 ms + debris queue (claude/view-spikes). bridge agent -> walk m2 (claude/walk-m2 off turn-weight).
- skyline: prototype background kaiju rampage + burning skyline (comments #16), off by default, stills+clip for his yes.
- Next: fire research (comments #15, ROADMAP E) when a slot frees; insectoid/cephalopod double voxels follow-up.
## Merged since build 4: #120 #121 #122 #123. Decisions today: D-107 voxels, D-108 lightning, D-110 destructible slabs.
- Worktrees: ~50 vs cap 12; safe ones (hygiene, hygiene2-5, ci-balance) need --force, refused: ask the director.

## Merged 2026-10-21: #113-#119. Build 4 = Kaiju-Builds/carve-build4-6cc9c77 (smoke PASS 03:06; contains #115-#118).
## Docs pushed: da19852 roadmap H mortars + mecha (R 23, R 24); b163f75 D-108 lightning breath, STATUS refresh.

## Phase B, for the director when he is back (ask-the-director: images first, one question each)
- b2-19 (voxel count half/today/double): boards in OLD notes\phase-b\ PASS lead QC. Ask with b2-19_1/_2 (game camera)
  and _6/_7 (close), plus the cost line: double unplayable (5.6 fps, 13 s stall), half no cheaper, at game camera nearly
  alike. Recommend B today.
- b2-20 (voxel vs smooth): ask only after the phase-b agent's fixed boards pass lead QC (2x crops face/jaw/cars).
- Other open director questions: end of ROADMAP "Post-demo plan" (now includes H finale shape + mecha concept, R 23.1).

## NEXT
1. As each agent reports: QC (verify branch sha exists, read evidence, 2x crops/clips), hand ready branches to hygiene
   for PRs (max 3 open), refill the slot: R 6.1 no-empty-space suite (after walkers lands), R 5.6 headless parse step,
   then Phase C/D items (b2-4 effortless carving needs his D-091 answer first).
2. Director back: build 4 lines, then b2-19, b2-20, Phase C start question (b2-4 vs D-091).
3. Build 5 once #120 #121 light-pool + the "Any phase, now" branches merge.

## Findings
- Seed-sensitive checks (swipe topple, tank standoff, tank crab) flip when the city or walk changes: probe the unit,
  fix the behaviour or re-pin the fixture, never the threshold.
- Release smoke must run from the repo root (relative --script path); from the build folder it says File not found.

## Tools
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detached; commit docs [skip ci], push HEAD:claude/look-options).
- Release smoke: cd repo; APPDATA=<scratch> godot_console --headless --main-pack <exe> --script tools/release/demo_smoke.gd.
- Native dll for local runs: copy Kaiju-Incremental-wt/carve-play/native/bin/*.dll into native/bin/.

Lead = "Kaiju: LEAD 10". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file. playbook: nothing new.
