# Tests

One command runs everything CI runs (import, every suite, the harness self-test):

```sh
GODOT=/path/to/godot_console tools/run_tests.sh            # everything
GODOT=/path/to/godot_console tools/run_tests.sh smoke      # some suites
```

Every run gets its own user data (APPDATA and the XDG dirs point at a temp dir), so two
agents' runs never share saves, settings or caches. The rules are the `game-architecture`
skill §6 and the `kaiju-godot-tests` skill: one runner per suite extending
`tests/lib/runner.gd`; each test a `_check_*` method called through `await _t(...)`, so the
suite line "K of M functions" fails one that never ran or made no check (no floors); a
`SCRIPT ERROR` fails the suite; seeds pinned. Suites are found by filename and CI shards come
from `tools/ci_timings.txt`, so a new suite needs only its file and a row below.

`tools/run_tests.sh --quick <suite>` skips the re-import for the local loop.

## Suites

| Suite | Covers |
|---|---|
| `smoke` | typing warnings are errors; exactly the sanctioned autoloads; every script compiles; the main scene opens headless and stays up |
| `clips` | the croc titan's baked Blender clips (D-047) load and fit its rig; the walk phase follows distance; turn, roar and idle play without NaN; a walking curve swings the tail and it settles; the clips own the tail bones; the roar tail slam lands as one footfall; other kaiju keep procedural gaits |
| `walk` | the croc titan's walk carries weight (ClipWeight, director 2026-10-21 #4), each move measured on and off: the stride stretches with speed so the legs cycle slower (baby, adult; no catch steps, feet planted), the chest rolls and twists against the pelvis and the head bobs on a lag, footfalls drop the pelvis and a cub's land lighter, an adult eases into its walk, the chest takes part of the head's turn lead, two identical walks pose every bone the same |
| `carving` | the rampage on the fine grid (Carving, D-094 WP7, D-099): player-effect fixture "carving" (the same seeded stomps with carving on and off: cells carved, chunks only partly carved, every carved cell within the stomp's reach; off has no grid); promotion on first hit only; a base cut topples the tower toward the cut wherever the kaiju stands, carrying its fine cells; wear adds tough blows up and breaks on the same blow as the chunk rule; a razed building pays the same rubble either way; seeded replay identical; no clock or RNG in the module |
| `cell_mesh` | a carved building's view from its fine grid (CellMesher, CellView, D-094 WP4): uncarved it draws every face of the baked BuildingView in the same colour (lit windows included) plus only inner faces into the hollow; after carves every solid-air boundary is exactly one face (holes show lit inner faces, no gaps); a carve remeshes only the 16^3 blocks it touched and they equal a fresh mesh (drawn one by one and queued on a running batch); native KaijuMesher == GDScript oracle byte for byte; promote keeps BuildingFade's set_opacity |
| `cells` | the sim's fine destruction grid of a building (BuildingCells, D-094) is BuildingVoxels' layout cell for cell on every archetype, party walls, a sign and a seeded city sample; built twice the same; counts and digests pinned; materials table valid; no clock or RNG in the module; a building gets its grid only on its first hit (CellPromoter), with every lost chunk emptied as the view clamps it (proud and roof cells too); no island before any carve over the fixtures, 120 seeded-city buildings and every glass-style building of three cities (VoxelSupport's real rule; glass towers stand on a structural frame; a pane under a wall is cut off); a lit window is a look only |
| `landmarkcells` | the sim's fine grid of a landmark (LandmarkCells, D-094 WP6) is LandmarkVoxels' cells one for one, each in its colour class, in the chunks the sim builds; counts and digests pinned; the stadium's arcs shed a whole section on cells as they do on chunks (not before arc_shed_cells lost); a landmark is promoted on its first hit; no clock or RNG in the modules |
| `destruction` | the carving sim grid (VoxelFrame, D-094 WP1): sphere and capsule carves, material strength, the ground flood and islands, grid offset, no clock or RNG in the module, the spike's island pins (8,415 / 35,428), replay digests for the tower and the block of six at RES 4 and 8, and pinned replay traces (each event's size, kind, direction and pivot) |
| `voxel_support` | VoxelFrame's support rule on small grids (D-094 WP1): topples off a post and off an island's landing, adopt's guard (ground is grid layer 0), re-settling what hung from a toppled load, and fixtures (panes, signs) that hang by a face, edge or corner and hold nothing up |
| `military` | the tanks move and fight like a professional military (D-066): they drive the road plan, never into a building, a lot or an alley; no two tanks as drawn (hull, turret, gun) ever touch; a driving tank keeps its hull within 10 degrees of its road and a parked one squares to it; parked tanks hold their firing band or reserve and leave the danger radius; road entries; a toppled tower re-routes a column; the clip scene through the drawn models (parts never touch, no skewed driving; the kaiju strides at them and they fall back; tanks may run cars over, director 2026-10-20) |

The harness self-test (`tools/test_run_tests.sh`) proves the runner fails a `_check_*`
method that is never called or makes no check, and that an untyped declaration does not compile.
