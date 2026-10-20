# carve-wp7 handoff (life 1), 2026-10-20
## State: stood down at ~175k with work left (restart: pacing compare, croc-contact merge)
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
## Evidence so far (head 255f2fd)
- carving suite 7/7 functions, 21 checks pass. Planted defects fail it: takes() false -> 9 fail;
  wear `+=` -> `=` -> the 2 wear checks fail.
- Fixture (tower 3x3x14, kaiju (2.6,0), 60 steps): on 2404 cells carved, 25 chunks partly carved,
  15 chunks down, 0.8 rubble; off 30 chunks down, 2.5 rubble.
- Suites with carve on: sim, powers, tentacles, growth, cells, load pass. military FAILS (2 checks:
  a driving tank crabs 2 of 30813 steps; 55 tank pairs touch); passes with carve off and on the
  carve-wp3 base. Probe (tools/tmp_wp7/probe.gd, untracked): carving topples 2-4x more towers,
  so more roads close (tier 4 seed 2: 19 vs 10) -> latent convoy spacing issue. Lead call.
- Probe, military rampages 600 steps: rubble on/off tier 1 100/82 97/96 53/52; tier 2 370/437
  285/304 289/385; tier 4 2309/2785 1557/2026 3846/2423. Sim time 3-3.5x (tier 4 24-36 s per
  600 steps = 40-60 ms a step in GDScript; WP2 native needed for play).
## Unfinished / next
- Pacing: before (scratchpad/wp7/base copy of carve-wp3) and after, all three species, running.
- Fill pr_body_wp7.md TODOs (untracked, in the worktree). Delete tools/tmp_wp7 at the end.
## Lead ruling (2026-10-20)
- Do not fix convoy here: croc89-sync fixes it on claude/croc-contact (#89). Once pushed, merge
  origin/claude/croc-contact, rerun military; if still red with carving on, report the case.
## Next for the successor
1. Wait for pacing (scratchpad/wp7/after.log, baseline.log); compare stage tables, fill the
   pr_body TODO; if pacing drifts, chunk_alive_share is the knob (ask the lead first).
2. Merge croc-contact when pushed; rerun military; merge look-options once #98 lands there.
3. Delete tools/tmp_wp7 (untracked probe) at the end.
## Running jobs
- background: pacing before (reptilian...) and after (3 species in parallel), scratchpad/wp7.
