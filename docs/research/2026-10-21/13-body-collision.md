# Whole-body kaiju collision: blocking versus carving (stopping limbs and tail clipping into buildings)

Researched 2026-10-21. Scope: per-bone collision for a node-per-bone voxel kaiju against a carved voxel city
in Godot 4.7.2, and the rule for when contact carves and when the body gives way. Repo read-only.

## Key findings

1. **The sim already has an authoritative body volume, and it carves everything it touches.** It does not block.
   `sim/body_contact.gd` (BodyContact) puts a chain of discs along the heading. Each disc is
   `[forward offset, radius, bottom, top]`, set per stage in `data/tuning.json` `contact.bodies`. The chain
   sweeps between steps and "breaks every standing chunk it overlaps as it walks or turns". `_hold()` only
   holds or slides the body against a building that dwarfs the kaiju (D-091), where contact chews at `bite_dps`.
   Two gaps follow. (a) Only `reptilian` has discs (`contact.bodies` keys = `['reptilian']`); the cephalopod
   and insectoid have no volume and "only slow in walls". (b) The disc chain is a straight line along
   `heading`, but the drawn tail is a Verlet spring chain (`scenes/kaiju_rig.gd` `simulate_chains`) that
   swings off that line. Any swing off the line clips into chunks the sim never touched. That clipping is
   presentation drifting from the sim, not missing destruction. (Repo: `sim/body_contact.gd` lines 1-8 and
   94-128; `data/tuning.json` "contact".)
2. **Position-based dynamics (PBD) makes collision for the tail and tentacle chains almost free to add.**
   Müller et al. regenerate collision constraints each step, outside the solver loop. Each one is an
   inequality `C(p) = (p - q)·n >= 0` with stiffness 1, where q is the entry or closest surface point and n
   the normal. They are projected together with the distance constraints. The scheme "is unconditionally
   stable", and the authors call the artifacts from missed collisions "negligible". The rig's
   `SpringChain.ground` clamp (`pos[i].y = maxf(pos[i].y, chain.ground)`) is already a one-plane version of
   this. Generalising it to "push a joint out of solid cells along the open-face normal", inside the
   existing `CONSTRAINT_PASSES` loop, is the textbook fix. — [Müller, Heidelberger, Hennix, Ratcliff,
   "Position Based Dynamics", VRIPHYS 2006 (journal version: JVCIR 2007)](https://matthias-research.github.io/pages/publications/posBasedDyn.pdf)
3. **Godot's built-in per-bone collision and IK tools all assume a Skeleton3D. This rig has none.**
   - PhysicalBone3D "is a physics body that can be used to make bones in a Skeleton3D react to physics", driven
     through a parent PhysicalBoneSimulator3D. — [Godot docs: PhysicalBone3D](https://docs.godotengine.org/en/stable/classes/class_physicalbone3d.html)
   - SpringBoneSimulator3D, which handles tails and hair and collides with "self-standing" SpringBoneCollision3D
     shapes unrelated to PhysicsServer3D, is a SkeletonModifier3D on a Skeleton3D. — [Godot docs: SpringBoneSimulator3D](https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html)
   - The IK framework that returned in 4.6 (IKModifier3D with TwoBoneIK3D, FABRIK3D, CCDIK3D and others) is
     also SkeletonModifier3D-based. — [Godot blog: IK returns in 4.6](https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/)

   `scenes/kaiju_rig.gd` uses one Node3D per bone with its own MultiMesh skin. Adopting any of these means a
   rig migration, so they are a poor first step here. Their design is worth copying: a collision radius per
   joint, plus sphere and capsule colliders that push and slide the chain.
4. **PhysicsServer3D shape queries (ShapeCast3D, `intersect_shape`) need collision shapes, and the carved
   buildings have none.** Rebuilding colliders on every carve costs more than reading the grid directly. The
   query API caps results (`max_results`, default 32) and can exclude RIDs. The docs give no per-query cost. —
   [Godot docs: PhysicsDirectSpaceState3D](https://docs.godotengine.org/en/4.2/classes/class_physicsdirectspacestate3d.html).
   In this repo Jolt is used only for debris (`scenes/carve_debris.gd`: bare PhysicsServer3D bodies, no
   building colliders). The sim's own grids are the real geometry: `VoxelFrame.alive(c)`,
   `top_below(x, z, below_y)` and `column_top`, at `destruction.res = 8` cells per sim unit, with the chunk
   Structure as a coarse mirror. Presentation already reads them, e.g. `scenes/ability_fx.gd:252` calls
   `b.frame.top_below(...)` to stop a beam at a roof.
5. **Shipped giant creatures work with obstacles, not by colliding every bone.** For Trico (The Last Guardian):
   - The landing point is chosen when the foot lifts.
   - The walk avoids objects it cannot step on and corrects its path around obstacles.
   - It ducks under low ceilings.
   - The head look-at "detects walls and pillars" so the head does not get caught.

   This is pose correction on top of authored motion ("keeps adjusting original animation"), not full-body
   physics. The same talk credits foot IK to Ico and procedural horse-spine work to Shadow of the Colossus;
   it gives no colossus foot details. — [gameanim.com write-up of Masanobu Tanaka, CEDEC 2017](https://www.gameanim.com/?p=15474)
6. **Spore placed feet procedurally on unknown bodies: animation goes in as morphology-independent targets,
   and an IK solver poses each creature at runtime.** This is the precedent for one gait serving every body
   plan and growth stage. — [Hecker et al., SIGGRAPH 2008](https://chrishecker.com/Real-time_Motion_Retargeting_to_Highly_Varied_User-Created_Morphologies).
   Overgrowth reportedly drives everything from very few keyframes plus procedural spring layers (the
   13-keyframe figure is secondhand). — [GDC 2014, Rosen, "An Indie Approach to Procedural Animation"](https://www.gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation).
   The rig's feet plant on a flat plane (`scenes/gait_biped.gd:179` `var ground := root.origin.y`). So a foot
   on rubble or a roof edge sinks or floats; it never stands on top.
7. **Practitioners say tails in geometry are mostly accepted, or designed around.** Collision IK for tails is
   unstable when many contacts conflict. One answer: "design your level so that this is minimized", or use "a
   collision-based IK solution to bend the tail after its natural animation". It warns that physics gets
   "notoriously unstable" with conflicting contacts, and that many games don't bother. —
   [Unity Discussions: tail entering objects](https://discussions.unity.com/t/characters-tail-entering-other-objects-and-meshes/860045).
   Indie kaiju jams report kaiju "getting stuck in objects" and clipping through floors after heavy
   destruction. — [itch.io search results, 2024-26](https://itch.io/post/12507710) (comments only; low evidence).
8. **The big kaiju brawlers make contact destructive rather than blocking.**
   - GigaBash (UE4) maps are "fully destructible", and monsters can step on, pick up and throw cars, buses
     and office buildings. — [Wikipedia: GigaBash](https://en.wikipedia.org/wiki/GigaBash)
   - Godzilla: Destroy All Monsters Melee has buildings that "cave in and crumble" and that monsters throw
     opponents into. — [GameSpot preview](https://www.gamespot.com/articles/godzilla-destroy-all-monsters-melee-preview/1100-2879542)

   No source documents per-limb blocking in these games. The genre default looks like "the body is a
   destroyer, the limbs are not checked". This game asks for a finer rule than any of them publish.
9. **Cost: what decides it is how many cells are read, not how many bones there are.** The rigs have 27
   (reptilian), 32 (insectoid) and 43-79 (cephalopod) bones (`assets/kaiju/*.rig.json`). One sphere per bone
   at 60 fps is about 1.6k-4.7k sphere tests a second. A sphere of radius r sim units reads about (2r)^3
   cells: roughly 8-64 on the 1-unit chunk mirror, but 512-32k on the fine grid (res 8). Rough figures, my
   arithmetic, not measured:
   - Coarse chunk tests are cheap even in GDScript.
   - Fine-grid sphere fills belong in C++. `native/src/kaiju_carve.cpp` already binds `carve_sphere` over the
     same grid layout, so a read-only `overlap_spheres` (a batch of spheres in, depth and normal per sphere
     out) is a small addition.
   - Broadphase: BodyContact `_near()` already culls buildings by the swept AABB, so most frames test zero
     buildings.

## What goes in the sim and what goes in presentation

| Concern | Layer | Why / existing hook |
|---|---|---|
| Whether the kaiju's root may enter a building (block, slide, or carve through) | **Sim** | Decides outcomes and rubble; seeded and replayable. Hook: `BodyContact.step()`, `_hold()`, `_sweep()` |
| Rule for when contact carves: attack event, dash, forward speed above a threshold, dwarf chewing | **Sim** | Gameplay rule; tunable in `data/tuning.json` `contact` (no magic numbers) |
| Body volume per species and stage (discs, or capsules per segment) | **Sim (data)** | `contact.bodies`; the cephalopod and insectoid have none today |
| Tail sweep on a fast turn carving (the current disc rule) | **Sim, director call** | Today the rear discs break chunks on a turn; "idle sway should not destroy" needs the sim tail to be either non-carving or swing-aware |
| Occupancy queries (`alive`, `top_below`, `column_top`, chunk mirror) | **Sim API, read by both** | Pure reads of `VoxelFrame` and Structure; presentation may read sim state |
| Tail and tentacle joints resting against walls and roofs (PBD push-out) | **Presentation** | Visual only; `KaijuRig.simulate_chains` passes; never writes the grid |
| Feet and tentacle grips planted on roof or rubble height | **Presentation** | `gait_biped` ground plane becomes a heightfield sample; footfall events unchanged |
| Head and arm look-at bending away from a wall (Trico-style) | **Presentation** | `aim()` target nudge; optional |
| Any carve caused by a limb (stomp, swipe, tentacle strike) | **Sim event** | Already sim: `carve_sphere` and `carve_capsule`, `claw_swipe.gd`, `tentacles.gd _strike` |

## Sources

- Müller et al., Position Based Dynamics (VRIPHYS 2006): https://matthias-research.github.io/pages/publications/posBasedDyn.pdf
- Godot docs, PhysicalBone3D: https://docs.godotengine.org/en/stable/classes/class_physicalbone3d.html
- Godot docs, SpringBoneSimulator3D: https://docs.godotengine.org/en/stable/classes/class_springbonesimulator3d.html
- Godot blog, Inverse kinematics returns to Godot 4.6: https://godotengine.org/article/inverse-kinematics-returns-to-godot-4-6/
- Godot docs, PhysicsDirectSpaceState3D: https://docs.godotengine.org/en/4.2/classes/class_physicsdirectspacestate3d.html
- gameanim.com on Tanaka's CEDEC 2017 Trico talk: https://www.gameanim.com/?p=15474
- Hecker et al., Real-time Motion Retargeting (Spore), SIGGRAPH 2008: https://chrishecker.com/Real-time_Motion_Retargeting_to_Highly_Varied_User-Created_Morphologies
- Rosen, GDC 2014 procedural animation (coverage): https://www.gamedeveloper.com/design/video-an-indie-approach-to-procedural-animation
- Unity Discussions, tail entering objects: https://discussions.unity.com/t/characters-tail-entering-other-objects-and-meshes/860045
- itch.io kaiju jam comments (low evidence): https://itch.io/post/12507710
- GigaBash: https://en.wikipedia.org/wiki/GigaBash
- Godzilla DAMM preview: https://www.gamespot.com/articles/godzilla-destroy-all-monsters-melee-preview/1100-2879542
- Teardown dev blog index (no character-collision post found): https://blog.voxagon.se/
- Repo, read-only: `scenes/kaiju_rig.gd`, `sim/body_contact.gd`, `sim/voxel_frame.gd`, `sim/carving.gd`,
  `sim/tentacles.gd`, `scenes/gait_biped.gd`, `scenes/ability_fx.gd`, `scenes/carve_debris.gd`,
  `native/src/kaiju_carve.cpp`, `data/tuning.json`, `assets/kaiju/*.rig.json`

## For Kaiju Incremental (ranked, simplest viable first)

1. **Tail and tentacle joints yield to walls with a PBD push-out, in presentation.** Cost: about 40-60 lines
   in `kaiju_rig.gd` and 0.5-1 day.
   - Give each chain joint a radius (from its bone's voxel extent, already in `_voxels`).
   - Once per `simulate_chains` call, before the passes, get the buildings near the kaiju (the BodyContact
     `_near` pattern).
   - Inside the existing `CONSTRAINT_PASSES` loop, push any joint whose cell is solid in the chunk mirror (or
     `frame.alive`) out along the nearest open face, and clamp y to the column top.
   - The distance constraints already in the loop keep the chain whole, so the tail bends along the wall
     instead of entering it.

   No sim change, no determinism risk. This fixes "idle tail sway clips" outright.
2. **Feet and grips stand on what is there.** Cost: about 20 lines in `gait_biped`, `gait_hexapod` and
   `gait_radial`, and 0.5 day.
   - Replace the flat `ground := root.origin.y` with a per-foot heightfield sample:
     `top_below(x, z, h) + 1` over the building under the foot, or the street.
   - The planted foot then rests on rubble and roofs. Add a stretch cap so a foot never reaches a roof above
     the knee: it steps around instead, like Trico choosing the landing point at lift-off.
   - Set the tentacle `chain.ground` from the same sample.
3. **The sim decides block versus carve with one rule.** Cost: about 1 day plus a seeded test (a
   `kaiju-sim-review` packet). Director call on the rule:
   - Contact carves only when an attack event, a dash, or forward speed into the wall above
     `contact.carve_speed` drives it. Otherwise BodyContact holds and slides (`_hold()` already does this for
     dwarfing buildings).
   - Make the rear (tail) discs non-carving unless the turn rate is above a threshold (a tail swipe).
   - "Walking past" then yields; "walking into" still carves.
4. **Body discs for every species and stage.** Cost: data only, about 0.5 day per species, judged against a
   capture. Fill `contact.bodies` for `cephalopod` and `insectoid`, so their root blocks or carves the way the
   reptilian's does, rather than only slowing.
5. **Batched sphere query in C++, only if steps 1-2 show up in the profiler.** Cost: about 1 day. Add
   `KaijuCarve.overlap_spheres(PackedVector4Array) -> PackedVector4Array` (depth plus normal) over the
   fine grid. Keep the GDScript chunk-mirror path as the oracle, to match the "native port must match its
   digests" rule in `voxel_frame.gd`. This brings fine-cell accuracy for all 79 cephalopod bones at
   negligible cost.
6. **Do not adopt PhysicalBone3D, SpringBoneSimulator3D, IKModifier3D or PhysicsServer shapes now.** All of
   them need a Skeleton3D migration or building colliders rebuilt on every carve, and they duplicate what the
   grid query already gives. Accept small clipping on fast attacks: the carve makes it true a frame later.

## Evidence gaps

- No primary source documents how Shadow of the Colossus colossi, Monster Hunter monsters, Horizon machines,
  the PS4 Godzilla or GigaBash handle limb-versus-building contact.
- Teardown's character-versus-voxel method is not published on the voxagon blog.
- Godot publishes no per-query cost for `intersect_shape`.
- The cell-count budget above is arithmetic, not a measured profile of this repo.
- The PBD journal year (2007, JVCIR) is from memory; the PDF read is the VRIPHYS 2006 version.
