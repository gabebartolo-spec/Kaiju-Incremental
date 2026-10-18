# Destruction spike: real carving, real physics (post-demo, full game)

Director, 2026-10-19: "real dynamic destruction, actual physics and buildings that can be carved by
giant monsters" and "destruction techniques have been successful with voxel graphics in other
projects". Today's chunk/topple system stays for the demo. Spike by session destruction-spike; the lead
turns it into a director board with clips. Nothing here is merged game code. Sources: [n], at the end.

## 1. What has worked elsewhere
**Teardown** (Tuxedo Labs, Dennis Gustafsson). *Carve*: every object is a dense voxel grid, one byte
per voxel indexing a 256-entry material palette [1][2]; a blast clears voxels and the object splits into its
disconnected chunks, each a new object, again and again [3]. *Debris*: each
chunk is a real rigid body; collision detection was written for voxels and a custom solver "inspired
by Erin [Catto]'s work" [4][5]. *Fast*: no cube geometry at all: each object is drawn as its bounding
box and ray-marched through a 3D texture with 2x2x2 / 4x4x4 empty-space mips [3][6]; SIMD and threads
for physics and destruction [4]. *Determinism*: multiplayer sends destruction as commands applied "in
exactly the same way and order on all machines"; voxel data is never sent, and physics is plain state
sync [4]. Gaps: players report houses held up by a chimney [7]; a structural-integrity solver is only a
prototype (one building at 60 fps) [5]. *Transfers*: the voxel grid, the split-into-islands rule and the
deterministic-destruction / cosmetic-physics split. The ray-march renderer does not: it replaces the
whole Forward+ pipeline (shadows, SSAO, SSIL, our facade shaders).

**Red Faction: Guerrilla, Geo-Mod 2.0** (Volition, 2009). *Carve*: no carving; buildings are pre-broken
meshes whose pieces have mass and react to stress and impact [8][9]; a shot or ram damages pieces and
the links between them. *Collapse*: a stress pass propagates load through the links; a group that loses
its path to a root (ground) splits off as one dynamic body with the summed mass of its pieces [10];
weaken the base and the tower falls [9]. *Fast*: pieces and links are authored offline; stress runs in
per-frame slices [10]. *Transfers*: the structural model (links, roots, islands as one body) matches our
`Structure` (support flood + topple), and its load rule fixes Teardown's chimney problem. The pre-broken
look does not suit D-005 voxel art: a wall always breaks along the same seams.

**Instruments of Destruction** (Radiangames, Luke Schneider, ex-RFG lead tech designer) [11]. Unity
2019 + PhysX with custom compute-shader rendering [12]; every structure demolishes piece by piece with
chain reactions [13]. Internals unpublished: the RFG model, proven at indie scale on stock physics.

**CityV reference footage** (`WATCH THIS.mp4`, 590-680 s; no published tech found). What it shows:
buildings chewed into ragged holes with interiors exposed, streams of tiny voxels, smoke and ember
fires. It is the look of Teardown-style per-voxel carving, at city scale, in Unreal (the same video
showcases Voxel Plugin [14]).

**Godot**: Zylann's godot_voxel (C++ module) carves spheres and has `separate_floating_chunks`: floating
voxels inside a box become RigidBodies with convex shapes, kinematic for a moment while colliders
update; it warns the search "can become expensive quickly", box ~30 voxels [15]. Built for terrain,
not buildings; using it means a custom Godot build. Terabase's Voxel Destruction addon (MIT, Godot 4.1+)
draws voxels with MultiMesh, threads the work, debris modes [16]. Jolt is deterministic only with the
same binary and the same call order; cross-platform needs a special build flag Godot does not set [17].
So Jolt can animate debris but must not decide outcomes (hard rule 3), exactly Teardown's split.

## 2. Where we are today
`sim/structure.gd`: 1-unit chunks; `settle()` drops what lost the ground and topples what overhangs its
support. The view's RES 8 voxels (`BuildingVoxels`) are cosmetic: a hit hides whole chunks, falls are
tweened (`FallMotion`), debris is <= 600 Jolt boxes. A hole is always 1x1x1; a collapse is scripted.

## 3. Three options, each a proven recipe
**A. Teardown's carving + RFG's support rule, on our renderer (prototyped).** The sim owns the RES 8
grid the view already draws (one byte per cell = material, Teardown's format). A blow carves a sphere;
a flood from the ground finds islands (Teardown split, RFG root rule); `Structure`'s topple rule runs on
each island's support so towers lean and fall rather than float. Islands and carved cells are sim
events; the view remeshes only the 16^3 regions touched, turns islands into Jolt bodies that break up
from the bottom on each hard impact, and carved cells into Jolt debris. Carve, flood and mesher are C++
(GDExtension). *Rules 2-3*: integer grid, fixed scan order, no RNG: same blows, same grid (Teardown's
multiplayer relies on the same property). Biomass, crushes and the landing footprint come from the sim's
island cells and topple rule; the view follows that topple for the first second, then hands the body to
Jolt to break up; Jolt debris is cosmetic (Teardown's state-synced physics). *Memory*: 295k cells a
6x6x16 building, ~100 MB for a city, so a building gets its fine grid the first time it is hit.

**B. RFG/Instruments of Destruction: pre-broken pieces + links + stress.** Each archetype is cut offline
(Blender cell fracture) into 100-400 pieces with links; the sim holds the piece graph, damages links,
runs the stress pass and splits islands (RFG [10]); Jolt animates only detached pieces. *Rules 2-3*: fine
if the sim owns the graph; Jolt joints must not decide breaks (call order, frame rate [17]). *Look*:
shards along baked seams, no hole where you actually hit; conflicts with D-005 and the CityV target.

**C. Teardown in full: GPU voxel volumes, ray-marched, + coarse sim graph.** Buildings as 3D textures,
carved by compute, drawn by a ray-march pass [3][6]; debris as GPU particles; the sim keeps today's
chunk graph as the authority. *Rules 2-3*: fine (the fine shape is cosmetic) but fine shape and coarse
graph can disagree at chunk edges. *Cost*: a second renderer beside Forward+ (shadows, SSAO, SSIL, fog,
facade shaders redone) through RenderingDevice: the biggest build and risk.

## 4. Frame cost (measured for A; B and C estimated)
RTX 4070 SUPER, 3840x2097 off-screen window, Godot 4.7.2 Forward+ (SSAO, SSIL, glow, fog, shadows, MSAA
2x), five other agents' Godot processes running. Grey stand-in towers, no city/army/props, RES 8.
`--block` = six towers carved at once and cut through at the base: a city block collapsing.

| Prototype run | GPU avg / p95 | Jolt avg / p95 | live bodies |
|---|---|---|---|
| one tower, 2,500 body cap | 4.1 / 6.8 ms | 9.5 / 16.6 ms | 2,500 |
| block of 6, carving stopped at 1.5 s (steady) | 4.3 ms | 11.1 / 15.3 ms | 5,200 |
| block of 6, full collapse, 2,500 cap each | 12.4 / 39.3 ms* | 20.6 / 31.6 ms | 15,000 |

\* Spikes come from the GDScript remesh stalling the CPU 100-600 ms (GPU clocks drop; zero-debris runs
spike the same); the moment carving stops the same scene renders at 4.3 ms. The 15,000 run hit Jolt's
10,240-body limit: cap live debris at ~2,000 city-wide and freeze settled pieces into a static rubble
MultiMesh (no body). Debris draws as one MultiMesh per building, not a mesh per body (Terabase does
the same [16]).

| Carve + flood + mesh, block of 6, RES 8, per 30 Hz tick | tick p95 | flood p95 | mesh p95 |
|---|---|---|---|
| GDScript (prototype) | 488 ms (sim 140 + mesh 348) | - | - |
| C++, one thread (`spike/native_bench.cpp`, MSVC /O2) | 7.2 ms | 4.2 ms | 3.5 ms |
| C++ at RES 16, one thread | 31.9 ms | 26.2 ms | 5.4 ms |

GDScript is ~70x too slow, as Teardown and godot_voxel both imply by being native; C++ fits a 33 ms tick
on one thread and spreads per building over `WorkerThreadPool`. RES 16 costs 4x memory, 6x flood.
Estimates: **B** GPU ~2-4 ms, Jolt 6-15 ms for 6 x 300 linked pieces. **C** 6-12 ms GPU at 4K for the
ray-march alone (Teardown-class), CPU light.

**Determinism (A)**: `carve_spike.gd --replay` runs the sim twice and compares every tick's grid digest,
carved count and island sizes: identical at RES 4 and 8 (601 entries; islands 8,415 / 35,428 cells).
The C++ port finds the same islands (35,428; block 201,639), so the rule fixes the outcome.

## 5. Build effort (agent days, with tests and a clip)
| | A | B | C |
|---|---|---|---|
| Sim (grid or graph), support rule, events, replay tests | 5 | 6 | 4 |
| Native: GDExtension + CI/export, Windows and Linux | 3 | 0 | 2 |
| Mesher / renderer (regions, workers, facade detail) | 4 | 2 | 15-25 |
| Physics: islands, break-up, debris cap, rubble freeze | 3 | 5 | 4 |
| Content: archetypes, landmarks, Arcs port | 2 | 6-10 (fracture bakes) | 3 |
| Gameplay port (biomass, D-091 base-cutting, army) | 2 | 2 | 2 |
| **Total** | **~19** | **~21-25** | **~30-40** |

## 6. Recommendation: A
It is the proven Teardown recipe (voxel grid, split into islands, deterministic destruction with
cosmetic physics) plus RFG's proven fix for its weak spot (support and topple), drawn by the renderer we
already have. It carves where the monster hits, keeps the voxel look (D-005, CityV) and one structural
model in the sim (rule 3), and the spike measured it: deterministic replay, a block collapse at ~4-5 ms
GPU at 4K, a 7 ms native tick. It extends `Structure`, `BuildingVoxels` and `DebrisField`. New: a C++
GDExtension in the build (godot-cpp is MIT) and a debris budget.
Smaller first step if wanted: keep 1-unit sim chunks but carve the view's voxels inside a hit chunk by the
blow's sphere (cosmetic, seeded by the sim event) and give falling sections the Jolt break-up; ~6 days,
GDScript only; holes are round, but buildings still fail chunk by chunk.

## 7. Clips and files
- Clips (1080p, 10 s, off-screen no_focus, override.cfg removed): `carve_one.mp4` (tunnel at floor 9,
  base cut in two passes, the top drops and breaks up from the bottom), `carve_block.mp4` (six towers),
  contact sheets and 2x crops: session notes folder `destruction-spike/`. Known gaps: no dust or smoke,
  one debris size, the upper block stays a clean box until its next hit; orange sphere = the blow.
- Prototype (never merge): branch `claude/destruction-proto`, `spike/` (usage in carve_spike.gd's header).

## Sources
[1] blog.voxagon.se/2020/12/03/spraycan.html [2] blog.voxagon.se/2024/12/29/year-summary.html
[3] acko.net/blog/teardown-frame-teardown/ [4] 80.lv/articles/teardown-developer-breaks-down-multiplayer-and-voxel-destruction-tech
[5] 80.lv/articles/this-real-time-voxel-building-demolition-is-so-satisfying/ [6] juandiegomontoya.github.io/teardown_breakdown.html
[7] steamcommunity.com/app/1167630/discussions/0/2998794978529876575/ [8] redfactionwiki.com/wiki/Geo-Mod_2.0
[9] gameinformer.com/games/red_faction_guerrilla/b/ps3/archive/2009/09/22/review
[10] github.com/DevelopmentStatus/rfg-physics-sandbox (Docs/destruction_reference.md; unofficial reverse engineering)
[11] radiangames.com/pkrg/instruments/index.html [12] steamcommunity.com/app/1428100/discussions/0/3190242182152123491
[13] store.steampowered.com/app/1428100/ [14] github.com/leonsavvidi/VoxelPlugin
[15] voxel-tools.readthedocs.io/en/latest/api/VoxelToolLodTerrain/ [16] github.com/Terabase-Studios/Godot-Voxel-Destruction
[17] jrouwe.github.io/JoltPhysics/ (Deterministic Simulation)
