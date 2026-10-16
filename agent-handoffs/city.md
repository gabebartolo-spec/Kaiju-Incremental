# City handoff, 2026-10-16 21:05
## State: awaiting lead (captures sent for review; PR open into claude/look-options)

## Task
Director 2026-10-16: "our city exists in a void ... far too gridlike, it must look like an
actual city not a grid of isolated buildings"; then "use tokyo and new york as inspiration".
Scope: city layout (sim) + city edges/background + evidence. Not in scope: D-028 building
fidelity (RES 8-12) and D-029 real OSM districts (another helper) - see Open decisions.

## Branch and commit
claude/city-layout-56adda (worktree .claude/worktrees/city-layout-56adda), merged with
origin/claude/look-options at 829bc53 (street life #5 included). PR into claude/look-options.

## What exists now
- sim/city_gen.gd: CityGen.map(cfg) street plan from the config alone (map_seed): long
  Manhattan blocks (block_long x, block_short z), ring avenue at +-half, avenues, alleys, one
  diagonal (Broadway). Returns nodes, streets {from,to,width,kind}, blocks {rect,use}, xs, zs.
  generate(rng, cfg) = buildings of the "built" blocks. half_extent = cfg.half.
- sim/city_lots.gd: lots along block faces with shared party walls, courtyards, two tower
  cores (cfg.cores), front yards in low-rise, pencil buildings, diagonal leftovers = plazas.
- RampageSim: arena_half = half + arena_margin; kaiju spawns at (0, half) on the ring avenue.
- scenes/city_ground.gd (blocks+sidewalks, park, plaza, parking, diagonal, lane lines, zebras,
  quay, bay), city_skyline.gd (outer blocks as facade-shaded boxes, roof clutter, waterfront
  expressway, far skyline + lattice tower + beacons, aircraft lights, outer lamp heads),
  facade.gdshaderinc + facade.gdshader (engine fog) + facade_far.gdshader (own haze).
- BuildingView: floor slabs in a second MultiMesh shown only once a building is broken (GPU
  saving); party_walls() -> blank side walls; BuildingVoxels: vertical neon signs.
- CityDecor rebuilt on the plan. PropField.crush uses 8-unit buckets. Topple rubble strips
  build on WorkerThreadPool.
- Street life ported: Traffic on the graph (one-way side streets by line index parity,
  two-way avenues/diagonal), Police picks crossings()/street_dirs(), StreetLife walks block
  pavements and crosses to the block opposite.
- tests/run_city_tests.gd (city suite, floor 5); ALL_SUITES + ci_shards updated.
- tools/capture/capture_looks.gd: + edge and skyline shots; city_stats.gd prints layout numbers.

## Evidence so far
Tests: smoke 11, sim 39, city 5, flow 14 + harness self-test green; gdlint/gdformat clean.
Capture perf (engine timers, 1080p): young 5.8 ms, evolved 5.5, edge 4.5, skyline 4.2
(before: 5.3 / 5.5). Bench 30 s interleaved with base (another helper's GPU captures running
at the same time): GPU avg base 6.6-8.1 vs city 7.1; frames over 33 ms base 0, city 1 per run
(34.7 / 36.0 ms). Boards: docs/captures/2026-10-16-city/. Full-size shots in the shared notes
folder city-captures/.

## Attempts
- Facade stand-ins rendered black: source_color uniforms are already linear (no second
  srgb_to_linear) and fog_disabled + own fog only for the far shader.
- Flow suite took 535 s in a fresh worktree: LFS fonts were pointers (FreeType error spam
  per frame). `git lfs pull` then reimport: 14 s.

## Open decisions
- D-028 (building RES 8-12) is assigned to "city-layout" in the lead handoff but no brief
  reached this session; start only on the lead's word.
- D-029 real OSM districts: if a baked district returns the same CityGen.map() shape,
  ground, traffic, people and police run on it unchanged.

## Running jobs
None. No override.cfg left. Temp worktrees removed.

## Findings for the lead
- Splitting hidden floor slabs into a lazily shown MultiMesh cut GPU from 7.3 to 5.6 ms on the
  denser city (capture perf line, same stage).
- A merged project.godot fullscreen line blocks every windowed capture (focus guard); already
  fixed upstream in 8cf4a16.

## Rules learnt the hard way
- New worktree: `git lfs pull` before any Godot run, or fonts error every frame.
- Python str.replace replaces every match: assert the count when patching code.
- Godot class cache: run --import after adding a class_name file before --script runs.
