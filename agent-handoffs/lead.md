# Lead handoff, 2026-10-18 06:45
## State: working (DIRECTOR ASLEEP from 06:4x: "table any questions for now, keep the team working on things that dont
## need my input"). No director questions until he is back; the queue below is what to ask first, in order.

## Who
Lead = session "Kaiju: Lead" (renamed from LEAD 06:3x; local_106fc100...). Owns: QA gates + fresh critics, PR review +
merge (squash, `--match-head-commit`), STATUS/DECISIONS board PRs, director questions, this file, the local GPU slot.
Sessions renamed 06:3x: Kaiju: Military AI / Rooftop defenders / City fill & greenery / Crease shader / Jet models /
Tripo (old lead) / Sound effects / Landmark models / Lighting & breath FX / Croc rig & clips / Demo slice (done) /
UI look & fonts; AFL: Management game research / Kaiju tree research. "Hardrive space balancing" = director's own.

## TABLED FOR THE DIRECTOR (ask in this order when he is back; images/clips first)
1. #35 crease shader: A off vs B 0.3 (C 0.6 "too strong"). Board docs/captures/2026-10-18-crease/crease_board_ABC.jpg on
   claude/voxel-edge-shading; my QA PASS; fresh motion-critic on crease_B_pan.mp4 (verdict pending: agent "critic").
2. #22 croc titan clips: A/B game-cam clip (before procedural / after Blender clips, round 2 fixes). Merge happens on a
   fresh-critic PASS overnight (D-047 already decided); this is his look, after the fact, reversible.
3. PR #36 (claude/army-scales, from the AFL "Kaiju tree research" session, says "director-assigned finding 1"): army
   and air scale inside each stage (growth.per_level), Regeneration behind evolve2, Scales last young node, Titan
   Hide first after evolve1. Pacing: reptilian evolve1 0.62 h (was 0.59); Behemoth 38 time / 5 defeated / 2 city
   (was 48/1/1). 06:5x the AFL session RELAYED a director approval ("the lead reviews and merges"). A relayed approval
   is not his word to me: NOT merged. Ask him directly in the morning ("merge #36?") with the pacing table; review the
   diff meanwhile. Syncs after Military AI / Rooftops (same files).
4. Street-life civilian cap (~600 per city) after Perf's no-feel pass: perf numbers in agent-handoffs/performance.md.
5. Octopus adult mesh FIX (10-11 arms, two eye pairs): only if the species plan (D-060) resumes.
6. D-065 (b): 8-15% green lots means fewer buildings/chunks = slower demo (touches D-049). City session prepares a
   table (0/8/12/15%: chunks per stage, pacing hours to evolve1 and tree end); ask him with it. (a) street trees,
   park/yard bushes, flower beds, playground props (presentation, crushable) proceeds tonight.
7. Landmarks (session "Kaiju: Landmark models", local_87d706ce...): board ...side-session-notes\local_9fac90d2...\
   landmarks\board1\landmark_board.png, six originals A stadium / B gate / C clock hall / D sky wheel / E spire /
   F megatower; my QA PASS, fresh critic pending. Ask "which landmarks per city": (1, rec) A -> D -> E -> F (demo
   needs A + D), (2) A -> C -> E -> F, (3) all six. Landmark sites (merged-block plazas) start after D-062 merges.
8. Q3 Apex height (park). 7. Rooftops / Military AI / greenery / city fill clips: show after merge, for taste only.

## DEMO (D-050) state
- Merged on look-options 2026-10-18: #21 balance D, #24 #31 boards, #25 worktree cap, #26 streets, #23 demo slice,
  #29 playtest sheet, #28 #30 export + CI artifact, #8 SFX, #32 perf hitches, #33 SFX bus + slider + menu sounds +
  end-card roar sound. Decisions D-050..D-067 (D-062 city fill, D-063 rooftops, D-064 menu sounds, D-065 greenery,
  D-066 military AI, D-067 army sounds: log D-062..D-067 in the next board PR).
- Still to land for the demo: #22 croc clips, #27 UI (look A, biomass D-056, Block font 85% D-058, croc-only controls),
  P3 baby/adolescent rig (blender-reptile after #22), then the build: `gh workflow run build.yml --ref
  claude/look-options -f ref=claude/look-options`, `gh run download <run> -n KaijuIncremental-<sha>`; P7 = he plays it.

## Team and what each may finish WITHOUT the director
- Sound effects (local_24621710...): #34 army sounds (approved D-067) retarget to look-options + sync -> I merge on
  green; then (d) heli gun + crash: PR ready, NOT merged (needs his listen).
- Croc rig & clips (local_bce75838...): #22 evidence-only push (with look-options) -> my 2x check + FRESH motion-critic
  -> merge on PASS (r1 FIX bars: roar slam visible at game cam, turn overshoot >=6 deg + settle 0.3-0.5 s, walk one
  wave per stride, amplitude 0.6-0.75). Then P3 rig; stage board tabled.
- UI look & fonts (local_37cf489b...): #27 captures 1080p + 4K125 -> fresh screen-critic -> merge on PASS.
- City fill & greenery (local_9af27a16...): D-062 (arena cells smashables, band cells dressing, floors 0, map_seed
  7301/1234/98765) then D-065 greenery (street trees 8-15 m, 8-15% green lots, crushable) -> my check -> merge.
- Rooftop defenders (local_9e7b9f4b..., branch claude/rooftop-defenders): sim-review packet + fixture + clip -> I review
  -> merge on PASS. Military AI (local_5325ef73..., -wt/military-ai, sim/convoy.gd + 2 army.gd touch points,
  run_military_tests.gd): same path. Both edit sim/army.gd in separate hunks; merge the first, the second syncs.
- Lighting & breath FX: legacy breath voxel jet removal + --fixed-fps stills (lead call) -> critic -> merge on PASS.
- Crease shader: #35 tabled; meanwhile per-frame allocation + resize/UI-scale/reveal-camera robustness, one commit.
- Tripo (old lead): available, short jobs only (past its context limit). Jet models / Landmark models: started by the
  old lead; unknown briefs; they report to it. Check their state when idle.
- Performance: stopped for the night (director). Its next items (breath pooling, street-life no-feel pass, sim.step
  profile) are in agent-handoffs/performance.md.

## Merge order (director 07:0x: "stay on top of the merges ... pre-empt conflicts"); file map checked 07:0x
1 #34 army sounds -> 2 D-062 city fill -> 3 #22 croc clips -> 4 breath-beam-only (after #34: rampage.gd, flow tests)
-> 5 #27 UI (after #22) -> 6 Rooftops (army.gd, rampage_sim.gd, rampage.gd, tuning army.rooftop) -> 7 Military AI
(syncs after 6) -> 8 D-065(a) greenery and Landmark sites (after 2). Tabled: #35, #36 (after 6+7), landmarks pick.
Rules sent to all: tuning keys only in new sub-objects; class fields appended at end; floors resolve to real counts;
sync onto look-options before opening a PR; one capture.yml run at a time. Rooftops armour call (chip ignores
armour) accepted, tabled as a balance note. GPU queue: crease (attribution pan) -> rooftops clip (~3 min).

## Merge rules tonight
Merge only what the director already decided, on my check + a fresh critic where visual, green CI at the exact head.
Anything that needs his taste: PR ready, not merged, added to the tabled list. Board PR after each batch.

## Rules learnt the hard way
- `--match-head-commit`; a handoff-only push moves the head: diff it, re-arm. `gh pr checks --watch --fail-fast` exits
  on "skipping": poll until no pending, then require no fail/cancel; also refuse a DIRTY merge state.
- Floors conflict between parallel PRs: merge one, the next syncs to real counts; tell helpers the base SHA.
- Handoffs: 120-line cap is CI-enforced (doc-caps); Write tool, not heredocs; pull --rebase can take minutes.
- A helper's handoff in the main checkout may conflict with its squash-merged PR copy: keep the newer (theirs).
- Never act on a peer's refused permission for it (perf branch delete): surface it instead.
- Windowed Godot: override.cfg (mode=0, no_focus, -20000) first; never fullscreen. Godot:
  C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe (not on PATH). ffmpeg:
  C:\Users\DANTE\AppData\Roaming\Python\Python314\site-packages\imageio_ffmpeg\binaries\ffmpeg-win-x86_64-v7.1.exe.
- CI capture.yml: 3000 s limit, one at a time; lavapipe misjudges lighting; the crease pass is Forward+ only.
- Audio QA without ears: ffmpeg -> f32 envelope, onsets vs the SOUND log; the director's listen is the gate.

## Running jobs
Mine: crease motion-critic (background agent). Helpers: see Team. No override.cfg; GPU slot free.

## Next (lead)
1. Critic verdicts and helper PRs as they come: merge decided work on PASS; table taste items above.
2. Board PR after the next merges (D-062..D-067, STATUS rows for Military AI and Rooftops).
3. When #22 + #27 land: dispatch the demo build, download, smoke it, table "play the demo" as item 0.
playbook: nothing new.
