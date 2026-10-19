# carve-wp4 handoff (builder, WP4 of real carving, D-094)
## State: WP4 complete; CI run 39343371928 on a4fe572 pending; capture docs/captures/2026-10-20-carve-view; pr_body_wp4.md written (untracked)
## Task
WP4: draw a carved building from its fine grid (WP3 BuildingCells), 16^3 regions, remesh only touched
regions on WorkerThreadPool, native mesher (WP2 extension) with GDScript oracle. Not wired into rampage (WP7).
## Branch
claude/carve-wp4 from origin/claude/look-options + merge of origin/claude/carve-wp2 and carve-wp3 (PRs #99/#98
open). Worktree ../Kaiju-Incremental-wt/carve-wp4. No PR: the lead opens it; body draft pr_body_wp4.md (untracked).
## Files
- native/src/kaiju_mesher.{h,cpp} (KaijuMesher: setup, mesh_region), register_types.cpp registers it
- scenes/cell_mesher.gd (CellMesher: looks overlay = materials + BuildingVoxels lit roll, GDScript oracle)
- scenes/cell_view.gd (CellView: region MeshInstance3Ds, batch on WorkerThreadPool, carved(cells, lo, hi))
- scenes/building_view.gd: promote(grid) -> CellView, set_opacity forwards (BuildingFade)
- tests/run_cell_mesh_tests.gd (suite cell_mesh), tests/README.md row
## Design notes
- Faces wherever solid meets air (true surface): hole interiors are lit front faces; walls' inner faces
  and slabs are drawn (more triangles than the baked shell; only promoted buildings pay).
- Same shader (building_baked) with a 1x1 all-standing alive texture; no UV2 (chunk 0).
- Vertex colours: baked mesh stores 8-bit truncated, clamped; parity compares within one step.
## Evidence so far
cell_mesh 7/7 fns 38 checks green, native 16, cells 33 green. Fail-first: M1 region margin, M2 lit roll,
M3 edge faces, M4 fade, M5 stale grid, M6 native salt (870/990 blocks off).
## Local build
scratchpad build_native.bat (vcvars64 + python -m SCons platform=windows target=template_debug).
## Bench (local, Windows, 16 threads; tools/capture/bench_cell_mesh.gd headless, 60 carves)
- glass 6x6x16 native: remesh/carve p95 2.0 ms (r6), 2.8 ms (r12); GDScript 7.8-12 ms. office 3x3x6 native
  p95 1.2/3.8 ms. Promotion: grid+voxels ~140 ms, looks ~50 ms, first build 40 ms native (126 GDScript).
- 4K (capture_carve_view.gd --bench, SubViewport 3840x2160, game camera, stage 2): baked city GPU 8.1-8.6 ms,
  with 21 buildings promoted+carved (898k tris) GPU 8.4 ms (noise), CPU render +0.8-1.5 ms.
## Capture (local, director away, allowed by lead): capture_carve_view.gd at 1920x1080, kaiju hidden (covers
  tower). Boards in session scratchpad: board_sequence.png, board_slab.png (A 2b2d30 vs B 8a8780).
- Lead ruling: keep A (slab 2b2d30, one palette line in BuildingVoxels._make_palette); lead asks director.
## Fix applied
- Meshes now built on the main thread (worker-made mesh RIDs raced the dummy renderer:
  "Initializing already initialized RID"); workers return arrays.
## Left
- CI run 39342476788 (dispatched before the bench/capture commit) result; re-dispatch after this commit.
- Rerender capture after bite moved to the street face (panel 3 was invisible on the east face).
- pr_body_wp4.md (untracked, worktree root; all template sections incl. Not exercised).
