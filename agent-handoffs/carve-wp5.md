# carve-wp5 handoff (builder, WP5 physics presentation of carving)
## State: life 2. Pushed 2a5f7af; CI captures (tower, swipe, block) running sequentially; then crops + PR body
## Task
WP5 of option A (D-094): island bodies follow the sim topple ~1 s then break up from the bottom on hard
hits; carved-cell debris one MultiMesh per building; live cap ~2,000 city-wide; settled pieces frozen into a
static rubble MultiMesh; dust/fire hooks. Not wired into the rampage (WP7). No PR (lead opens it).
## Branch
claude/carve-wp5 (from origin/claude/look-options), worktree ../Kaiju-Incremental-wt/carve-wp5.
Merged origin/claude/carve-wp1 (d8174d4) at a085399: clean swap, stub deleted.
## Files
- scenes/carve_site.gd (offset, from_local for VoxelFrame's building-local pivot, indices(event) reads
  "index"), carve_mesh.gd, carve_collider.gd, carve_physics.gd, island_body.gd, carve_debris.gd.
- data/tuning.json "carve_physics". Capture: tools/capture/capture_carve_physics.gd (VoxelFrame via
  tests/lib/destruction_paths.gd office()), carve_view_stub.gd (stands in for WP4 mesher).
## Evidence (local headless, console exe, isolated APPDATA, --fixed-fps 30; scratchpad g.sh)
- Swap check: tower numbers identical to the stub run (island 46,915 cells t=2.53, 7 breaks, 2,548 pieces).
- Sinking: before (life 1) sunk=30-54 per SEC sample, lowest -0.142. Fix = CarveDebris._raise: a live piece
  below ground_y - ground_slop is lifted onto the road (in _physics_process before the freeze check and in
  _draw_live before drawing, so no drawn frame shows it sunk). After, tower: sunk 0-6 in the physics state
  sampled before the draw fix, end lowest -0.020 (= slop); 4,812 lifts, deepest 0.255.
- Swipe: 0 islands, 2,531 bodies, live max 1,785, phys 4 ms avg, lowest -0.019.
- Block: 6 islands, 38 breaks, 14,350 pieces, 12 fires; live max 3,216 (cap soft, fading), all max 7,732
  (< Jolt 10,240); phys 64 avg / 147 p95; sim (GDScript carve) 131 avg; 23,022 lifts (pile pressure).
- Tried and reverted: island mass power-law (mass_power): sinking lower (block sunk <=15) but breaks fell
  38->14 / 7->2 and a resting island never slept (phys 181 ms idle). Linear mass kept.
## Next
1. CI captures -> scratchpad ci_<scene>; crops of contact/break frames (*_crop2x.png); view crops only.
2. Fill pr_body_wp5.md Evidence / Not exercised (untracked); report to lead.
## Open issues
- Block: many repeated lifts under piles may read as jitter; check the block clip at contact.
- Rubble MultiMesh grows unbounded per building; no merge yet. Sim carve cost is GDScript (WP2 native).
