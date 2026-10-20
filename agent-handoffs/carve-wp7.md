# carve-wp7 handoff (life 2), 2026-10-20
## State: life 2; sim side PR-ready except pacing (after runs still going) and the military case
## Task
D-094 WP7 sim side: first hit promotes a building (CellPromoter), stomps / swipes / body contact
(all of hit_area) and even blows (damage_chunks/damage_cells: impacts, coats, powers) carve its
cells; VoxelFrame.settle (VoxelSupport) decides islands and topple direction; events for WP4/WP5.
Rulings: D-097 true physics top priority, carving included; D-099 carved towers fall toward the
cut side wherever the kaiju stands; D-091 big buildings take longer; no empty space.
## Branch
claude/carve-wp7 (worktree ../Kaiju-Incremental-wt/carve-wp7). Contains carve-wp3 (#98),
look-options up to WP1, and claude/croc-contact a1bdca1 (#89) merged (fafc9f9). Not yet: look-options
WP2-4 (#99 native, #103 view). No PR: the lead opens it from pr_body_wp7.md (untracked, worktree).
## Design (what the code does)
- sim/carving.gd (Carving, RampageSim.carving): per promoted building a Grid (VoxelFrame, wear per
  grid column x floor, live/full cells per chunk, dead flags, column->chunk maps).
- Wear: each column-floor sums every blow's force; a cell breaks at strength x chunk_hp x tier.
  Blows scaled by Growth.dwarf_mult (D-091, from #89). No "tough" event (#89 removed it).
- Chunk Structure kept as a coarse mirror: a chunk dies at live <= floor(full x chunk_alive_share),
  pays then (fallen ones on landing with topple bonus). Army, climb, blocking read chunks.
- Carving.settle parts: index/mats/low/height/width/drop plus "base" (lowest-layer footprint) and
  "gutted" (nothing under, taller than narrower side); Collapse applies #89's gutted topple to them.
- Events: cells_promoted, cells_carved {index, mats}, fall_start + index/mats (+ cut_dir from #89).
## Evidence (head fafc9f9 + pacing pending)
- carving 7/7 functions 21 checks pass (fixture claws off: #89's rake reaches past the stomp).
- flow, powers, cells, growth, tentacles, load pass after the merge (carving on).
- sim: see pr_body (timing under investigation: 560-900 s locally after the merge vs 104 s before).
- military carving on: 2 failures (3/41306 tank-steps crab; one tank 1.7 s in danger radius);
  carving off on the same code: passes. Reported to lead, not fixed (lead ruling).
- Step cost: profiled (pr_body): settle 35%, promote 16%, wear 11%; worst step 4.7 s.
## Pacing (PAUSED by director order 2026-10-20 18:50; runs stopped)
- Before = copy of carve-wp3 (lead 6's cde796d6.../scratchpad/wp7/base); done: cephalopod 4.21 h,
  insectoid 3.51 h (~85 min wall each). Not done: reptilian before, all 3 after (killed at ~2h20m;
  pacing.gd prints only at the end; after is ~3x slower). Results, run.sh, probes, pr_body backup:
  side-session-notes/local_962460da-.../carve-wp7-pacing/. Rerun: run.sh <before|after> <proj> <species>.
## Open items for WP7 (from WP6 sim review, lead 8; not started)
- building_view.gd:121 promote() takes BuildingCells only: widen to CellGrid for WP6 LandmarkCells
  (view file; on look-options, not this branch).
- First stadium hit builds its grid in ~246 ms (hitch): same as promotion cost here (16% of step,
  up to 550 ms/building); native or pre-build fixes both. Details: side-session-notes/
  local_30225153-.../wp6-review.md
## Next for the successor
1. Merge look-options (now has #89, #99 native, #103 view) into carve-wp7; rerun carving/sim.
2. Pacing: rerun the 4 missing runs (or with --runs cap), fill the pr_body TODO table.
3. Delete tools/tmp_wp7 (untracked probes) at the end. pr_body_wp7.md is untracked in the worktree.
