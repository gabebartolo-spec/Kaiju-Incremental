# Destruction spike: real carving, real physics (post-demo, full game)

Director, 2026-10-19: "real dynamic destruction, actual physics and buildings that can be carved by
giant monsters"; today's chunk/topple system stays for the demo. Spike by session destruction-spike;
the lead turns this into a director board with clips. Nothing here is merged game code.

## Where we are today
- **Sim** (`sim/structure.gd`): a building is a grid of chunks, 1 sim unit each way, one floor tall.
  `settle()` drops parts cut off from the ground and topples a part whose centre of mass hangs past
  its support (`_topple_check`); `Arcs` breaks stadium walls in sections. Pure, seeded, headless.
- **View**: `BuildingVoxels` draws 8 voxels per sim unit (RES 8), but they are cosmetic: a hit hides
  whole 1-unit chunks (`hide_chunks`) and throws up to 600 Jolt boxes (`DebrisField`); falling
  sections are tweened (`FallMotion`), not simulated; `LandmarkBurst` hides landmark cut faces.
- So a hole is always a 1x1x1 block, a collapse is a scripted rotation, and the debris is confetti.

## Three options

### A. Fine sim voxels + native carve/flood/mesher + Jolt debris (prototyped)
- **How**: the sim owns the RES 8 voxel grid the view already draws (one byte per cell: material).
  A blow carves a sphere/capsule; a flood from the ground finds every island cut loose; each island
  is a sim event. The view remeshes only the 16^3 regions touched, turns carved cells into Jolt
  debris and each island into a Jolt rigid body that breaks up from the bottom on each hard impact
  (the clip). Carve, flood and mesher are C++ (GDExtension); everything else stays GDScript.
- **Hard rules 2-3**: integers, fixed scan order, no RNG in the carve, so the same blows give the same
  grid and the same islands (measured below). Jolt never decides an outcome: biomass, score and
  crushed props come from the sim's island cells plus a sim-side landing footprint (today's
  drop/topple rule applied to the island's support polygon). The view kinematically follows that
  topple for the first second, then hands the body to Jolt to break up, so what you see lands
  where the sim says. Jolt debris is pure presentation, as today.
- **Memory**: 295k cells per 6x6x16 building; a whole city at RES 8 is ~100 MB, so a building is
  promoted from today's chunk Structure to a fine grid the first time it is hit (lazy).
- **Look**: ragged sphere-shaped holes with floors exposed inside, chunks of the building's own
  material; the closest of the three to the CityV target (WATCH THIS.mp4, 590-680 s).

### B. Pre-fractured pieces with breakable joints
- **How**: each building archetype is cut offline (Blender cell fracture) into 100-400 pieces glued
  by Jolt joints that break past a force; a blow breaks joints, pieces fall under Jolt.
- **Hard rules 2-3**: Jolt in Godot is not built for cross-platform determinism, and joint breaking
  depends on solver order and frame rate, so Jolt cannot be the authority. The sim would need its
  own piece graph (piece = node, glue = edge with strength) to decide every break, with Jolt only
  animating detached pieces: two structural models to keep in step.
- **Look**: shards, not voxels; breaks only along baked seams (no carving where you actually hit);
  conflicts with D-005 (voxel art) and the CityV target. Every new archetype needs a fracture bake.

### C. GPU voxel destruction (Teardown style) + coarse sim graph
- **How**: buildings live as 3D textures / brick maps on the GPU; carving is a compute shader;
  rendering is a ray-march or GPU-side meshing; debris is GPU particles. The sim keeps a coarse
  brick graph (today's chunks) that decides support and islands.
- **Hard rules 2-3**: fine (the coarse sim graph is the authority, GPU detail is cosmetic), but the
  fine shape you see and the coarse graph that decides can disagree at brick edges.
- **Cost**: a custom renderer beside Forward+ (shadows, SSAO, SSIL, fog, the facade shaders all have
  to be re-done for ray-marched voxels) via RenderingDevice; the biggest build and the biggest risk.

## Frame cost (measured for A; estimated for B and C)
Measured on this PC (RTX 4070 SUPER, 3840x2097 window off-screen, Godot 4.7.2 Forward+, SSAO, SSIL,
glow, fog, shadows, MSAA 2x) with five other agents' Godot processes running, so CPU times are high.
Scene: grey stand-in buildings only (no city, army or props); `--block` = six towers carved at once
and cut through at the base: a city block collapsing.

| Prototype run (RES 8) | GPU avg / p95 | Jolt avg / p95 | live bodies |
|---|---|---|---|
| one tower, 2,500 body cap | 4.1 / 6.8 ms | 9.5 / 16.6 ms | 2,500 |
| block of 6, carving stopped at 1.5 s (steady) | 4.3 ms | 11.1 / 15.3 ms | 5,200 |
| block of 6, full collapse, 2,500 cap each | 12.4 / 39.3 ms* | 20.6 / 31.6 ms | 15,000 |

\* The GPU spikes come from the GDScript remesh stalling the CPU for 100-600 ms (GPU clocks drop;
zero-debris runs spike the same); as soon as carving stops the same scene renders at 4.3 ms.
The 15,000-body run also hit Jolt's 10,240-body limit. Lesson: cap live debris at ~2,000 city-wide
and freeze settled pieces into a static rubble MultiMesh (no body). Debris draws as one MultiMesh
per building, not a mesh per body.

Sim + mesher cost per 30 Hz tick, same carve paths:

| Block of 6 at RES 8 | tick p95 | flood p95 | mesh p95 |
|---|---|---|---|
| GDScript (prototype) | 488 ms (sim 140 + mesh 348) | - | - |
| C++, one thread (`spike/native_bench.cpp`, MSVC /O2) | 7.2 ms | 4.2 ms | 3.5 ms |
| C++ at RES 16, one thread | 31.9 ms | 26.2 ms | 5.4 ms |

GDScript is ~70x too slow; native fits in a 33 ms sim tick on one thread and spreads per building
over `WorkerThreadPool`. RES 16 is not worth it (4x memory, flood 6x slower).

Estimates (not prototyped): **B** GPU ~2-4 ms (few hundred pieces a building), Jolt heavy while
joints hold (6-15 ms for a block of 6 x 300 jointed pieces). **C** GPU 6-12 ms at 4K for the
ray-march alone (Teardown-class figures), CPU light.

## Determinism evidence (A)
- `carve_spike.gd --replay`: sim run twice, every tick's grid digest, carved count and island sizes
  compared: identical at RES 4 and RES 8 (601 entries each, one island of 8,415 / 35,428 cells).
- The C++ port gives the same islands as the GDScript (35,428 cells; block 201,639 = 201,618 + three
  7-cell islands), so the algorithm, not the language, fixes the outcome.

## Build effort (days of agent work, including tests and a clip)
| | A | B | C |
|---|---|---|---|
| Sim structure (grid or graph), events, replay tests | 4 | 5 | 4 |
| Native code: GDExtension + CI/export for Windows/Linux | 3 | 0 | 2 |
| Mesher / renderer (regions, workers, facade detail) | 4 | 2 | 15-25 |
| Physics: islands, break-up, debris cap, rubble freeze | 3 | 5 | 4 |
| Content: archetypes, landmarks + Arcs port | 2 | 6-10 (fracture bakes) | 3 |
| Port gameplay (biomass, D-091 base-cutting, army) | 2 | 2 | 2 |
| **Total** | **~18** | **~20-25** | **~30-40** |

## Recommendation: A
It is the only option that carves where the monster actually hits, keeps the voxel look the
director chose (D-005, CityV), keeps one structural model in the sim (rule 3) and was proven here:
deterministic replay, a 4K block collapse at ~4-5 ms GPU, and a native tick of 7 ms. It also
extends what exists (Structure's support rules, BuildingVoxels' RES 8 grid, DebrisField) rather
than replacing it. The two things it needs that we do not have yet: a C++ GDExtension in the build
(new tooling: CI matrix, export templates, licence of godot-cpp is MIT) and a debris budget rule.

Simpler first step if the director wants less: keep the sim at today's 1-unit chunks but carve the
view's RES 8 voxels inside a hit chunk by the blow's sphere (cosmetic, seeded by the sim event) and
give falling sections the Jolt break-up from the clip. About 6 days, GDScript only, no new tooling;
holes are sphere-shaped, but buildings still fail chunk by chunk.

## Clips and files (for the lead's board)
- Clips (1080p, 10 s, off-screen no_focus, override.cfg removed after): `carve_one.mp4` (one tower:
  tunnel at floor 9, base cut in two passes, the top drops and breaks from the bottom up) and
  `carve_block.mp4` (six towers), plus contact sheets and 2x crops, in the session notes folder
  `side-session-notes/local_106fc100-.../destruction-spike/`.
- Prototype (throwaway, never merge): branch `claude/destruction-proto`, `spike/` (carve_grid.gd,
  carve_view.gd, carve_spike.gd, native_bench.cpp). Re-run: `godot --headless --path . --script
  spike/carve_spike.gd -- --replay --res=8`; timing: add `--windowed --resolution 3840x2160
  --fixed-fps 60` with the no_focus override.cfg, `-- --res=8 --block [--hold=1.5]`.
- Known gaps in the clip (2x check): no dust or smoke (the game's Fx would add them), carve debris
  is one size, the upper block stays a clean box until its next impact, orange sphere = the blow.
