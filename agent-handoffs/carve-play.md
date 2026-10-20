# carve-play handoff (integration builder: carving in the playable build, D-094/D-097/D-099)
## State: life 3 paused (director: helpers finish, pause, archive), 2026-10-20. Head 3998051 pushed
(no PR). Build 1: run 39379786766 on 4d65b48, KaijuIncremental-4d65b48, smoke PASS, exe headless clean.
Build 2: run 39383890892 on 3998051 (+ #89 croc body contact, look-options c08e770); release smoke PASS (0 failures),
exe headless clean, artifact KaijuIncremental-3998051. #89 merge: city_view takes RuinYard/ToppleFx, carved buildings get no ruin heap
(_mark_ruin); flow_collapse.gd picks non-carving buildings. 9 suites green locally (smoke, cell_mesh,
cells, destruction, flow, military, native, powers, sim).
- Island fall hitch fixed: IslandMesher (scenes/island_mesher.gd) meshes bricks in a WorkerThreadPool
  group task and scans an island's cells once; split chunks keep layer/mask/look (were white on default
  layers); CarveCity._take_chunks row-wise. Bench 1080p balanced 18 s, carving on (2 runs): mean 16.6-16.7,
  p95 23.9-25.8, worst 94.6-97.5, 9-11 > 33 ms; off: mean 16.7, p95 17.3, worst 52.7, 3 > 33 ms.
  Carve costs now: fell 103 -> 14-18 ms, take 22 -> 5, carved 25-36, colliders 63-66 (promote).
- --bench prints "CARVE slow step" lines with what each slow frame spent. Remaining spikes, by the
  trace: CarveCollider build on promote (63 ms, step ~555), carved debris spawn + chunks_broken
  (25-42 ms each at a carve), engine physics on the fall frame (~30 ms). Next targets, in that order.
- Clip: C:/Users/DANTE/AppData/Local/Temp/claude/carve-play3/carve_play_tower.mp4 (1080p 30 fps, game
  camera; sheet_fall.png beside it: tower topples right in its own look 11.1-12.6 s, dust).
- Lint debt (lead): island_body.gd 490 lines, carve_debris.gd 539 (WP5) > gdlint 400.
## Next (a fresh life)
4. WP7 (origin/claude/carve-wp7 367bb7e, "life 1 stands down, work left", no PR): merge when PR-ready.
   Its dry merge conflicts only in data/tuning.json + tests/README.md. Then CarveCity reads
   cells_promoted / cells_carved / fall_start index+mats (see "Left from life 1" item 3).
5. Spikes left (bench --bench "slow step" lines): CarveCollider build on promote 63 ms, carved debris
   + chunks_broken 25-42 ms per carve, engine physics ~30 ms on the fall frame.
6. Rebuild, smoke, clip, bench after each.
## Branch
Worktree ../Kaiju-Incremental-wt/carve-play from origin/claude/carve-wp4 (10ed48b) + merge of
origin/claude/carve-wp5 at cecfac8 (WP5's old WP1 copies of sim/voxel_frame, voxel_support,
tests/run_destruction_tests, tests/lib/destruction_paths resolved to ours = final #97).
native/bin has WP4's debug dll copied (gitignored); godot-cpp submodule initialised.
## What I added
- scenes/carve_city.gd (CarveCity, child of CityView): per building, BuildingCells + CellMesher made on a
  worker (want(); prefetch of the nearest built buildings within destruction.prefetch_reach x body scale,
  prefetch_tasks at a time); _take_made() clears chunks the sim already lost, BuildingView.promote(grid,
  mesher, keep_baked=true), baked meshes stay until the CellView's first batch is drawn (show_cells), then
  CarvePhysics.add_site with a CarveSite (origin = grid cell 0 corner, offset = grid.offset, palette from the
  building's voxel palette by material name).
  chunks_broken(): empties the chunks' cells (BuildingCells.clear_chunk ranges), CellView.carved, CarvePhysics.carved
  (push away from kaiju + carve_lift). fall_start(): chunks' cells -> IslandBody via CarvePhysics.fell (pivot made
  building-local); island layer 4 / mask 8 (ground only; CityView ground on 1|8) and the building's cell material.
  cost_usec timers (take, carved, fell, promote, colliders).
- city_view.gd: carve hooks in chunks_broken / fall_start / fall_land (_carved_land: dust line + crush only),
  no Ruin heap for carved buildings; building_view.gd: promote(grid, mesher, keep_baked), show_cells(),
  cells_material(), hide_chunks keeps slabs hidden once cells show; building_stream.gd: party(n).
- tools/capture/capture_carve_play.gd: croc (upgraded) walks by real W/A/S/D key events to the tallest tower it
  can break and stomps it; --bench --graphics=balanced, --carving=on|off, --islands (per-island trace).
## Evidence (local, Windows, director away)
- Headless probe (fixed 60): target b44 7x2x14 falls at step 631 (10.5 s); 4 promoted, 10 carves, 2 islands,
  rubble 400 (max 120/building, 0 dropped), live bodies back to 0.
- Clip 1920x1080 30 fps, game camera: scratchpad clip2/carve_play_tower.mp4 (session cde796d6 scratchpad);
  frames 10.8-14.0 s: grey slab topples right, dark tower b45 drops and crumbles to rubble + dust.
- Bench balanced 1080p 18 s: carving on mean 16.7 ms (60 fps, vsync), p95 18.3, worst 141.7, 5 frames > 33 ms;
  off: p95 16.8, worst 26.1, 0 > 33 ms. Costs on: fell 103 ms (IslandBody meshing, GDScript), colliders 35,
  carved 24, take 22.
- Suites green locally: smoke, cell_mesh, cells, destruction. tools/release/demo_smoke.gd from source: PASS (0 failures).
## Fixes found in play
1. Island caught on a neighbour's CarveCollider stopped dead at 35 deg (v 0 at release) -> islands collide with
   the ground layer only; the sim's Collapse strip decides what a fall crushes.
2. Islands drew flat white (CarveMesh StandardMaterial) -> building's cell ShaderMaterial on island meshes.
## Left from life 1 (items 1-2 done; 3-4 = steps 4, 3 above)
1. Report build 39373735540 artifact (KaijuIncremental-<sha>) to the lead.
2. Merge origin/claude/carve-wp5 7503e06 (round-2 motion fixes) and re-run the probe.
3. WP7 (origin/claude/carve-wp7 486a21e, life 1) emits "cells_promoted" {building, dims, offset, cells},
   "cells_carved" {building, index, mats}, "chunks_broken" (mirror), and fall_start with "index"/"mats"
   (grid indices). When merged: CarveCity must read sim.carving.frame(n).cells (sim grid; adopt copies bytes)
   instead of its own mirror: carved(index, mats) straight from cells_carved, fall_start uses event index/mats,
   chunks_broken stops carving (mirror only). WP7 key is destruction.carve (true); mine is carving_enabled.
   WP7 also moves party walls to sim/party_walls.gd (BuildingView.party_walls -> PartyWalls.of).
4. Hitches: fell 103 ms (IslandBody GDScript meshing -> worker or native), take 22 ms (row-wise scan).
5. Not exercised: landmarks (chunk path until WP6), 4K, other species' powers on carved buildings, a full
   60 s run end beat with carving, gl_compatibility.
## Rules learnt
- focus-guard needs override.cfg with mode=0, no_focus, initial_position (-20000,-20000) (untracked; delete after).
- cv2 is in user site-packages: run python without -I for own scripts.
