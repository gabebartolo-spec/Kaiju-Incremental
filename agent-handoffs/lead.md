# Lead handoff, 2026-10-21 late (lead 10; CLI session 1df8b1cf, registered in ~/.claude/context-guard-leads/)
## Successor: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then the notes folder below. Director's /goal: playable build with building carving first draft.
## Plan = docs/ROADMAP.md "Post-demo plan" phases A-H; research picks "R n.m" -> docs/research/2026-10-21/ (01-24).
## Comments: docs/roadmap/2026-10-21-director-comments.md (#1-#46 today; #45-46 minimal HUD, #33 neck approved).

## Director state: at the PC, often gaming. Clips/captures render on the LOCAL GPU always (RTX 4070 SUPER; off-screen
## no_focus override.cfg, --windowed; two calls: write the override, then launch) until he says pause (~/.claude/focus-pause).
## Up to 2 headless Godot per agent. Never a visible window or dialog. Subagents up to 8 (RULEBOOK Kaiju exception).

## Notes folders
- NEW (lead 10's agents): C:\Users\DANTE\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_df2c2989-951e-4b20-9998-9c23b0a37f42\
  BRIEF-COMMON.md + RULES-NOW.md = shared rules; each agent writes <task>\handoff.md at milestones.
- Nimbalyst mailbox: C:\Users\DANTE\Documents\Nimbalyst Tutorial\kaiju-mailbox\ (to-nimbalyst tasks, to-kaiju results).

## 2026-10-22 evening: STATE FOR THE SUCCESSOR (lead session "Status check", hand-off at 500k)
- Base = origin/claude/look-options = main; squash-only repo: the base moves on every merge. Old branches are rebuilt
  as own commits cherry-picked onto the newest tip; an OPEN PR is synced by MERGING the base (never rebase/force-push).
  Builder rules file: C:/Users/DANTE/AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental--claude-worktrees-status-check-b96b26/b2b0bc5b-915b-4abe-b67a-dbc9a0712bcb/scratchpad/WAVE1-COMMON.md (copy it before this scratchpad goes; it holds the rules + rulings).
- Merged today: #147 crowds 6x, #148 fade/light scans 4-6x, #151 audit-shared (ae9ac939).
- Open PRs (cap 3): #149 turn (claude/turn-weight-v2 907a4ac3; critic round 2 FIX sent as LAST round, lead QCs:
  yaw arrives in 3 bursts f232-273 -> one ease curve, bar: no frame step > 25% of peak yaw rate; capture camera pulses
  ~15% -> smooth follow; walk start ramp >= 8 frames; then director feel gate). #150 camera A (claude/camera-growth-v2
  cbb885a9, base merged; on critic fixes; full suite then 4K clip; lead QCs, then director look gate). #152 fire spread
  (claude/fire-spread b8fb2faf; sim review PASS; clip fire_spread_r0.mp4 with a fresh motion critic; then director look).
- Waiting for a PR slot: claude/audit-sim c839b111 on OLD base 95f01083: rebuild on the tip first (city code moved in
  #151), then a sim-review reader (scanner gap: complexity_ratchet.py misreads multi-line signatures: a follow-up).
- Subagents running at 18:30 (die with this session; resume from worktree + handoff): city-memory (full suite, then
  push claude/city-memory-v2), clumsy-army (damage probes, then suite + clip), camera, turn, explosions
  (claude/city-explosives-v2, suites), ui-art (REDO as bold flat 2D SVG icons per director, yellow band <= 6 px, icon
  >= 80% of ring; 3D renders rejected: "those icons look horrible"), drift-audit reader (scratchpad/drift_audit.md:
  content an agent added without a decision -> one director question per item).
- PARKED by director: perf-tiles (claude/perf-tiles f570ba2e, "Park it": 37-168 px/4K frame differ, no speed gain shown).
- D-135: 3 growth steps, one per croc body; the agent-invented Apex Titan step is cut (evolve3, 4th city/army/air row;
  top skills + bomber move to the adult city). Not started: a growth builder, after the drift audit.
- Monitoring (director #73): ~/.claude/tools/stall_watch.sh label=transcript=worktree per helper, re-arm after each flag
  (args in scratchpad/watch_args.txt); every Godot run under timeout (2 hangs today on script errors).
- Wave 2 not started: intro (claude/intro-cinematic), rubble (Opus; claude/rubble-break), dash (claude/dash-burst),
  UI (claude/ui-redesign; first-run controls card goes per #46). Then sky and sea life (#64-66), trains (#69), bonus
  buildings (#70), dogs escape (#68), birds scatter (#71), landmark stable (D-133).
- Director rulings 2026-10-22: comments #55-75, D-132 (Itch 1.0 demo invite-only, when reptilian stage 100%), D-133
  (landmark stable ~12, 3/stage by seed; 8 new; Tripo models made carvable), D-134 (Tripo 9000 today), #60 all
  CPU/GPU/screen/Godot slots ours. RULE: helpers on Sonnet unless complex. PC piloting allowed.
- Tripo: icons modelled (six-view PASS): ~/Downloads/kaiju_tripo/hud_croc_head_c9b2b460.glb, hud_dash_foot_ab9504ce.glb
  (130 cr; balance 18985 = 8870 of today's budget left; privacy "Sharing Only"). Landmark concept refs: 32 free images,
  board C:/Users/DANTE/AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental--claude-worktrees-status-check-b96b26/b2b0bc5b-915b-4abe-b67a-dbc9a0712bcb/scratchpad/landmarks/landmark_refs_board.png (copy also ~/Downloads/landmark_refs_board.png). Lead flags: B1/B3/B4 near-copy
  Sydney Opera House (B2 original), H3 cropped, E4 plinth, D3 "DINER" text, coaster track thin. A fresh critic is
  reviewed it: FIX. Clean: A3/A4 (tower only, drop cables), C1/C2/C4, D4, E1/E2/E3, F1/F3, G1, H1/H2/H4. Regenerate B (original,
  not Sydney), A (whole tower in frame), F (no planes: they fly in later); all prompts: no plinth/water/ship/text/flags/
  vehicles, whole structure in frame. Then ONE board to the director (pick one per row), then HD models (65 cr each).
- Process notes: worktrees removed today: 9 merged + perf-crowds + perf-scans (leftovers in
  Kaiju-Incremental-wt/_leftovers-2026-10-22); ca2-base (clumsy-army temp) still to remove. Downloads: Tripo/browser
  saves may sit as complete .tmp files (GLB header length = size) when the Save dialog is behind textinputhost.
  rule-check.py returned no answers (0/14): the Sonnet rule is recorded but not proven.

## Ruled follow-ups, not started (each brief names its ROADMAP item + decision, per the rulebook)
- D-137 Anti Kaiju Taskforce BEFORE the demo: from the adolescent city; agents with jetpacks grapple onto buildings
  only; frost grenades slow the kaiju; railguns charge visibly then hit hard. Ask him visuals (agent look board) first.
- D-135 growth rework: drop evolve3 and every 4th row (growth.stages, city.districts, rooftop tables); ultimates
  r_beam/i_brood/c_ink move off evolve3; jets/bomber into the adult city; re-split the tree rings over 3 steps.
- D-136 code: cut the breath camera swing; rename "Atomic" to Lightning/Thunder (D-112: species.json, r_beam,
  stat_text); remove BRANCH/CAPSTONE labels from the tree (copy rule). Headlines: 9 lines sent to him, await his edits.
- Narrative (#76) after the demo: briefing cards before each city/after each evolve + optional bonus goals per city.
- Drift audit table: scratchpad drift_audit.md (copy before this scratchpad goes).
- Icons: flat SVG set on claude/ui-art 1cbabb64 (ring lines for ui-redesign in its handoff); critic on board2, then
  him; then apply on claude/ui-redesign and open its PR.
- Fire PR #152: critic FIX sent (collapse is a one-frame swap, roof fire too small: use burn_chunk emitter, clip
  framing, measured timings); last round, lead QCs.

## PR queue after QC (max 3 open): #144 turn-weight, emerge-shore, camera-growth, intro-cinematic, rubble-break,
## city-explosives, croc-neck, dash-burst, ui-redesign, city-memory, clumsy-army; capture-native (no speed-up: keep?).
## Audit P4 (scene refactors, pixel-identical) after the croc batch merges. No octopus/insect work until croc ships (D-124).
## After the batch: fire visuals (R 26.5, D-126), then water (R 21; Nym's 013 code map).

## NEXT
1. QC each clip as it lands (2x crops yourself, then a fresh critic; only SHIP reaches him, one decision each).
2. Director questions pending: first-run controls card; stages 2-3 far-box look stills once the camera-led stream exists.
3. Merge passing branches in queue order; Build 5 after the batch.

## Findings
- Seed-sensitive checks (swipe topple, tank standoff, tank crab, growth lots, military retreat 21/24) flip with branch
  changes to city or walk: probe the unit, fix the behaviour or re-pin the fixture, never the threshold.
- A dark patch inside a silhouette may be negative space between parts (jaw vs forearm), not a seam: trace its border.
- Release smoke must run from the repo root (relative --script path).

## Tools
- Lead docs worktree Kaiju-Incremental-wt/lead-docs (detached; git pull --ff-only first; python edits newline='';
  commit docs [skip ci], push HEAD:claude/look-options). DECISIONS.md cap 400 lines (roll to docs/archive/).
- ffmpeg: python -c "import imageio_ffmpeg;print(imageio_ffmpeg.get_ffmpeg_exe())".
- Native dll for local runs: copy Kaiju-Incremental-wt/carve-play/native/bin/*.dll into native/bin/.

Lead = "Kaiju: LEAD 10". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file. playbook: nothing new.
