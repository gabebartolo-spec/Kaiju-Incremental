# City-calm handoff, 2026-10-19
## State: awaiting lead (PR #88 river emergence open; merges after D-091; full suite on the look-options merge running)

## Task
Role city-calm (greenery session, local_9fac90d2). Lead: "Kaiju: LEAD" (local_106fc100).
Jets / army ramp: local_b38b3a6f (told the event name "kaiju_emerged" and PR #88).

## Open work
- **#88 D-083 river emergence + south-edge fix**: claude/river-start into claude/look-options.
  Worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/greenery (now on this branch).
  Commits: 4b6c733 river, 77a952d south extension (reverted in 9daef55), 9daef55 bank park + wade
  to the city bank, 50992f9 canal look (quays, bridges, looks.json "river"), f5cc221 merge of
  look-options (tuning conflict: wheel anchor [10,-56] + rubble_bonus 1.5).
  - city 33/35: the 2 spawn-view failures (seed 98765, stages 1-2) are the tier gate D-091
    removes (croc-contact-dash). Lead: keep the check strict, merge #88 after D-091.
  - Needs a fresh kaiju-sim-review reviewer (the lead names one).
- **#55 greenery** (claude/greenery, b037f69): r15 PASS; lead merges after the demo exe.
  Push nothing; only resolve Auto-fix conflicts if asked (merge, never rebase).
- **D-075 green lots** (claude/green-lots, 4446f21, built on #55): post-demo PR into
  look-options after #55 merges; needs a fresh sim reviewer; pr_d075.md draft in scratchpad
  (pacing and stills placeholders). Ask the lead about deleting claude/green-lots-red.

## How the river works
- sim/city_river.gd CityRiver.mark (in CityGen.map): row just south of district 0's ring line =
  "river" at every stage; the row past it = "park" (far bank). Both keep "was" so generate still
  draws and drops their lots (growth invariants hold). plan: river (z band), river_spawn (axis),
  river_bank (2 m onto the city side).
- sim/emergence.gd: started only by Rampage.setup; rise 2.5 s, then wade to
  clamp_to_arena(river_bank), then emit kaiju_emerged. Holds clock, stomps and army until then.
- scenes/river_view.gd: splashes. scenes/city_ground.gd _river: one canal per run of river
  blocks, bridges at street gaps (<= avenue_width), quays.
- Tests: tests/lib/city_river.gd (RiverStart), tests/lib/city_spawn_view.gd (SpawnView:
  no stand-in and no unbreakable building within camera reach of the rise or bank point).

## Evidence (notes river/)
- run_tests_full2.log (pre-look-options merge): all pass but city 33/35 (D-091).
- pacing_river.log vs pacing_base.log: evolve1 0.26 h both; evolve2 1.42 vs 1.59 h.
- river_stage1.mp4 (emerged 3.12 s), river_stage2.mp4 (2.87 s), frames _t*.png, before/, after/.

## Machine notes
- After a run on another branch, run a headless --import before windowed captures (the class
  cache goes stale: "Identifier CityRiver not declared").
- Clip runner: scratchpad river_clips.sh (needs override.cfg written first; removes it at the end).
- gdlint is `python -m gdtoolkit.linter`; ffmpeg via imageio_ffmpeg.

---
(from look-options, kept)
# City-calm handoff, 2026-10-19 02:30
## State: awaiting lead (#55 r15 pushed at 7154f43; lead's own 2x check, merges after the demo build)
## NO LOCAL GODOT (director, via lead): no headless or windowed runs until the lead lifts it;
## verify on CI only (tests.yml on push, capture.yml).

## Task
Role city-calm (helper). Lead: "Kaiju: Lead" (local_106fc100). Anything sim goes to the lead.
- DONE: #26 calm streets (D-054), #28 export-windows, #30 ci-export, #37 no empty ground
  (D-062), D-065(b) green-lot table (lead), Landmarks city_gen review.
- DONE: PR #66 collapse-cap MERGED (329e708). Worktree removed; local branch claude/collapse-cap
  is left (squash-merged; `branch -D` needs the lead/director's OK). POST-DEMO (lead): sim
  Structure._topple_check rounds an overhang under 0.005 cells to a zero dir; FallMotion covers it.
- NOW: D-065(a) greenery + body trample, PR #55. Lead r14: core passes, no more critic rounds;
  numeric tweaks only, then the lead merges after the demo build on its own 2x check.
  r14 tweaks: puff peak 0.30 by f3, hold to f5, linear fade to 0 by f29 (Fx PUFF_*); leaf
  debris 60ae43 (-25% sat/val); leaves start anywhere inside the crown + random side spread
  (tree_leaf_spread 0.6); leaf speed tree_leaf_speed 2.5 (~150 px flight); tree debris casts
  no shadow (DebrisField.shadows). capture_green --log-props prints puff alpha per frame.
- NEXT: D-075 = D-065(b) at 8% green lots, its own PR after #55 merges: city.green_lot_share
  0.08 in CityGen/CityLots (data); parks/gardens/playgrounds/plazas spread so no building is
  more than ~2 blocks from one; crushable; pacing table near evolve1 0.64 h / tree 4.88 h;
  kaiju-sim-review packet; city checks failing first. Draft: notes greenery/D-075_packet_draft.md.
  city_gen.gd is at 399 lines: the green-lot pass needs a new sim file.

## Branch and commit
claude/greenery, worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/greenery,
PR #55 head: see git log (synced with look-options after r12). Stray local branch claude/greenery-before:
delete when allowed.

## What #55 does
- scenes/city_greenery.gd: street trees on every avenue/street kerb (city-wide spacing), park
  garden, playground, front-yard hedges. All decor props, all crushable.
- scenes/city_decor.gd (397 lines, cap 400): body trample in _process. Every prop whose base
  is under the kaiju's ground box (scenes/kaiju_footprint.gd, from the kvox sculpt) goes down.
- scenes/prop_field.gd: a tree is crushed in place (lead, rule 8 after ten topple rounds): a
  pale stump (city.stump_color) stays, the cells above are hidden, 1 in 4 leaf cells and every
  bark cell go to PropField's leaf_field / bark_field (DebrisField, size_scale/lift knobs; the
  decor adds them), bark dark brown, scattered at spawn, flung toward the camera; drained before
  they process (contact frame). Stump: bark sides, warm cut top. Fx.tree_puff: soft unlit radial
  sprite, 30% peak in 2 frames, gone <1 s (footfall puffs vanish in the smoke centre clearing).
  group["origins"]/["keys"] are kept because headless MultiMeshes keep no transforms.
- tests/lib/city_trample.gd: tail tree goes down; crushed tree leaves stump + debris same frame.
  city floor 53.

## Evidence (notes side-session-notes/local_9fac90d2-.../greenery/)
- r14/: trample/clip_720p.mp4 + lossless clip.avi (from f0), fall_strip.png, contact_seq_2x.png,
  stump_puff_bark_3x.png, pair_r14_2x.png, samples.txt (from the avi), proplog.
  r12/stump_accounting_2x.png (tree 643's stump behind a standing crown).
- city_red_r11_crush.log (6 FAILs, debris off); run_tests_r16.log (full suite, r14 code).
- Older rounds r9-r13 failed. Sample the lossless avi: mp4v bleeds colour on small pieces.

## Next
1. r15 is done (notes greenery/r15/: strip_f0_f36_2x.png, puff_alpha.txt, samples.txt,
   stump_f0_f3_4x.png, flight_*/ leaf-flight runs, trample/clip). Lead merges #55 after the
   demo build; keep it synced (merge origin/claude/look-options, floors = real counts, CI only).
   Then remove the greenery worktree and start D-075.
2. Stomp shockwave tan crescents (rampage.gd:177) are not #55's; the lead excluded them.

## Rules learnt the hard way (under 10 lines)
- Branch off origin/claude/look-options; confirm the worktree exists before git commands.
- Lint before push: python -m gdtoolkit.linter AND gdtoolkit.formatter --check.
- Headless MultiMesh keeps no instance transforms or colours: tests read a CPU mirror.
- Never edit files under a running suite; other sessions share /tmp, read your own log.
- Local windowed Godot: no_focus override.cfg first (Write tool), removed after.
- Night/dusk lighting darkens debris and smoke: sample pixels at game camera before sending.
