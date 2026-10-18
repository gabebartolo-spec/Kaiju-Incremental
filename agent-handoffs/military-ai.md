# Military AI handoff, 2026-10-18 (evening)
## State: awaiting lead (pair clip sent for LEAD's fresh critic; PR #50 head 0d1fd53, Auto-fix on)

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". Brief from LEAD
(session "Kaiju: Lead", local_106fc100...). Gates: sim-review packet (LEAD reviews), seeded
checks failing first, player-effect fixture, floors, a 6-10 s 1080p game-camera clip (tank
column by road + heli pair run), top-down traces before/after, army-step timing, pacing.

## Branch and commit
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options, head 0d1fd53 (synced look-options 78b5346, #53). Do not merge: LEAD merges.

## What is in it
- sim/convoy.gd (routes, drive, spacing, right of way, re-route, bounding, fall back, rubble),
  sim/road_graph.gd (graph, grids, drivable, waypoints, lanes), sim/road_search.gd (Dijkstra),
  sim/firing_posts.gd (band posts, arc spread, reserve rings, line of fire).
- sim/army.gd: spawn via Convoy, move = convoy.step, fire needs clear_line. sim/air_wing.gd:
  lead/wingman, ORBIT/RUN(strafing pass, run_hold)/BREAK, break off when faced, guns on runs.
- data/tuning.json: army.convoy, air.formation (new blocks); growth.stages army range per
  stage 10.5/14.5/15/17.5 (base 11 untouched); young also tank_damage 8, fire_interval 0.7 so
  every young shooter is on screen (LEAD review 1); air.dive now unused (left for board).
- scenes/rampage.gd: reversing hull keeps its front to the kaiju (convoy.reversing).
- tests/run_military_tests.gd + tests/lib/military_base.gd (11 checks, floor 11, shard 1).
  Player effect = facing the helicopters down (0 vs 41 rounds; old code 7 vs 7). The charge
  fixture was dropped: no effect at on-screen young range (backing tanks cannot outrun).
- tools/capture/army_trace.gd (trace PNG + Army.step timing; runs on old code too),
  tools/capture/capture_military.gd (18 s clip, trim to 10 s).

## Evidence (all in the PR body)
- Suites: all 10 green locally at 7cb5432 (smoke 30, flow 133, clips 14, military 11); flow 134 + military at 0d1fd53.
- 1080p clip (run 39085086356, notes clip_ci2) failed my 2x check: heli pair rotor to rotor.
  Fixed 3caf8e6: air.formation wing_out 13, wing_gap 12; pair check >= 12 m (old 7.0 fails).
- Face-down exploit check (LEAD): always-face player 0 heli dmg but city 45% vs 90%: shipped.
- Failing first: 7/7 on old code; 4 mutants. Notes folder military-ai/ has traces, timing,
  sim-review-packet.md.
- Damage per run (tank + heli + rooftop), 27 replayed pacing states: -2.8/+3.8/+0.2/+2.1%.
- Pacing reptilian at 4bc64c9: 0.60 h / 4.53 h, young 11/19 (bar 0.59 / 4.46).
- Young camera ground measured: 13.7 m S, 21-49 m sides, 36 m N; young reach 11.8 m.
- Timing: Apex army step mean 0.4 ms, p95 1.1 ms, max 3.0 ms (old 0.03 ms).

## Next
1. Pair clip (notes military-ai/clip_pair, run 39093467906, 0d1fd53) passed my 2x check and went
   to LEAD: faced reversal 4.73 s, camera-arc turn-backs 9.65/16.58 s, closest 13.00 m. LEAD runs a
   fresh critic, then merges. Fix any finding.
2. Resync if look-options moves (floors to the real counts; keep military 11).
3. Capture note: forward_plus at 1080p hit the 50 min cap on CI; pass --renderer=gl_compatibility.

## Findings for the lead
- Replay pacing states (dump stats every 6th run, replay with candidate tunings) reproduced the
  old pacing exactly and measured balance shifts in minutes instead of 18-30 min pacing runs.
- Run pacing on a tar snapshot of the worktree so edits do not leak into a running job.

## Rules learnt the hard way
- gdlint caps (400 lines, 100 cols, 4 args, declaration order) bite late: lint early.
- Probe scripts: typed locals for every Variant (warnings are errors).
