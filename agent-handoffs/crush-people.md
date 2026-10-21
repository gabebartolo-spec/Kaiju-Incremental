# Crush-people handoff, 2026-10-21 (merge by the clumsy-army builder, lead 10)
## State: available (merge done, pushed; PR is the hygiene agent's)
## Task
Kaiju crushes people it walks into (counted apart from tank run-overs); people under a falling section freeze there;
a young kaiju is noticed late. Original author stood down at 6cab107. This pass: merge origin/claude/look-options.
## Branch and commit
claude/crush-people, worktree ../Kaiju-Incremental-wt/crush-people. Merge commit b26c024 (look-options 8d6d7db).
## What the merge did
- scenes/street_life.gd: crush(at, r, by_tank) -> crush_all(spots, by_tank); #133's single pass kept; each kill adds
  run_over when by_tank. brace() kept; the fall_start event -> brace mapping (was CityView._brace) is now
  StreetLife.brace_fall(event, drop_reach).
- scenes/city_view.gd: fall_start calls _broke (look-options) then street.brace_fall(event, DROP_REACH);
  _topple_land builds crush_all spots with width * 0.6 + fall_spill.
- 400-line cap: the pavement graph (_build_pavements, _link, CORNERS/PAVEMENT/CROSSWALK) moved, unchanged, to
  scenes/pavements.gd (class Pavements). street_life 376 lines, city_view 389.
## Evidence so far
- Native rebuilt in the worktree (godot-cpp copied, gitignored); headless import 0 SCRIPT ERROR.
- flow 7/7 fn 206 checks, smoke 13/13 30, crowd 4/4 8: all pass. gdlint + gdformat clean on touched files.
- tools/capture/probe_crush.gd --seeds=0-11 (cephalopod): kaiju kills on 12/12 seeds: 48 22 13 14 10 35 12 17 20 14
  9 15 (tanks 2 5 5 5 7 7 5 0 0 5 5 0).
## Open decisions
none
## Running jobs
none
## Findings for the lead
- probe_crush on the headless dummy renderer prints "Attempting to initialize the wrong RID" / "material is null"
  from building_stream.finish_initial when it runs several rampages in one process; counts unaffected, not a suite.
## Rules learnt the hard way
- Merges that add lines to street_life/city_view hit the 400-line cap: split by moving a self-contained block.
