# carve-wp1 handoff (builder, WP1 of real carving destruction, D-094)
## State: life 2, review FIX on #97 pushed; awaiting CI and the lead. Do not merge (lead's call).
## Task (life 2)
Answer review-wp1's FIX on PR #97 (comment 6279596456) and add the lead's fixture rule (from #98's
review, comment 6279562193). Branch claude/carve-wp1, worktree ../Kaiju-Incremental-wt/carve-wp1.
## Done (life 2)
1. settle() re-floods after topples: a fresh VoxelSupport, its islands taken and landed like the
   first pass (`_drop_islands`). Reviewer's repro is `_check_resettle`: [topple 832, drop 32], then
   detach() finds nothing. Failed first ([topple] only, 1 part left floating).
2. adopt() returns bool; refuses (push_error, frame unchanged) offset.y != 0, a dim < 1, or
   dims product != bytes. `_check_adopt_guard` (failed first: true true).
3. Replay trace adds per event dir.x, dir.y and the pivot in half cells (round(pivot*2*res)).
   Pinned hashes in TRACE_PINS: tower RES 4 3951767490, tower RES 8 2034646805, block RES 4
   3520931729. Mutation (dir flipped in _tip) fails all three pins and the two topple checks.
   The re-flood did not change these paths (no hung loads on them).
4. Fixture rule: materials' "fixture" (bool, default false) -> VoxelFrame.fixtures (by id) and
   has_fixtures. Structural flood 6-neighbour, structural only; then fixtures join a grounded part
   by 26-neighbour touch (to a labelled cell or a joined fixture), or stand on layer 0. Islands:
   joined by a face, or any touch when either cell is a fixture. Topple box counts structural on
   structural only (fixtures weigh, hold nothing). Tests: edge-only pane stays (same cells as wall
   drop), pane cut free drops whole (16 window cells), wall cell held only by a pane drops.
5. Notes only (PR body): pivot float32; damage() has no wear vs tough_mult 0.35 (WP7 rule).
## Suites
- New suite `voxel_support` (7 functions, 14 checks, about 1 s): moved `_check_overhang` and
  `_check_island_support` there plus the 5 new checks (destruction hit the 400-line cap).
- destruction: 12 of 12 functions, 43 checks, 0 failures (174 s local).
- Bench RES 8 tower, back to back on the shared PC: old settle avg 24.1 / p95 88.3 ms, new avg
  27.9 / p95 80.8 ms (the structural-only check in the flood; no fixtures on the bench path).
## API changes (VoxelFrame)
- adopt() now returns bool (was void). New public: fixtures (PackedByteArray[256]),
  has_fixtures. Everything else unchanged.
## Open / for the lead
- settle() does not re-check the remaining grounded parts for a topple after the re-flood (the
  next settle does). Islands landing on a fixture land on it (landing reads any cell).
- Which materials are fixtures is carve-wp3's data change (claude/carve-wp3).
- Not probed: WP3's real buildings with the fixture rule (needs wp3's fixture list).
