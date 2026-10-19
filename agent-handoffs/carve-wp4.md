# carve-wp4 handoff (builder, WP4 of real carving, D-094)
## State: working (code + tests green locally; bench and capture next)
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
## Left
bench line (remesh ms per carve, p95, native vs GDScript); capture before/after at game camera; PR body.
