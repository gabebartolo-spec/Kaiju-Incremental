# carve-wp5 handoff (builder, WP5 physics presentation of carving)
## State: stopped at the 200k guard after a save point (pushed 079f0a6 + this handoff); restart from 'Next'
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
- Local headless tower (Desktop Godot console exe, APPDATA=scratchpad/appdata, --fixed-fps 30), run 3:
  topple island 46,915 cells at t=2.53, 7 bottom breaks, 2,548 pieces, 1 fire; live max 2,112 (cap 2,000
  soft, fading excess), all bodies max 5,411 (< Jolt 10,240), rubble 4,793. Break 23 ms avg / 39 max
  (was 270: brick spans now cached); wall 88 ms avg; phys 53 avg / 139 p95 (headless, shared PC, not GPU).
- Fixed on the way: pieces seated in the road (lift on spawn, no freeze below ground); headless never quit
  (await frame_post_draw); wake churn (street rubble no longer woken; static -> rigid in place).
## Next (in order)
1. Open issue: ~4% of live pieces (sunk=30-54 of ~1,200) reach >0.03 below the road while moving (tiny 1/8
   boxes under piles; lowest -0.14). Try: Jolt CCD already on; raise debris size floor or lower
   debris_per_carve, or a thicker min box; re-measure 'sunk' in the SEC lines.
2. Headless swipe + block runs (--scene=swipe|block) for errors and counts.
3. CI captures: tools/capture/ci_capture.sh --movie capture_carve_physics.gd -- --scene=tower --out=<dir>
   (then swipe, block; run sequentially, the helper picks the newest run). 2x crops: *_crop2x.png.
4. Fill pr_body_wp5.md (untracked) Evidence/Not exercised; report run ids to the lead. No PR.
## Open issues
- WP1 event shape for cells/pivot unknown: adapter accepts PackedInt32Array indices or Array[Vector3i];
  pivot read in local cell units (CarveSite.to_world). Swap the stub for VoxelFrame when wp1 pushes.
- Rubble MultiMesh grows unbounded per building (4,793 a tower); no merge yet.
- GDScript island meshing per brick: first spawn of a 47k-cell island not timed separately yet.
