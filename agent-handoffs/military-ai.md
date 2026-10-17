# Military AI handoff, 2026-10-18
## State: running a check (reptilian pacing on snapshot A: range 24)

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". Brief from LEAD
(local_106fc100...): road-bound tanks in columns, firing posts at standoff with line of fire on an
arc, bound/fall back/re-route on rubble; helicopter pairs, deliberate runs, break off when faced,
never inside the kaiju. Gates: sim-review packet (LEAD reviews), seeded checks failing first,
player-effect fixture, floors, clip + top-down trace + army-step timing, pacing (reptilian).
Do not touch biped_swing/gait_clip/city_ground/ui_kit. Rooftop session edits sim/army.gd too.

## Branch and commit
claude/military-ai off origin/claude/look-options b25bb4f, worktree
../Kaiju-Incremental-wt/military-ai (makes 9 worktrees: WT-OVER told to LEAD). Nothing committed.

## Unfinished changes (all uncommitted in the worktree)
- sim/convoy.gd (new): road graph from CityGen.map (no alleys, clipped to arena+entry_depth),
  Dijkstra (danger/held/oncoming costs), firing posts sampled along roads in the band, spread
  arc, reserve rings, right-hand lanes on 6 m roads, hull-rectangle spacing, column follow gap,
  right of way (younger backs up), stuck re-route, toppled-tower road closure, line of fire.
- sim/army.gd: two hunks only (spawn via convoy.enter/pick_entry, move = convoy.step, fire needs
  clear_line). sim/rampage_sim.gd: Tank.heading, Tank.reversing. scenes/rampage.gd: hull keeps
  its front to the kaiju when reversing.
- sim/air_wing.gd: lead/wingman pairs, ORBIT/RUN/BREAK, attack_radius = body + attack_clear,
  break off + reverse when faced (face_deg). data/tuning.json: army.convoy block, army.range
  11 -> 24 (MEASURING), air run/break/wing keys (dive removed).
- tests/run_military_tests.gd (11 checks, floor 11) + registration in run_tests.sh, ci_shards,
  README. tools/capture/army_trace.gd (top-down PNG + army step timing, runs on old code too),
  tools/capture/capture_military.gd (clip script, untested).

## Evidence so far
- Baseline pacing (old code, scratch export): reptilian evolve1 0.59 h, tree 4.46 h (= lead's).
- Old code fires 197/224/367 tank shots (tiers 1/2/4, seeds 0-2, 60 s); new at range 11 only
  7/50/126 (road travel + line of fire); range 24: 64/179/226. Pacing at range 24 running.

## Attempts (fix-loop record)
Jams: circle gap -> hull rectangles; lanes; follow only same-direction; oncoming cost; right of
way + 2 s yield hold; reserve flag (stale firing posts were kept); band posts sampled 1 m.

## Open decisions
- Heli cap unchanged: a lone heli until the wingman's call-in (asked LEAD, no answer yet).
- Range change 11 -> 24 needs LEAD/director OK if pacing holds (D-049 balance).

## Running jobs
Pacing snapshot A in scratchpad snapA (background); one Godot at a time.

## Findings for the lead
none yet

## Rules learnt the hard way
- Run pacing on a scratch copy (tar of the worktree) so edits do not leak into a running job.
