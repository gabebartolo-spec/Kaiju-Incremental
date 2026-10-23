# Audit-shared handoff, 2026-10-22 16:10
## State: running a check (full suite)
## Task
Task 017 (audit package 2): #1 one sim-side building layout for BuildingCells and BuildingVoxels; #7 one shared capture
kit for tools/capture near-copies. Wave 1 rules: no PR, push under claude/audit-shared (or -v2), 6-line report.
## Branch and commit
claude/audit-shared on origin/claude/look-options 56d92a1b, 4 commits (backup of the old history:
claude/audit-shared-pre-rebase 9ba97662):
- e79c1141 BuildingLayout (sim/building_layout.gd) + thin BuildingCells / BuildingVoxels (audit #1)
- a92ea3af complexity baseline 80 -> 76 rows
- 02fec157 tools/capture/capture_kit.gd + 16 scripts moved onto it (audit #7)
- 1fc63940 tests/lib/fade_spawn.gd reads the kit's stage levels
## Evidence so far
- #1 digest (scratchpad digest_buildings.gd): 20 non-landmark buildings per stage, stages 1 and 4, all 4 styles; per
  building: view voxel cells (lit, insertion order), baked shell and slab meshes, sim GDScript grid, native grid.
  Origin sim/building_cells.gd + scenes/building_voxels.gd vs the branch: all 43 lines IDENTICAL; native == GDScript.
- Lines: sim/ + scenes/ 377 added, 580 removed (net -203; building_layout.gd is 345 of the added).
- Lint: gdlint clean, tuning_keys ok (698), complexity ratchet ok (76 offenders).
- #7: probe_promote / probe_settle ran headless clean; the other 14 scripts ran once windowed off-screen (RTX 4070 SUPER, 1280x720, shortest flags): all exit 0, no script errors, stills written.
- Pixels, old tree (origin tools/capture + old layout files) vs branch, seed 0, 1920x1080: kaiju_2x.png crop byte-identical (twice); game.png 48 px differ (max 11/255) vs 174 px (max 20) between two runs of the SAME branch; 3 s rampage_kaiju clip worst frame mean 0.157 vs 0.265 between two same-branch runs = engine run-to-run noise.
## Overlap with claude/city-memory
city-memory (8747ddf6) adds only tools/capture/stage4_memory.gd in tools/capture and does NOT touch
sim/building_cells.gd or scenes/building_voxels.gd relative to their common base, but it changes BuildingView,
BuildingMesher, CellMesher, building_stream/fade, voxel_builder (none touched here). Expect a textual conflict only if
it later edits building_voxels.gd / building_cells.gd; stage4_memory.gd may adopt the kit (not done).
## Left
check_scripts.sh + full suite once (tools/run_tests.sh --quick, log in scratchpad fullsuite.log); commit handoff; push; report.
## Running jobs
runall.sh in scratchpad (windowed off-screen, 2 Godot at a time, APPDATA as_ad1/as_ad2).
## Findings for the lead
none yet
## Rules learnt the hard way
- A headless (dummy renderer) run cannot save images: stills need --windowed with the no_focus override.cfg.
