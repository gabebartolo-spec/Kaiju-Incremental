# Tests

One command runs everything CI runs (import, every suite, the harness self-test):

```sh
GODOT=/path/to/godot_console tools/run_tests.sh            # everything
GODOT=/path/to/godot_console tools/run_tests.sh smoke      # some suites
```

Every run gets its own user data (APPDATA and the XDG dirs point at a temp dir), so two
agents' runs never share saves, settings or caches. The rules are the `game-architecture`
skill §6 and the `kaiju-godot-tests` skill: one runner per suite extending
`tests/lib/runner.gd`; a floor per suite in `expected_checks.txt` that only goes up; a
`SCRIPT ERROR` fails the suite; seeds pinned; a new suite registered in `ALL_SUITES`
(`tools/run_tests.sh`), `tools/ci_shards.txt`, `expected_checks.txt` and the table below.

## Suites

| Suite | Covers | Floor |
|---|---|---:|
| `smoke` | typing warnings are errors; exactly the sanctioned autoloads; every script compiles; the main scene opens headless and stays up | 9 |
| `clips` | the croc titan's baked Blender clips (D-047) load and fit its rig; the walk phase follows distance; turn, roar and idle play without NaN; a walking curve swings the tail and it settles; the clips own the tail bones; the roar tail slam lands as one footfall; other kaiju keep procedural gaits | 14 |
| `military` | the army moves and fights like a professional military (D-066): tanks drive the road plan, never into a building, a lot or an alley; no two tanks as drawn (hull, turret, gun) ever touch; a driving tank keeps its hull within 10 degrees of its road and a parked one squares to it; parked tanks hold their firing band or reserve and leave the danger radius; road entries; helicopter pairs (13 m apart across the ground, wingman stacked higher, never crossing), attack runs, nose within 20 degrees when firing, altitude that follows the roofs and comes back down, break-off when faced, never flying into the kaiju; a toppled tower re-routes a column; player-effect fixture (facing the helicopters down); the clip scene through the game camera: helicopters whole in frame and off the HUD, tanks' drawn parts never touching, air.view pinned to the camera; over whole rampages, helicopters in frame and off the HUD per stage | 22 |

The harness self-test (`tools/test_run_tests.sh`) proves the runner fails a suite short of
its floor or without one, and that an untyped declaration does not compile.
