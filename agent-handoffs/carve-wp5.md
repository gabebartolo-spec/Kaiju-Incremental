# carve-wp5 handoff (builder, WP5 physics presentation of carving)
## State: life 5 done, PR-READY at 0017d9c on claude/carve-wp5 (pushed, look-options merged, gdlint/gdformat green). PR NOT opened: the lead opens it when a slot frees. Body: pr_body_wp5.md (untracked, in this worktree; copy it out, do not commit it).
## Life 5
- Splits finished (094f74a, fa00f37), behaviour unchanged. island_body.gd is exactly 400 lines (the lint cap).
- No fires from breaks more than fire_ground 1.5 above ground (tower fires 44 -> 6, block 39 -> 27).
- Contact-frame break path (body_entered on a StaticBody3D). Captures: identical to before, so the ~0.3 s late landing break was NOT reproduced.
- Split chunks keep the parent's layer/mask (carried in the split payload) and IslandBody.cell_material (kept on remeshes). Probe: 9/9 chunks ok. carve-play/WP7 should set island.cell_material instead of looping over meshes.
## Left (carried into WP7 integration, D-103, critic round 3)
- Block shear sawtooth; chunks behind panes on a swipe; tower slab propped on its teeth.
- Fires are not moved with the island once started.
- No suite covers CarvePhysics/IslandBody; proof is the headless captures.
