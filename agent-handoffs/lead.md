# Lead handoff, 2026-10-16 17:20
## State: working (director AFK, "no questions"); critic round 2 on the city look running

## Task
Art direction + destruction overhaul. Director decisions today (docs/DECISIONS.md D-008..D-013):
look C (concrete) far more detailed; real light sources; young kaiju outscaled by the city, grows
(D-009); terrifying monsters, not toys; buildings are real structures that topple like Jenga;
shaders and particles; kaiju models from Tripo, voxelized in Blender (D-012, spend approved
"a few hundred credits per species"; ask past 500/session).
Reference: WATCH THIS.mp4 (repo root, untracked; CityV voxel city destruction) + CG Cookie
detailed-voxel trailer (youtube iPENkVBlPgI). Frames: scratchpad w_city/, w_city2/.

## Branch and commit
claude/look-options -> PR #3 (HOLD: director has not seen the detailed look yet). Head 9bd44d5.

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
2. Critic round 2 verdict -> fix -> re-capture -> show director board (city + lineup).
3. Lineup kaiju still code-built placeholders (toy-like) until the sculpts land.

## Evidence so far
Tests: smoke 11, sim 39, flow 9 + self-test green; lint clean. GPU ~4.5 ms 1080p, ~9 ms 4K
(4070 SUPER, engine timers). Offscreen-window FPS is throttled: never trust it.

## Rules learnt the hard way
- Check nvidia-smi for a game before windowed runs (director plays LoL).
- sim.step() clears events: route sim.events right after direct damage calls (capture tool).
- Godot scaled RigidBody is unsupported: tween the mesh child, not the body.
- gdformat rewraps code: re-read before scripted string edits.
- Capture override.cfg must be deleted afterwards.
