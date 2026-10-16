# Lead handoff, 2026-10-16 17:36
## State: running a check (director AFK, "no questions"): critic gate round 10 on the city look

## Task
Art direction + destruction overhaul. Director decisions today (docs/DECISIONS.md D-008..D-013):
look C (concrete) far more detailed; real light sources; young kaiju outscaled by the city, grows
(D-009); terrifying monsters, not toys; buildings are real structures that topple like Jenga;
shaders and particles; kaiju models from Tripo, voxelized in Blender (D-012, spend approved
"a few hundred credits per species"; ask past 500/session).
Reference: WATCH THIS.mp4 (repo root, untracked; CityV voxel city destruction) + CG Cookie
detailed-voxel trailer (youtube iPENkVBlPgI). Frames: scratchpad w_city/, w_city2/.

## Branch and commit
claude/look-options -> PR #3 (HOLD: director has not seen the detailed look yet). Pushed to head.

## What exists now
- sim/structure.gd (chunks, support, drop/topple), sim/collapse.gd (falls, landing, strip crush),
  RampageSim blows spread outward (_falloff) so power = bigger crater; nearest_standing() for AI.
- scenes: BuildingView (voxels per chunk, chip() ragged holes), CityView, DebrisField (Jolt rigid
  debris), Ruin (rubble heap + wall stubs), Fire (flames/embers ember.gdshader, smoke.gdshader
  columns), Fx (dust puffs, sparks, shockwave.gdshader), CityDecor/PropField (cars, trees, lamps
  with OmniLights; crushable), TankModel, KaijuModel (code-built RES 5 placeholders; loads
  assets/kaiju/<species>.kvox when present), Kvox loader, VoxelBuilder (DIRECT colours).
- tools/blender/voxelize.py (GLB -> .kvox, textured, proven on a test mesh); tools/capture/
  capture_looks.gd (perf via engine timers) and bench_rampage.gd.
- Economy retuned: ~80 rubble first rampage (chunk_rubble 0.05).

## Unfinished
1. Tripo reptilian generated (task 484078ce..., 30 cr, Private). Inspection + download need the
   director: Chrome window too small for the viewer and downloads need his OK. Then texture (if
   untextured), rig/animate, voxelize, six-view QA, then insectoid + cephalopod.
2. Critic rounds 1-8 fixed (round 8: dusty rubble palette, dim fire light, soft smoke); rounds 1-7 fixed (ruins, plumes, ember-cluster fire, grade, stepped bites, rubble piles
   where towers land, hitches, exit crash); round 9 fixed (pale concrete heaps, corner stumps); round 10 gate pending. Note: rounds 8/9 oscillated (too bright, then too dark) - stop at a middle the reference shows. Board ready:
   docs/captures/2026-10-16-destruction/board.png (A young, B evolved).
   Then show the director: city captures + docs/captures/2026-10-16-destruction/rampage_clip.mp4
   (local only, *.mp4 is gitignored).
3. Lineup kaiju still code-built placeholders (toy-like) until the sculpts land.

## Evidence so far
Tests: smoke 11, sim 39, flow 9 + self-test green; lint clean. GPU ~4.5 ms 1080p, ~9 ms 4K
(4070 SUPER, engine timers). Offscreen-window FPS is throttled: never trust it.

## Perf (engine timers, 4070 SUPER)
1080p GPU ~5 ms; real frame gaps worst 20.8 ms, 0/3994 over 33 ms (bench_rampage.gd prints a
per-event worst-cost table). Debris spawns from a queue (30/frame); ruins build on WorkerThreadPool.

## Rules learnt the hard way
- WorkerThreadPool tasks: wait in _exit_tree or the game crashes at exit.
- Performance.TIME_PROCESS updates ~1/s: measure hitches as wall-clock frame gaps.
- Check nvidia-smi for a game before windowed runs (director plays LoL).
- sim.step() clears events: route sim.events right after direct damage calls (capture tool).
- Godot scaled RigidBody is unsupported: tween the mesh child, not the body.
- gdformat rewraps code: re-read before scripted string edits.
- Capture override.cfg must be deleted afterwards.

## Attempts
- Fire: cream "lampshade" = fire light washing out its smoke base + AgX desaturating bright orange;
  fixed by starting smoke above flames, ember heat 1.4, small flame cubes.

## Running jobs
Critic gate round 10 (background agent). CI on PR #3: the one red run (977a34e) was the exit crash, fixed since; later runs green. override.cfg present for captures: delete when done.
