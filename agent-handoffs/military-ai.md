# Military AI handoff, 2026-10-18 (afternoon)
## State: running a check (CI capture of the clip, run 39082152802 at 886f9cb); PR #50 open, Auto-fix on

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". Brief from LEAD
(session "Kaiju: Lead", local_106fc100...). Gates: sim-review packet (LEAD reviews), seeded
checks failing first, player-effect fixture, floors, a 6-10 s 1080p game-camera clip (tank
column by road + heli pair run), top-down traces before/after, army-step timing, pacing.

## Branch and commit
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options, head c0599b0 (merged look-options 2d66383). Do not merge: LEAD merges.

## What is in it
- sim/convoy.gd (routes, drive, spacing, right of way, re-route, bounding, fall back, rubble),
  sim/road_graph.gd (graph, grids, drivable, waypoints, lanes), sim/road_search.gd (Dijkstra),
  sim/firing_posts.gd (band posts, arc spread, reserve rings, line of fire).
- sim/army.gd: spawn via Convoy, move = convoy.step, fire needs clear_line. sim/air_wing.gd:
  lead/wingman, ORBIT/RUN(strafing pass, run_hold)/BREAK, break off when faced, guns on runs.
- data/tuning.json: army.convoy, air.formation (new blocks); growth.stages army range per
  stage 40/14.5/15/17.5 (base army.range 11 untouched); air.dive now unused (left for board).
- scenes/rampage.gd: reversing hull keeps its front to the kaiju (convoy.reversing).
- tests/run_military_tests.gd + tests/lib/military_base.gd (11 checks, floor 11, shard 1).
- tools/capture/army_trace.gd (trace PNG + Army.step timing; runs on old code too),
  tools/capture/capture_military.gd (18 s clip, trim to 10 s).

## Evidence (all in the PR body)
- Suites: all 10 green locally after the merge (flow 130, clips 14, military 11).
- Failing first: 7/7 on old code; 4 mutants. Notes folder military-ai/ has traces, timing,
  sim-review-packet.md.
- Damage per run (tank + heli + rooftop), 27 replayed pacing states: +0.5/+3.5/-0.6/+1.9%.
- Pacing reptilian: 0.59 h / 4.52 h (bar 0.59 / 4.46; look-options 0.58 / 4.45).
- Timing: Apex army step mean 0.4 ms, p95 1.1 ms, max 3.0 ms (old 0.03 ms).

## Next
1. Clip: when run 39082152802 lands (dir notes military-ai/clip_ci), check it at 2x (tanks
   on roads, column spacing, deploy, heli pass + break-off at 13 s). It is at 886f9cb (before
   the U-turn fix c86114d): if any tank dithers, re-dispatch at head:
   tools/capture/ci_capture.sh --movie --fps=30 --resolution=1920x1080 capture_military.gd --
   --seconds=18 --out=<notes>/military-ai/clip_ci2 (check capture.yml in_progress first).
   Trim the best 10 s with ffmpeg (path in lead handoff), send to LEAD, add to the PR body.
2. LEAD's sim review; fix findings. Sync if look-options moves (floors: keep both).

## Findings for the lead
- Replay pacing states (dump stats every 6th run, replay with candidate tunings) reproduced the
  old pacing exactly and measured balance shifts in minutes instead of 18-30 min pacing runs.
- Run pacing on a tar snapshot of the worktree so edits do not leak into a running job.

## Rules learnt the hard way
- gdlint caps (400 lines, 100 cols, 4 args, declaration order) bite late: lint early.
- Probe scripts: typed locals for every Variant (warnings are errors).
