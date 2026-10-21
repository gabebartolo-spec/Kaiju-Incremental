# carve-wp3 handoff (builder, WP3 of real carving, D-094)
## State: life 4 re-review items done (flood .uid removed, glass_frame.gd in guard MODULES, PR body updated, 50 checks); CI pending on the new head
## Task
WP3: a pure sim generator of a building's fine grid (BuildingVoxels' layout cell for cell), materials
from data/, lazy promotion helper (not wired, WP7), new `cells` suite. PR #98.
## Branch
claude/carve-wp3 from origin/claude/look-options; worktree ../Kaiju-Incremental-wt/carve-wp3.
## Files
- sim/building_cells.gd (BuildingCells), sim/cell_promoter.gd (CellPromoter)
- data/materials.json (26 materials, all strength 1.0, "fixture" bool on each), data/tuning.json
  "destruction": {"res": 8}
- sim/content.gd: Content.materials()
- tests/run_cells_tests.gd (10 functions, 46 checks), tests/lib/cells_support.gd (edge-chunk and
  island checks), tests/lib/cells_flood_until_wp1.gd (TEMPORARY test-side fixture flood: delete
  when WP1's VoxelSupport has the fixture rule), tests/README.md row
## Review FIX (life 2)
1. Islands: fixture=true for window, mullion, glass, shop, sign_frame, neon0-3 (lead decision).
   Contract for WP1: fixture cell grounded if 26-touching a grounded cell; structural 6-face.
   Generator bugs fixed in BuildingCells AND BuildingVoxels (view change, needs a still):
   - brick water tank (636 cells) had no contact at all: a 6-cell "pipe" riser under its centre
     (roof to top+5) now meets the blob's lowest cell;
   - office neon sign (layers -2..-3, nothing at -1): "sign_frame" brackets at layer -1 at the
     sign's two edge columns on every spandrel row (y % res == 1), office only.
   Numbers: before 92/120 city buildings islanded (6-flood), 34/120 with fixture rule (all
   tank/sign); after 0/120 (77/120 if fixture flags off).
2. clear_chunk: boundary chunks run to grid edge (x/z 0 from 0, last to dims, top floor to dims.y).
   Before: office 1071, brick 1146, glass 903, stone 2043 cells left in dead chunks; after 0.
3. Parity exact: test subclass UnlitVoxels (no window lit) compared key == material name; plus
   _check_lit_is_a_look. Mutation window<->mullion: 1824 office cells off, caught.
- Pins moved: office 9227, brick 6674, party 6277 (+6 cells each: brackets / riser).
## Re-review FIX (life 3, WP1 real rule)
- Test flood now = WP1 exactly (structural 6-face from structural layer 0; fixtures 26-touch, never carry structural; layer-0 fixture grounded). Failing first: glass 12,029 cells cut, 285 of 299 glass-style buildings.
- Glass buildings get a structural frame one cell inside the curtain wall (sim/glass_frame.gd GlassFrame, one layout used by BuildingCells and BuildingVoxels; building_cells.gd was over the 400-line lint cap): "pillar" columns at corners and every destruction.column_bay (8) cells, ground to roof; "frame" beam behind the transom row (y%res==4, above ground floor). Pin glass 24805 -> 27213 (2ea7122061040817).
- New checks: wall-on-pane (2 cut), pane on layer 0, column carries pane; all glass-style buildings of 3 cities stand.
- Probe with WP1's real VoxelSupport (reviewer's probe): 7 fixtures + 1234 buildings, 0 islands, 0 settle events.
- Still: C:/Users/DANTE/AppData/Local/Temp/claude/wp3-still/frame (before/after, crops). Columns are invisible from outside at normal camera (glass is opaque there); only see-through/carved glass shows them.
## Contract notes for WP1/WP2/WP4
- Grid bytes: x fastest, then z, then y; offset = building-local cell of grid (0,0,0), offset.y = 0.
- Lit windows are a view look: the sim stores window/mullion/shop/glass.
## Open
- Ground-floor corner still (A before / B after) in C:/Users/DANTE/AppData/Local/Temp/claude/wp3-corner/ (corner_ground_4x_AB.png, full.png per side): awning hides the ground floor at the game camera, no visible change beyond lit-window rolls. Lead decides riser/bracket still.
- party_walls still in scenes/building_view.gd; move to sim in WP7.
