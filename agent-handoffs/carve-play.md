# carve-play handoff (integration builder: carving in the playable build, D-094/D-097/D-099)
## State: life 2 stood down after step 2 (lead: no subagents, a fresh session continues). Branch
claude/carve-play pushed with the WP5 7503e06 merge; no PR (the lead opens it).
- Build run 39373735540 (e0f8c7c, life 1 head): GREEN, artifact KaijuIncremental-e0f8c7c (57 MB).
- WP5 7503e06 merged clean. Headless probe after it (--fixed-fps 60, --seconds=18): first carved
  fall step 631 (10.5 s), 4 promoted, 10 carves, 2 falls, islands peak 10 (WP5 splits), live back
  to 0, rubble 1597 (max/building 823, 0 dropped; life 1 was 400 / 120: WP5 round 2 makes far
  more rubble, flag to the lead). Headless costs: fell 888 ms, take 96, carved 120, colliders 104.
- Suites green after the merge: smoke 13/13 fn 30 checks, cell_mesh 7/7 38, cells 10/10 50,
  destruction 12/12 43.
## Next life: steps 3-5 of the lead brief (2026-10-20)
3. Island fall hitch. WIP (unverified, not committed) in ../Kaiju-Incremental-wt/carve-play-wip/:
   hitch.patch (git apply in this worktree) + island_mesher.gd (copy to scenes/). It adds
   IslandMesher (worker fills CarveMesh.arrays_at, take() builds ArrayMesh), CarveMesh.from_arrays/
   arrays_at split, IslandBody.mesh_on_worker + look (material setter) + _ready meshing, split
   chunks keep layer/mask/look (BUG on branch now: WP5 split chunks spawn on default layers and flat
   white material, since only the first island is dressed), CarvePhysics.mesh_on_worker set by
   CarveCity. To do: gdformat carve_city.gd; move CarvePhysics.mesh_on_worker below the vars in
   order (gdlint class-definitions-order); island_body.gd is 493 lines > gdlint 400 (437 already
   from WP5: tell the lead). Then take 22 ms: _take_chunks row-wise (index = x + z*dx + y*dx*dz,
   iterate the x run from one base index). Bench on vs off (--bench --graphics=balanced 1080p).
4. WP7 (origin/claude/carve-wp7 255f2fd) handoff still says "working" with an open lead question
   (military suite): skip, do not wait.
5. Push, gh workflow run build.yml --ref claude/carve-play, report run id; 1080p clip of the stomp
   (capture_carve_play.gd --write-movie) to the lead.
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
