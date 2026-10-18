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
