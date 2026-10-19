# carve-wp5 handoff (builder, WP5 physics presentation of carving)
## State: working (code written, headless logic runs; next: push + CI captures)
## Task
WP5 of option A (D-094): island bodies follow the sim topple ~1 s then break up from the bottom on hard
hits; carved-cell debris one MultiMesh per building; live cap ~2,000 city-wide; settled pieces frozen into a
static rubble MultiMesh; dust/fire hooks. Not wired into the rampage (WP7). No PR (lead opens it).
## Branch
claude/carve-wp5 from origin/claude/look-options, worktree ../Kaiju-Incremental-wt/carve-wp5.
## Plan / files (all written)
- scenes/carve_site.gd (CarveSite): grid placement/size/palette; scenes/carve_mesh.gd (CarveMesh):
  outward-normal voxel face mesher; scenes/carve_collider.gd (CarveCollider): static boxes per brick.
- scenes/carve_physics.gd (CarvePhysics): city-wide manager, budget, building colliders, hooks.
- scenes/island_body.gd (IslandBody): per-brick meshes + boxes, follow phase, bottom break.
- scenes/carve_debris.gd (CarveDebris): per building PhysicsServer3D debris + live/rubble MultiMesh.
- data/tuning.json "carve_physics" section (after landmark_burst, away from WP1's edits).
- tools/capture/carve_grid_stub.gd: capture-only copy of spike carve_grid + cell topple rule (swap to
  VoxelFrame when carve-wp1 pushes).
- tools/capture/capture_carve_physics.gd: --scene=tower|swipe|block, stills + stats.
## Evidence
- Local headless (Godot console exe on Desktop, APPDATA=scratchpad/appdata): tower topples (46,915-cell
  island at t=2.53). Run 1 found: pieces seated 0.17 below ground (fixed: lift on spawn, no freeze
  below ground), no quit in headless (await frame_post_draw never fires; fixed).
## Open issues
- WP1 event shape for cells/pivot unknown: adapter accepts PackedInt32Array indices or Array[Vector3i];
  pivot read in local cell units.
