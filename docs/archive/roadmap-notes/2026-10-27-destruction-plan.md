# Destruction in the played game: staged plan, 2026-10-27
Cap: 120 lines. Owner: destruction builder (claude/destruction-1); the lead decides order and merges.
Serves D-327 ("the destructions ship with the demo, the destruction is the game"), D-094 option A, D-311 (render items
10 and 11, built inside this plan), D-326 (no falling, toppling or broken piece ever fades), hard rules 2 and 3.

## 1. What is on main today (audit of 918719d7)
- **The sim already carves in play.** `destruction.carve` is true: `Carving` (sim/carving.gd) promotes a building to
  its fine grid (RES 8 cells a unit) on its first hit, warmed ahead of the kaiju by `WarmOrder`; blows wear columns
  and clear cells (`cells_carved`); `VoxelFrame.settle` (native `KaijuSettle`) finds islands and topples by the support
  rule; `Collapse` turns each part into a timed drop or topple (pivot, dir, duration; the fine `index`/`mats` ride on
  `fall_start`), pays, and crushes the landing strip at `fall_land`. Deterministic, seeded, replay-tested.
- **The view ignores the fine grid.** No scene handles `cells_promoted` or `cells_carved`. A hit shows as whole
  floor-sized chunks switched off plus a cosmetic chip (BuildingView `alive` texture); a fall lifts whole chunks
  (`lift_piece`) and tweens a scripted hinge (ToppleFx), then crumbles into a rubble strip. A fall smaller than a
  chunk's worth (a "scrap") lifts nothing: it is invisible.
- **Built, tested, capture-only:** the fine-grid look (`BuildingView.promote` -> `CellView`/`CellMesher`, native
  `KaijuMesher`, WP4 #103) and the physics view (`CarvePhysics`: `IslandBody` Jolt islands that follow the sim's
  topple ~1 s then break up from the base, `CarveCollider` static colliders of the standing part, `CarveDebris` and
  `CarveRubble`, WP5 #106). Only tools/capture/capture_carve_view.gd and capture_carve_physics.gd create them
  (git log -S: no scene ever did). Render items 10 and 11 speed up exactly this unused code (D-311 correction note).
- **D-326 conflicts in that path:** `CarveDebris.retire`/`_cull` and `CarveRubble` past `rubble_cap` shrink pieces
  away (`fade_seconds`); IslandBody and CarveMesh draw a flat per-material palette, not the building's facade.
- **Costs measured before (WP4 PR #103, one Windows PC):** promotion grid+voxels ~140 ms, CellMesher looks ~50 ms,
  first mesh 40 ms native: all on the main thread in `promote()` today, so it cannot be called as is in play.
  Remesh per carve p95 2.0-2.8 ms native. Spike (DESTRUCTION_SPIKE.md): Jolt 9.5-20.6 ms avg at 2,500-15,000 bodies.
- **Open neighbour:** #288 (facade-carve) changes building_view.gd and building_mesher.gd (proud balcony slabs drawn in
  neither baked mesh); CellMesher still draws them, so it must follow #288 or promotion would pop balconies (D-289).
- claude/destruction-plan was deleted 2026-10-26 (bundle in ~/.claude/handoffs/kaiju); its WP1-WP7 plan is built.

## 2. Stages (each one PR, merged ON by default, its own flag only for the D-299 A/B)
Every stage: test shown red on origin/main first; `bash C:/kt/gh_check.sh` PASS; a kaiju-sim-review packet where sim
changes; ONE 6 s 1080p clip of a building carved and falling in a real rampage, game camera, to the lead unjudged.
Speed check (D-299) for every stage: `tools/capture/bench_driver.sh`, the baseline route (stage 3, Medium, night,
replayed), 3 interleaved rounds of flag off vs on in a bench window; GPU line judged, wall line context; plus one
`bench_frames.gd` run each way for frames over 33.4 ms and the worst-frame handler table.

### Stage 1. The cut you see (flag `destruction.carve_view`)
Player: a blow bites a ragged hole exactly where it lands, cell by cell, not floor by floor; a falling section is the
real cut shape in the building's own facade; sub-chunk scraps fall visibly instead of vanishing.
Change: new `scenes/city_carve.gd` (CityCarve, a CityView child) reads the sim's events. On `cells_promoted` it
builds the building's voxels, CellMesher looks and first mesh on WorkerThreadPool (render resources only on the main
thread, D-295 lint), uploads region meshes under a per-frame budget, and hides the baked shell only once every region
is drawn (no blink). `cells_carved` -> `CellView.carved` over the removed cells' box. `chunks_broken` on a carved
building throws debris and dust without switching chunks off. `fall_start` with `index` lifts a piece meshed from
exactly the part's cells (same mesher, same material) instead of whole chunks; ToppleFx motion and landing unchanged.
CellMesher follows #288's proud-slab rule. Sim untouched.
Bars: (a) seeded rampage test: every building the sim carved is drawn by a CellView whose mesh source equals the sim
grid bytes, every falling piece holds exactly its event's cells (red on main); (b) the shell hides only on a frame
the CellView is fully drawn; (c) promotion is invisible: 4K A/B of promoted-uncarved vs baked, building pixels,
mean <= 1/255, p99 <= 4/255 (#288's bar); (d) speed: GPU mean on <= off + 5%, frames over 33.4 ms on <= off, carve-view
main-thread work <= 2 ms in every frame (its own timer, printed by the bench).

### Stage 2. Render items 11 and 10: the physics view made cheap first (D-311, D-327)
Built as plan.md section 3 says, flags `render_opt.island_merged` and `render_opt.native_colliders`, on the
capture path where the code runs today, so stage 3 enters play at its real cost.
- Item 11: one merged ArrayMesh per IslandBody, meshed on a worker with the old mesh kept until the new is ready;
  shapes added through the body RID. Bars: island of 300 bricks has <= 2 MeshInstance3D (red on main: 300); draw
  calls during a topple down >= 80%; `IslandBody.last_break_us` p95 down >= 50%; topple still pixel diff 0 over 1/255.
- Item 10: `region_boxes()` in native/src/kaiju_carve.cpp mirroring `_brick_boxes` in order; one reused StaticBody3D
  per region, shapes via PhysicsServer3D from a size-keyed BoxShape cache; the GDScript path stays the oracle. Bars:
  digest test native == GDScript boxes over 200 random carved regions (red before the method exists); worst
  CarveCollider rebuild < 2 ms at stage 3; frames over 33.4 ms during collapses down >= 50%; identical settle stills.
- Speed check: capture_carve_physics.gd `--scene=block` (six towers collapsing) off vs on in a bench window.
  Native: build.yml builds the DLL; after merge the lead runs C:/kt/fetch_dll_all.sh.

### Stage 3. It falls for real (flag `destruction.carve_physics`)
Player: a cut tower turns over as the sim decides for about a second, then Jolt takes it: it strikes the street,
breaks up from its base in its own facade, chunks tumble and stay as rubble for the run; carved cells fly out as
debris in their own material; rubble lying on a fresh cut wakes and falls.
Change: CityCarve gives each carved building a CarveSite, CarveCollider and CarveDebris; `fall_start` with `index`
-> `CarvePhysics.fell` instead of the tweened piece. The sim still pays, crushes the strip and moves the street at
its own `fall_land` (Jolt decides nothing, hard rule 3). D-326 in this path: no piece shrinks, fades or is removed
while drawn; past the live cap the oldest live pieces lose their Jolt body and finish their fall as drawn ballistic
pieces that land and stay; past the static cap colliders go, pieces stay; the indoors cull goes; islands, pieces and
rubble draw with the building's own palette (CellMesher's), not CarveMesh's flat one.
Bars: seeded rampage test (red on main): one IslandBody per carved `fall_start` with equal cells; the count of
drawn piece cells never drops between frames except into rubble of the same cells; Jolt bodies <= `debris_live`;
the sim digest identical with the flag on and off over the run (presentation never writes back);
`CarvePhysics.sunk(0.03) == 0`. Speed: frames over 33.4 ms on <= off; GPU mean on <= off + 10%; physics step p99
<= 4 ms at Medium (the bench's physics column).

### Stage 4. Rubble under his feet (D-091, D-110, D-245)
Player: he never clips through a falling chunk or a rubble pile: his feet, legs and tail shove and crunch it
flatter, "well below his knees". Change: a kinematic Jolt body set following his BodyVolume shapes pushes and wakes
pieces (cosmetic); a stomp breaks rubble it lands on (CarveDebris.wake + break), as the sim's D-110 slab rule already
decides for outcomes. Bars: no drawn piece overlaps his body volume for more than 2 physics steps in a seeded
rampage; rubble height under his path <= his knee height after a pass; speed as stage 3.

### After the plan (lead's existing rows, not started here)
Landmarks and river bridges carve on cells ("carve is universal", ROADMAP C, owner lead); the kinematic ToppleFx path
stays for landmarks until then.

## 3. Order, risk and asks
- Order 1 -> 2 -> 3 -> 4. Stage 1 alone puts real carving in play; stage 2 lands the speed-ups before physics enters.
- Risk: the 4K frame is already over 16.7 ms (baseline: GPU p50 24.5 ms Medium, CPU-bound wall ~30 ms). Each stage's
  speed bar is relative to flag off, so a stage that adds cost shows it before it merges.
- Merge order: stage 1 touches building_view.gd (the deferred shell hide) and cell_mesher.gd; it follows #288.
- No stage needs a taste call from the director: the look and motion are his earlier rulings (D-099, D-101, D-110,
  #25/#26, D-326). Each stage's clip goes to him unjudged.
