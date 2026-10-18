# Destruction-spike handoff, 2026-10-19
## State: available (spike done: #91 merged ca0b7fc; director picked A, D-094; build waits for demo exe 2, D-083)
## Task
Spike done. Report: docs/research/DESTRUCTION_SPIKE.md (survey, options, 4K cost, effort). This file now
holds the BUILD PLAN for option A, for whoever the lead assigns when D-083's playtest fixes ship.
## Branch and commit
- Report merged (#91). Prototype: claude/destruction-proto d49d241, folder spike/: never merge, keep as is
  (carve_grid.gd = reference algorithm, native_bench.cpp = C++ port, carve_spike.gd = timing/clip harness).
- This handoff: claude/destruction-plan (no PR needed unless the lead wants it on look-options).
## Unfinished changes
None. override.cfg removed. Worktree ../Kaiju-Incremental-wt/destruction removed after this push.

## BUILD PLAN (option A, ~19 agent days; section 5 of the report)
Principle: GDScript reference first (the oracle the replay tests pin), native second (must match the
oracle's digests bit for bit), then wire into the game, then retire the old chunk path.
### Work packages
- WP1 Sim grid + island flood + support rule + replay tests (5 d) ....... FIRST PR, scope below.
- WP2 Native core: GDExtension (godot-cpp, MIT) for carve, flood, region mesher; CI build for Windows
  + Linux, export templates, LICENSING_REGISTER entry for godot-cpp (3 d). Golden test: native digests
  == WP1's GDScript digests on the same fixtures.
- WP3 Building cells in the sim: move BuildingVoxels' cell layout (shell, slabs, windows, archetypes) to a
  pure sim generator, materials and strengths from data/ (no Look, no Node), so sim and view build the
  same grid; lazy promotion (fine grid made on a building's first hit, chunk Structure until then) (2 d).
- WP4 View: region mesher on WorkerThreadPool (native from WP2), only touched 16^3 regions remeshed;
  facade shaders, BuildingFade and the crease pass keep working on the new meshes (4 d).
- WP5 Physics presentation: island bodies follow the sim's topple for ~1 s, then break up from the bottom
  on hard hits (clip r2 rule); carved-cell debris via one MultiMesh per building; live-body cap ~2,000
  city-wide; settled pieces frozen into a static rubble MultiMesh; dust/smoke/fire hooks (3 d).
- WP6 Landmarks + Arcs port (stadium sections on the fine grid) (2 d).
- WP7 Gameplay port: biomass per carved/fallen cell, D-091 base-cutting, army squads on cells
  (army.gd uses frame.alive(cell)), species powers (species_powers, tentacles) on the new API; retire the
  chunk Structure for promoted buildings; pacing run to re-check e1 and tree times (2 d).
### Order and parallelism
- WP1 first, alone: it fixes the sim API everything else calls.
- After WP1: WP2 (native, tools/CI) and WP3 (sim cell generator) in parallel: different files.
- WP4 needs WP2 (native mesher) + WP3 (real cells). WP5 needs only WP1's events: it can run beside WP4
  on the GDScript oracle with small grids (scenes/ debris and islands vs the mesher: different files).
- WP6 after WP3. WP7 last (rampage_sim, army, powers): needs WP1-WP5, one writer.
- At most two building sessions at a time. Sim PRs (WP1, WP3, WP6, WP7) get kaiju-sim-review; WP4/WP5
  get lead 2x + a fresh motion critic on clips and a 4K bench line in the PR body.
### First PR scope (WP1): sim grid + island flood + replay tests
- New pure sim class (proposed `sim/voxel_frame.gd`, VoxelFrame): RES cells per sim unit (RES in
  data/tuning.json, 8), one byte per cell (0 empty, else material id) in a PackedByteArray, x fastest
  then z then y (Structure's order). Port spike/carve_grid.gd: carve_sphere(centre, radius) and
  carve_capsule(a, b, radius) (stomp and swipe sweeps); ground flood (iterative, packed frontier);
  islands in scan order with their materials.
- Support rule on islands AND on the grounded remainder (RFG's fix for Teardown's "held up by a chimney"):
  Structure._topple_check's floor-sum logic at cell level, per connected grounded part. Events keep
  Structure.settle()'s shape ({cells, kind drop|topple, pivot, dir}) so Collapse consumes them unchanged.
- API mirrors Structure where callers need it (alive(c), alive_count, top_below(x, z, y), damage via
  material strength from data), so WP7 is a swap, not a rewrite. Not wired into RampageSim yet: nothing
  the player sees changes in this PR; say so in "What the player sees" and name WP7 as the payoff.
- Tests (sim suite or a new `destruction` suite, with its floor): replay twice -> identical digests every
  tick (spike paths: one tower, block of six, RES 4 and 8); island sizes pinned (35,428 cells for the
  6x6x16 tower path at RES 8, as in the spike); a tunnel leaves the tower standing (side walls hold it);
  a base cut gives exactly one island; an overhang past its support topples; a carve outside the grid is
  a no-op; no clock or RNG in the module (grep check). New checks shown failing first.
- Bench line in the PR body: GDScript carve+flood ms at RES 8 (spike: ~40-140 ms p95 a tower; it is the
  oracle, not the shipping path; WP2 brings it to ~1 ms).
- Out of scope: native code, meshing, physics, building generation (WP3), gameplay wiring (WP7).

## Evidence so far
- Replay identical at RES 4 and 8; native port finds the same islands. 4K: tower 4.1/6.8 ms GPU,
  block of 6 steady 4.3 ms with 5.2k bodies; native tick 7.2 ms p95 (GDScript 488 ms).
- Clips + sheets + 2x crops: side-session-notes/local_106fc100-.../destruction-spike/.
## Attempts (fix-loop record)
- Clip r1 inverted normals + whole-island shatter; r2 fixed (outward normals, materials, bottom-up break).
## Open decisions
None (D-094: option A). The lead schedules WP1 after demo exe 2.
## Running jobs
None.
## Findings for the lead
- GPU timings taken while GDScript stalls the CPU are inflated (clocks drop): a --hold run that stops the
  CPU work isolates the scene's real GPU cost (28 ms "spikes" -> 4.3 ms steady).
- Jolt in Godot has a 10,240-body default limit; 2,500 debris per building x 6 hits it.
- MSVC 2022 is on this PC (vcvars64.bat): a quick C++ port is the fastest way to price native code.
- Teardown's multiplayer (deterministic destruction commands, state-synced physics) is a published
  precedent for our sim/view split; cite it in sim reviews.
## Rules learnt the hard way (under 10 lines)
- Exporting APPDATA to a scratch dir hides Python's user site-packages (cv2): run Python without it.
- Bash /tmp and Windows Python's /tmp differ: pass scratchpad paths to Python scripts.
- focus-guard needs --windowed on the command line and override.cfg present.
