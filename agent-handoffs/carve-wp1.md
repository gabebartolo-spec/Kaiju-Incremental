# carve-wp1 handoff (builder, WP1 of real carving destruction, D-094)
## State: done, awaiting lead (lead opens the PR into claude/look-options)
## Task
WP1 per `git show origin/claude/destruction-plan:agent-handoffs/destruction-spike.md` ("First PR scope (WP1)").
Pure sim VoxelFrame (sim/voxel_frame.gd + sim/voxel_support.gd), RES in data/tuning.json "destruction"
(identical blob to carve-wp3), new `destruction` suite, bench tools/destruction_bench.gd. Not wired into
RampageSim. PR body: pr_body_wp1.md in the worktree (untracked).
## Branch and worktree
claude/carve-wp1 from origin/claude/look-options; worktree ../Kaiju-Incremental-wt/carve-wp1 (remove after merge).
## Done
- VoxelFrame: carve_sphere/carve_capsule (force vs material strength), damage/remove/alive/top_below,
  adopt(dims, offset, cells) for WP3's BuildingCells (offset = building-local cell of grid 0),
  detach() (spike rule) and settle() (support rule), Structure-shaped events + "mats" + "index".
- Materials: caller passes the list (data/materials.json shape, WP7 passes Content.materials()); no
  materials table added here (coordinator: wp3 owns data/materials.json).
- Tests green: destruction 13/13 functions, 45 checks; sim 13/13, 53 checks. Fail-first: stub run 21 red,
  offset stub 4 red, mutation run (unclamped carve + res 4) 13 red incl. outside no-op and data.
- Island pins hold: RES 4 [8415], RES 8 [35428] (detach). With the support rule the tower path gives one
  topple of 38,866 cells instead (it tips after the first base pass).
- Bench RES 8 (local, shared PC): tower tick avg 23.9 / p95 63.2 ms; block of six avg 146 / p95 371 ms.
## Open / for the lead
- Suite takes 125-228 s locally (replays at RES 8 twice): re-measure CI timings after merge.
- Interpretation: island support = landing on the least-gap columns (topple if COM past them).
- Seam for WP2: grid is `cells` (public PackedByteArray) + adopt(); native carve takes cell units
  (VoxelFrame converts: centre * res - offset).
