# Lead handoff, 2026-10-16 20:15
## State: working (kaiju stages via Tripo); helper city-layout running; street-life helper running

## Task
Kaiju sculpts (3 species x baby/adolescent/adult, rigged voxels) + art direction. Director today:
D-022 insectoid = mantis (2 scythe arms + 4 legs), D-023 credits: quality over cost (log every
task), D-024 real city/edges (helper), D-025 smoke must not obscure the camera, D-026 ability
VFX/SFX later, D-027 4K 120 Hz TV target.

## Branch and commit
claude/look-options -> PR #3 (HOLD until the director has seen the work). Helpers PR into it:
street-life (civilians/traffic), city-layout (layout + edges, worktree branch city-layout).

## Done this turn
- smoke.gdshader camera rule: clear inside 8 units of camera, full from 22; 55% kept over screen
  centre. Capture: scratchpad smoke_after/ (kaiju visible through fires). Tests green.
- project.godot: fullscreen at start, stretch aspect expand, adaptive vsync (VRR TV).
- Tripo downloads staged in ~/Downloads/kaiju_tripo/: mantis_a (adult PICK, 9668b815),
  mantis_b (rejected, armless), mantis_c_lowpoly (adolescent candidate), adol_a (reptile adol v2).
  Six-view sheets in scratchpad six/<name>_sheet.png.

## Next
1. Insectoid baby generating: Tripo b1ddb234 (mantis nymph, 4 variants, Private). Export each
   (default name), six-view, pick. Maybe a proper-density adolescent from the mantis_c shape.
2. rig_voxel.py: add a hexapod skeleton (thorax/abdomen, 2 raptorial arms, 4 legs, antennae
   physics chains); KaijuRig walk needs 4-leg gait (tripod alternation).
3. Reptile adolescent v2: download b/c/d (export with the DEFAULT name; typing a new file name
   makes the export silently fail; rename locally), pick, rig at 130 voxels.
4. Board for the director: baby / adolescent / adult per species, labelled.
5. Cephalopod: all 3 stages + radial tentacle rig.
6. Review city-layout captures before the director sees them (art-qa-critic).
7. 4K TV: check UI text size at TV distance; HDR output; perf at 4K (~9 ms GPU before).
   Director confirmed the TV is on the 4070 SUPER.
9. Building fidelity (D-028) sent to city-layout: RES 8-12, recessed facades, LOD; review its side-by-side.
8. Cars (CityDecor.car, police cruisers) are far chunkier than the buildings: detail pass or
   Tripo vehicles later (noted in the street-life review).

## Rules learnt the hard way
- Tripo export: leave the default file name; typing one kills the download silently.
- Tripo thumbnails can fail to switch the selection: confirm the URL/face count changes first.
- WorkerThreadPool tasks: wait in _exit_tree. Frame gaps, not TIME_PROCESS. nvidia-smi before
  windowed runs. Capture override.cfg must be deleted afterwards.

## Running jobs
Sessions: city-layout (local_134db419-684a-4484-bc85-0333f568ac36, told to sync onto ca2c65c),
ability-vfx (local_24621710-3f9c-4f67-ae39-8fa4b6192106). street-life PR #5 MERGED (ca2c65c),
flow floor 14. Tripo b1ddb234 generating. No override.cfg left behind.
