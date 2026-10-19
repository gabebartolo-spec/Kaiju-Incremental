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
| `cells` | the sim's fine destruction grid of a building (BuildingCells, D-094) is BuildingVoxels' layout cell for cell on every archetype, party walls, a sign and a seeded city sample; built twice the same; counts and digests pinned; materials table valid; no clock or RNG in the module; a building gets its grid only on its first hit (CellPromoter) |
| `cell_mesh` | a carved building's view from its fine grid (CellMesher, CellView, D-094 WP4): uncarved it draws every face of the baked BuildingView in the same colour (lit windows included) plus only inner faces into the hollow; after carves every solid-air boundary is exactly one face (holes show lit inner faces, no gaps); a carve remeshes only the 16^3 blocks it touched and they equal a fresh mesh (drawn one by one and queued on a running batch); native KaijuMesher == GDScript oracle byte for byte; promote keeps BuildingFade's set_opacity |

The harness self-test (`tools/test_run_tests.sh`) proves the runner fails a `_check_*`
method that is never called or makes no check, and that an untyped declaration does not compile.
