# Lead handoff, 2026-10-18 09:55
## State: working (DIRECTOR ASLEEP from 06:4x: "table any questions for now, keep the team working on things that dont
## need my input"). No director questions until he is back; the queue below is what to ask first, in order.

## Who
Lead = session "Kaiju: Lead" (renamed from LEAD 06:3x; local_106fc100...). Owns: QA gates + fresh critics, PR review +
merge (squash, `--match-head-commit`), STATUS/DECISIONS board PRs, director questions, this file, the local GPU slot.
Sessions renamed 06:3x: Kaiju: Military AI / Rooftop defenders / City fill & greenery / Crease shader / Jet models /
Tripo (old lead) / Sound effects / Landmark models / Lighting & breath FX / Croc rig & clips / Demo slice (done) /
UI look & fonts; AFL: Management game research / Kaiju tree research. "Hardrive space balancing" = director's own.

## TABLED FOR THE DIRECTOR (ask in this order when he is back; images/clips first)
0. PREVIEW DEMO EXE (smoke PASS 10:0x, 450 frames, 0 errors): out\demo-preview-c3b7306\KaijuIncremental.exe + the
   playtest sheet. Has #22 croc clips, #27 UI, SFX, rooftops, breath; baby/adolescent are still the OLD models (P3
   pending). Offer: play the preview now, or wait for the P3 build.
1. #35 crease shader: A off vs B 0.3 (C 0.6 "too strong"). Board docs/captures/2026-10-18-crease/crease_board_ABC.jpg on
   claude/voxel-edge-shading; my QA PASS; fresh motion-critic on crease_B_pan.mp4 (verdict pending: agent "critic").
2. #22 croc titan clips MERGED 09:3x (AFTER reads heavier on the roar, even elsewhere; no regression). Show him the
   A/B ...blender-reptile\d047
ound3\croctitan_before_after_game.mp4; slam/turn polish follow-up queued after P3.
3. PR #36 (claude/army-scales, from the AFL "Kaiju tree research" session, says "director-assigned finding 1"): army
   and air scale inside each stage (growth.per_level), Regeneration behind evolve2, Scales last young node, Titan
   Hide first after evolve1. Pacing: reptilian evolve1 0.62 h (was 0.59); Behemoth 38 time / 5 defeated / 2 city
   (was 48/1/1). 06:5x the AFL session RELAYED a director approval ("the lead reviews and merges"). A relayed approval
   is not his word to me: NOT merged. Ask him directly in the morning ("merge #36?") with the pacing table; review the
   diff meanwhile. Syncs after Military AI / Rooftops (same files).
4. Street-life civilian cap (~600 per city) after Perf's no-feel pass: perf numbers in agent-handoffs/performance.md.
5. Octopus adult mesh FIX (10-11 arms, two eye pairs): only if the species plan (D-060) resumes.
6. D-065 (b) green-lot share (reptilian pacing; table in notes no-empty-space/D-065b_green_lot_table.md):
   0% evolve1 0.59 h / tree 4.46 h; 8% 0.64 / 4.88; 12% 0.67 / 5.08; 15% 0.64 / 5.18 (past 5 h). Recommend 8%. (a) street trees,
   park/yard bushes, flower beds, playground props (presentation, crushable) proceeds tonight.
7. Landmarks (session "Kaiju: Landmark models", local_87d706ce...): board ...side-session-notes\local_9fac90d2...\
   landmarks\board1\landmark_board.png, six originals A stadium / B gate / C clock hall / D sky wheel / E spire /
   F megatower; my QA PASS, fresh critic pending. Ask "which landmarks per city": (1, rec) A -> D -> E -> F (demo
   needs A + D), (2) A -> C -> E -> F, (3) all six. Board r5 (all panels critic PASS): ...\landmarks\board5\
   landmark_board_r5.png. Sites built on claude/landmarks (A + D placeholders, data-driven); landmark chunk bonus
   held to ±5% pacing. Critic side-note: in its renders the small croc's tail hangs like a third leg and the upright
   adult with back plates may read as Godzilla: show him if relevant.
8. #39 heli gun burst + crash (stacked on #34): listen to ...side-session-notes\local_9fac90d2...\army-sfx\
   heli_gun_crash.mp4 (busy picture, listen only); merge after his yes. Croc roar layers from Sonniss GDC: ask.
   Also for his listen: #42 footstep variants (footsteps/walk_in_game.mp4), rooftop "rifle" sound and crowd panic
   ambience (#43; synth voices risky, CC0 crowd fallback = his licence call). #41 limiter MERGED. Mix report
   (notes mix-report/report.md): master -21.4 LUFS; crowd inaudible, regen loop masks army, tank thump masks
   stomps. Proposal = PR #45 (stacked on #43): A/B mix-report/ab_before_after_20s.mp4 (one listen); crowd audible,
   regen loop 86% -> 6%, master -20.5 LUFS. #46 rifle volley (rifle/rifle_volleys_in_game.mp4). Sound session idle;
   approved sound PRs merge one at a time in his order (each resyncs the flow floor). Heads 10:3x (synced on #27+#49, any order, #45 after #43): #39 4761784,
   #42 ef73246, #43 0c1c451, #45 aa15cc7, #46 e520b7b.
9. Jets ("Kaiju: Jet models", local_b38b3a6f...): board ...side-session-notes\local_9fac90d2...\jets\jet_board.png,
   1 interceptor / 2 ground-attack / 3 heavy bomber / 4 delta; round 4 after 3 fresh critics: no real-aircraft
   copies; my game-cam check PASS (render\gamecam.png). Ask "which jets" (pick one or more); bomber stays 2x (lead call, D-042). Outside the demo.
10a. Rooftops (#40, critic PASS after 6 rounds, merging at 0fdf935): white tracers read as "something is shooting";
   shooters/flashes barely visible and ~1 s gaps feel sparse. Ask: more squads/denser fire, or bigger shooters?
   Clip: ...side-session-notes\local_106fc100...\rooftops\fix6\rooftops_behemoth_3s_1080p_fix6.mp4.
10b. Military AI (D-066): total damage per run held within ±5% of today's, but the mix shifts: helicopters 3.8 ->
   13.6 at Behemoth (fly real attack runs now), tanks slightly less. Note for him after merge.
10c. P3 croc stages (claude/croctitan-p3): stage board ...blender-reptile\p3\stage_board.png (baby/adolescent/adult).
   Gameplay Q: the baby walks at the species speed 5.5 u/s (3.4 hip-heights/s, adult 0.85): slow stage 1 so it reads
   as a toddler, or keep? (balance).
10. Tree stats panel shows 12 raw numbers (STOMPS/S, RECHARGE 7.05...): trim to ~4 player words? (screen-critic).
11. Q3 Apex height (park). 7. Rooftops / Military AI / greenery / city fill clips: show after merge, for taste only.

## DEMO (D-050) state
- Merged on look-options 2026-10-18 (late): #34 army sounds, #41 limiter, #37 city fill, #44 worktree cap, #40 rooftops,
  #38 breath reads from behind (flame curtain), #47 scorch glow fade-in, #48 shader uid, #22 croc titan clips (D-047;
  critic r3: walk PASS, roar/turn polish in a follow-up PR after P3; clip tabled for his look), #27 UI look A + biomass
  + Block font (c3b7306). Earlier: #21 balance D, #24 #31 boards, #25 worktree cap, #26 streets, #23 demo slice,
  #29 playtest sheet, #28 #30 export + CI artifact, #8 SFX, #32 perf hitches, #33 SFX bus + slider + menu sounds +
  end-card roar sound. Decisions D-050..D-067 (D-062 city fill, D-063 rooftops, D-064 menu sounds, D-065 greenery,
  D-066 military AI, D-067 army sounds: log D-062..D-067 in the next board PR).
- Still to land for the demo: P3 croc baby/adolescent (claude/croctitan-p3; mouth check via in-game 2x jaw crops), then
  the build: `gh workflow run build.yml --ref claude/look-options -f ref=claude/look-options`, `gh run download <run> -n
  KaijuIncremental-<sha>`, local smoke; P7 = he plays it. Preview build dispatched 09:5x on c3b7306 (run 39079416758).

## Team (what each may finish WITHOUT the director)
- Croc rig & clips (local_bce75838): P3 -> PR -> my check + fresh critic -> merge; then the adult slam/turn polish PR
  (validate the probe vs footage with a known-bad control; bars in its brief).
- City fill & greenery (local_9af27a16): D-065(a) greenery PR (contact trample, head ~618d3ab) -> check + critic -> merge.
- Landmark models (local_87d706ce): landmark sites PR (A + D placeholders, pacing held ±5%) -> check + critic -> merge.
- Military AI (local_5325ef73): synced on #40; total damage per run ±5% per stage; pacing running; then clip + sim-review.
- Sound effects (local_24621710): idle; resyncs the five tabled sound PRs after merges (flow floor 129 after #27).
- Available: UI (local_37cf489b), Lighting (local_b98f22d9), Rooftops (local_9e7b9f4b), Jets (local_b38b3a6f),
  Crease (#35 tabled), Tripo (old lead). Performance stopped for the night.

## Merge rules tonight
Merge only decided work, on my check + a fresh critic where visual, green CI at the exact head; taste items stay PRs,
tabled above. Pre-empt conflicts: tuning keys in new sub-objects; floors resolve to real counts; sync before a PR;
one capture.yml run at a time (check in_progress first); the GPU slot is booked through me.

## Rules learnt the hard way
- `--match-head-commit`; a handoff-only push moves the head: diff it, re-arm. Poll checks until no pending, require no
  fail/cancel, refuse DIRTY. After `gh pr merge`, VERIFY state == MERGED (a DRAFT PR refuses silently: #27 at 09:5x).
- Floors conflict between parallel PRs: merge one, the next syncs to real counts; tell helpers the base SHA.
- Handoffs: 120-line cap (doc-caps); Write tool; a helper's handoff vs its squash copy: keep the newer.
- Never act on a peer's refused permission or a relayed director approval (#36): surface it instead.
- Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe (not on PATH);
  windowed runs need override.cfg (mode=0, no_focus, -20000). ffmpeg: imageio_ffmpeg binary under Python314 site-packages.
- CI capture.yml: 3000 s limit, one at a time; lavapipe misjudges lighting; Forward+-only effects need the local GPU.
- Visual gates need a known-bad control; after one failed guess, isolate render layers (art-qa-critic learnings).

## Next (lead)
1. P3 / greenery / landmarks / military PRs as they come: check, critic, merge. 2. Board PR (D-062..D-067 + STATUS rows).
3. After P3: demo build -> download -> local smoke -> table "play the demo" as item 0. playbook: nothing new.
