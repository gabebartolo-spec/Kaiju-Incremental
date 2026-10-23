# sim-leak handoff (builder "sim-leak", Kaiju lead's task: ROADMAP "Balance run on GitHub", D-179), 2026-10-23
## State: phase 1 done and sent; phase 2 in progress (probe written, base not yet measured)
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
## Evidence so far
- Base (old sim), probe `--runs=20 --steps=200 --stage=2` (Behemoth, reptilian, 200-step rampages): static 95.0 -> 453.7
  MB (+18.9 MB a run), objects 3918 -> 48253 (+2333 a run), runs 4-20 static +302 MB: LEAK. Base per-run result hashes
  and checksum 77692016 saved in scratchpad simleak/base_s2_200.txt. (Full-length rampages leak far more: carving grows.)
- Base pacing `--species=reptilian --runs=14 --verbose` saved in scratchpad simleak/pacing_base.txt, to diff after.
- Fixed probe, same args, cut short by the second pause after 7 of 20 runs (exit 127 = killed): static 76.2 MB and
  objects 1586 on every run 1-7 (flat; base grew +18.9 MB / +2333 objects a run), and runs 1-7 result hashes equal the
  base's run for run (3359963979, 2453474791, 1602554700, 2863955096, 2827875165, 3774334881, 67706960). The full
  20-run FLAT verdict and the checksum 77692016 compare are still to do. (The first fixed run, with the compile error,
  was killed by the first pause the same way.)
## Paused again 2026-10-23 (director: 30 more min, until about 11:34 UTC): no Godot of mine running; resume on the lead's word.
## Not exercised
GitHub's native settle path (no native binary locally); a full-length Colossus 109-run tree.
## Next (after "resume")
1. bash scratchpad simleak/probe_run.sh new_s2_200 new --runs=20 --steps=200 --stage=2 (expect FLAT, same per-run result
   hashes and checksum 77692016 as base_s2_200.txt); also --no-dispose once (leaks again, same checksum).
2. pacing `--species=reptilian --runs=14 --verbose` and diff against pacing_base.txt (identical lines).
3. tools/run_tests.sh sim (SimDispose checks: alive without dispose, freed after, Rampage frees its sim) and smoke.
4. Fill the numbers into this file, commit by name (new: sim/sim_teardown.gd, tools/pacing_player.gd,
   tools/sim_leak_probe.gd, tests/lib/sim_dispose.gd, agent-handoffs/sim-leak.md; edited: sim/rampage_sim.gd,
   tools/pacing.gd, scenes/rampage.gd, scenes/title_backdrop.gd, tests/run_sim_tests.gd), push claude/sim-leak, report.
   Do not commit the many untracked .uid files the import made.
