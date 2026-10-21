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

## Director AFK again (~13:00 2026-10-21): "work until usage is empty". Windowed Godot fine while away.
## Team (lead 10's subagents; die with this session; re-brief from NEW notes <task>\handoff.md):
- prs (Sonnet): squash-only queue, cap 3. Merged #124 parse-step, #125 light-pool. #126 b2-3-part3 in CI. Then cells-native
  223f8ba (after #126), audio-duck, tentacle-substep, graphics-presets 9f37429 (+D-109 lead: Medium 4K default), bridge-land
  2ceb079, kaiju-double 47ac4da, view-spikes 32555d9, walkers-on-pavement, turn-weight (HOLD: walk-m2b re-pins 3 seed flips),
  ci-sim-split 39e9f44 last.
- walk-m2b: fix turn-weight seed flips (swipe 0.160 vs 0.161, crush people 0, tanks in range 12<20) then walk-m2 clips.
  Director question later: young stages walk 2.2x/1.9x authored speed (R 11.2: slower young speed vs Blender re-bake).
- parse-step: clumsy army (#18) claude/clumsy-army; ~254k context, hands off at 280k.
- explosives-view: VFX/SFX/models on claude/city-explosives (sim done 971a372; blast numbers first-pass, lead judges clip).
- rubble-break: D-110 + #24/#25 (falling towers break believably on the kaiju) claude/rubble-break.
- walkers: deterministic diagonal fill, then #17 emerge facing city + shoreline + wider river, then R 6.1.
- skyline: background kaiju rampage prototype (#16), off by default. no-random-fire: R 26.1. cells-native: camera growth boards (R 19).
- Director questions when back: camera growth pick (R 19 boards), walk cadence (R 11.2), Suno Pro $10/mo or ElevenLabs Music
  (R 25), fire: spark source for non-breath species + wind fixed or drifting (R 26), background skyline yes/no, blast numbers.
- Decisions today: D-107 voxels, D-108 lightning, D-110 destructible slabs, D-111 look stays voxel. Comments #12-#25 logged.
- Build 5 once the queue lands: dispatch build.yml on look-options, smoke from repo root, Kaiju-Builds/carve-build5-<sha>.

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
