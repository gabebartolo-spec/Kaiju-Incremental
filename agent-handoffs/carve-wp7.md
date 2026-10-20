# carve-wp7 handoff (life 1), 2026-10-20
## State: working (sim side of WP7: Carving wired into RampageSim)
## Task
D-094 WP7 sim side: first hit promotes a building (CellPromoter), stomps / swipes / body contact
(all of hit_area) and even blows (damage_chunks/damage_cells: impacts, coats, powers) carve its
cells; VoxelFrame.settle (VoxelSupport) decides islands and topple direction; events for WP4/WP5.
Rulings: D-097 true physics top priority, carving included; D-099 carved towers fall toward the
cut side wherever the kaiju stands; D-091 big buildings take longer; no empty space.
## Branch
claude/carve-wp7 (worktree ../Kaiju-Incremental-wt/carve-wp7), based on origin/claude/carve-wp3
(#98). No PR: the lead opens it. Merge look-options in once #98 lands there.
## Design (what the code does)
- sim/carving.gd (Carving, owned by RampageSim.carving): per promoted building a Grid (VoxelFrame,
  wear per grid column x floor, live/full cell counts per chunk, dead flags, column->chunk maps).
- Wear rule (WP1 review ask): each column-floor sums every blow's force at that column; a cell
  breaks when sum >= material strength x b.frame.max_hp (chunk_hp x tier). tough_mult still scales
  blows. Uniform strengths (1.0) => same blow count as the chunk rule (tested).
- Chunk Structure kept as a coarse mirror: a chunk dies when live <= floor(full x
  chunk_alive_share); only then it pays rubble / counts destroyed (fallen chunks pay on landing with
  topple bonus). Army, climb, blocking, nearest_standing keep reading chunks.
- Collapse.settle uses Carving.settle for promoted buildings: parts carry "index"/"mats" (fine
  cells), "low", "height", "width", "drop". Fall.width added. A scrap part with no dead chunk lands
  with no pay, no crush, and does not count as a toppled building.
- Events: cells_promoted {building, dims, offset, cells}; cells_carved {building, index, mats};
  fall_start gains index/mats; chunks_broken / tough as before.
- Party walls moved to sim/party_walls.gd (PartyWalls.of); BuildingView.party_walls delegates.
- VoxelFrame.clear_index(i) added. rampage_sim._apply renamed damage_cells (wrapper removed);
  clear_dead_tanks removed (callers use army_units.clear_dead()) to stay under 400 lines.
- Tunables: data/tuning.json destruction.carve (true), destruction.chunk_alive_share (0.5).
- Landmarks unchanged (chunk path until WP6).
## Evidence so far
- tests/run_carving_tests.gd: 7 of 7 functions, 21 checks pass (before the arg refactor).
  Fixture (tower 3x3x14, kaiju at (2.6,0), 60 steps): on 2404 cells carved, 25 chunks partly
  carved, 15 chunks down, 0.8 rubble; off 30 chunks down, 2.5 rubble. Pacing gap to measure.
## Unfinished / next
- Baseline pacing (scratch copy of carve-wp3) running; then pacing after; compare per stage.
- Other suites (sim powers tentacles military cells load growth) with carve on: running.
- Planted-defect proof for the new checks (wear += -> =; carve false).
- pr_body_wp7.md (untracked) in the worktree.
## Open questions for the lead
- (none yet; pacing delta may need chunk_alive_share calibration, a numbers call not taste)
## Running jobs
- background: baseline pacing in scratchpad/wp7/base; suites1.log run.
