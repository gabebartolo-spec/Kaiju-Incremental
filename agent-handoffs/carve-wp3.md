# carve-wp3 handoff (builder, WP3 of real carving, D-094)
## State: pushed, awaiting lead (lead opens the PR; body draft in worktree pr_body_wp3.md, untracked)
## Task
WP3: a pure sim generator of a building's fine grid (BuildingVoxels' layout cell for cell), materials
from data/, lazy promotion helper (not wired, WP7), new `cells` suite.
## Branch
claude/carve-wp3 from origin/claude/look-options; worktree ../Kaiju-Incremental-wt/carve-wp3.
## Files
- sim/building_cells.gd (BuildingCells), sim/cell_promoter.gd (CellPromoter)
- data/materials.json (26 materials, all strength 1.0), data/tuning.json "destruction": {"res": 8}
- sim/content.gd: Content.materials()
- tests/run_cells_tests.gd (9 functions, 33 checks), tests/README.md row
## Contract notes for WP1/WP2/WP4
- Grid bytes: x fastest, then z, then y; offset = building-local cell of grid (0,0,0), offset.y = 0,
  x/z offset negative (proud cells, signs); dims grow to hold roof gear (glass t3 mast: dims.y 170).
- Lit windows are a view look: the sim stores window/mullion/shop/glass.
- Promotion cost ~120 ms GDScript per 6x6x16 tower.
## Evidence
cells + smoke green locally; fail-first by empty pins and three mutations (see pr_body_wp3.md).
## Open
- WP1 key names unconfirmed (RES key, materials table): lead told 2026-10-20.
- party_walls still in scenes/building_view.gd; move to sim in WP7.
