# carve-wp6 handoff (builder, WP6 of real carving, D-094)
## State: pushed, awaiting lead (lead opens the PR; body draft in worktree pr_body_wp6.md, untracked)
## Task
WP6: landmarks + Arcs on the fine grid; CellPromoter returns a real grid for a landmark.
## Branch
claude/carve-wp6 from origin/claude/look-options + merge of origin/claude/carve-wp3 (PR #98 open); worktree ../Kaiju-Incremental-wt/carve-wp6.
## Files
- sim/cell_grid.gd (CellGrid base, moved out of BuildingCells), sim/landmark_cells.gd (LandmarkCells), sim/cell_promoter.gd, sim/arcs.gd (+dir_of, arc_count)
- data/materials.json ids 27-30 landmark_*, data/tuning.json destruction.arc_shed_cells = 32
- tests/run_landmarkcells_tests.gd (9 functions, 26 checks), cells suite edits, tests/README.md row
## Contract notes
- Material = colour class of the baked voxel; sim has its own .kvox reader (sim cannot import scenes/).
- shed() returns events in cells ({cells, kind, pivot (cells), dir}); the caller clears with clear_cell().
- rebase() after promotion so settled chunk losses are not new arc loss.
## Evidence
landmarkcells, cells, smoke, city green locally; gdlint/gdformat clean; mutation fail-first in pr_body_wp6.md.
## Open
- arc_shed_cells = 32 is a placeholder (about one chunk's shell cells): balance call for the director.
- Build cost 246 ms stadium (GDScript, debug).
