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

## State 2026-10-21 evening: director at the PC (no windowed Godot; CI captures). Design = docs/DESIGN.md (one doc, lead edits).
## Merged today: #122-#135 (parse-step, light-pool, b2-3-part3, audio-duck, tentacle, graphics, cells-native, bridge,
## kaiju-double, view-spikes, no-rubble-fire, carve-no-fire). Open: #3 only. D-109 recorded.
## Team (lead 10 subagents; re-brief from NEW notes <task>\handoff.md):
- prs: preset-caps (shader_keep ratio fix), walkers-on-pavement, sfx-pool, shake-trauma 260aa17 (lead accepted 1.8 deg /
  9.5 px), empty-space-suite, ci-sim-split last; turn-weight held for crush-people.
- walk-m2b: crush-people option A (panic radius by body size + 1 s gawk), bar 10/12 seeds; then walk-m2 clips.
- rubble-polish: claude/rubble-break clip polish + bench + #26 (fallen buildings break against the ground, never sink).
- emerge-clips: claude/emerge-shore, director picked BURST THROUGH the bridge deck; check + CI clips.
- explosions-fix: claude/city-explosives 6fb45b69, CI clips running; then motion critic round 2.
- cells-native: R 19.4 BuildingFade fix (claude/building-fade) then re-render camera boards (claude/camera-growth 8db4122).
- clumsy-army: claude/clumsy-army clips rendering. sfx-pool stood down (shake handoff in notes).
- Director questions left: camera growth (after occlusion fix), walk cadence R 11.2, Suno vs ElevenLabs Music, fire spark
  + wind, background skyline, blast numbers, worktree cleanup permission. Insectoid = brood mother (DESIGN; code still
  has Leap Slam as signature: fix when species work starts).
- Build 5 once the queue lands: dispatch build.yml on look-options, smoke from repo root, Kaiju-Builds/carve-build5-<sha>.
- Context trim done 2026-10-21: RULEBOOK 16.5->13 KB (quotes in RULEBOOK-quotes.md), global CLAUDE.md 4.8->3.4 KB, project
  CLAUDE.md 5.2->3.0 KB, handoff hook 10.3->2.2 KB (last 30 h only), 7 skill descriptions halved, memory 7->2 files.
  Backups *.bak-2026-10-21 beside each file.

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
