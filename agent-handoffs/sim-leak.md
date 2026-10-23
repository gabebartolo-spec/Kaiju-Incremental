# sim-leak handoff (builder "sim-leak", Kaiju lead's task: ROADMAP "Balance run on GitHub", D-179), 2026-10-23
## State: DONE, pushed to claude/sim-leak; the lead opens the PR (all proved locally, CI runs the rest)
## Task
tools/pacing.gd leaked memory per run (GitHub run 39920885597: RSS 55 MB -> 15.2 GB by run 80, about 240 MB a run,
350 MB+ a Colossus run, the 16 GB runner died, exit 143). It blocks #171's D-167 pacing hours. If each RampageSim
leaks, the shipped game leaks every rampage. Pass bars: after 3 warm-up runs static memory <= +5 MB and no steady
object growth over runs 4-20, shown failing on the base first; checksum over the seeded runs identical to the base;
the game frees its sim through the same teardown. No PR (the lead opens it). Branch claude/sim-leak from
origin/claude/look-options (a674fb20).
## Cause (phase 1, no engine)
RefCounted reference cycles, which Godot 4 never frees: RampageSim holds collapse, carving, army_units, powers, air,
brood, body and each holds `sim` back (23 classes have `var sim: RampageSim`); plus rings that need no sim:
Convoy<->FiringPosts, Convoy<->TankSpacing, BodyContact<->Dash; Army->Taskforce->frost/perch/volley->sim;
SpeciesPowers->tentacles/swipe/fire->sim. No signals, no stored lambdas; statics bounded (Content, LandmarkCells._cache
by landmark id, one KaijuSettle); pacing.gd keeps only _cities (<= 4), the tally and marks.
## Fix (no behaviour change)
- sim/sim_teardown.gd (SimTeardown.cut): depth-first over a part's script variables holding a RefCounted; clears every
  reference that points back at a part still on the path (a back edge), so any new back pointer is cut with no edit.
- RampageSim.dispose() calls it. The sim is spent afterwards (parts reach the sim through `sim`): read result() first.
- Callers: tools/pacing.gd (after result(), each run), scenes/rampage.gd (_exit_tree: Main._swap queue_free's the
  Rampage on every screen change), scenes/title_backdrop.gd (_exit_tree; its sim was a local that leaked per title).
- tools/pacing_player.gd (PacingPlayer.play): pacing's scripted player loop moved out verbatim, shared with the probe.
- tools/sim_leak_probe.gd: N seeded rampages back to back, per run MEMORY_STATIC and OBJECT_COUNT, checksum of the
  summaries, exit 0 when flat after 3 warm-up runs. `--no-dispose` shows the old behaviour on the new code.
- tests/lib/sim_dispose.gd (called from tests/run_sim_tests.gd): per species a played sim is alive after drop without
  dispose (the check has teeth) and freed after it; a real Rampage node left in the tree frees its sim.
## Evidence (probe: tools/sim_leak_probe.gd, reptilian)
- Base, 20 runs x 200 steps, Behemoth: static 95.0 -> 453.7 MB (+18.9 MB a run), objects 3918 -> 48253: LEAK, checksum 77692016.
- Fixed, same args: static 76.2 MB, objects 1586 on every run, FLAT (+0.0 MB, +0 objects after run 3); all 20 per-run result
  hashes and the checksum 77692016 equal the base's. `--no-dispose` on the fixed code (8 runs): leaks as the base (+18.9 MB/run).
- Colossus, 8 runs x 400 steps: 78.1 MB / 1586 objects every run, FLAT.
- pacing `--species=reptilian --runs=14 --verbose`: all 24 summary and per-run lines identical to the base's.
- Suites (local): sim 77 checks 0 failures (69 + 8 new SimDispose: alive without dispose, freed after, per species, and a
  real Rampage freed on queue_free); smoke 47/0; check_scripts 470 scripts 0 failed; gdformat, gdlint, complexity_ratchet,
  tuning_keys clean. CI runs the rest (flow suites free Rampages; a test reading a sim after freeing its Rampage would show).
## Not exercised
GitHub's native settle path (no native binary locally); a full-length Colossus 109-run tree (200-400 step runs only);
the game's title/rampage swap by hand (covered by the SimDispose Rampage check, not played).
## Notes for the PR
ROADMAP "Balance run on GitHub" can say the leak is fixed; the pacing workflow can run the tree again. tests/README has no
`sim` row, so none was changed. Untracked .uid files from the import were not committed.
