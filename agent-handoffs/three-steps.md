# three-steps (builder, branch claude/three-steps, worktree ../Kaiju-Incremental-wt/three-steps)
Task (lead brief): D-135 three growth steps (young, Behemoth, Colossus), evolve3 and the Apex row cut, cities ~15% wider.
Lead opens/reads the PR; I push. Godot = Desktop\Godot_v4.7.2...console.exe (no godot_quiet.sh exists on this machine).

## State
- Merged origin/claude/look-options (fire spread #152, turning #149) into the branch; conflicts in upgrades.json (r_beam now evolve2,
  fire nodes kept) and run_military_tests.gd (took origin's RAMPAGE_SEEDS version, header comment only).
- Post-merge touched-suite run: scratchpad full7.txt (fire military powers growth street city sim empty_space flow).
- After-pacing DONE (reptilian, 400-run cap, 109 runs, wall 3533 s; scratchpad pace_after_rept.txt). Before (old cities, 87 levels): evolve1 0.12 h, evolve2 1.02 h, evolve3 2.85 h, last 3.30 h; young 0.12 / Behemoth 0.90 / Colossus 1.83 / Apex 0.46 h. After (new cities, 95 levels, the base also gained 8 fire levels): evolve1 0.16 h (run 9), evolve2 1.28 h (run 55), r_beam first level 2.11 h (run 88), LAST unlock 2.62 h (run 109); young 0.16 h, Behemoth 1.12 h, Colossus 1.35 h. Target about 2 h: 2.62 h is 31% over. Cost rows: r_beam 845,820 rubble over 3 levels (160,020 / 266,700 / 419,100) is the tail (after evolve2 at 1.28 h the Colossus runs earn 31-45k each, 34 of 54 end in defeat); tree total 2,390,295 rubble. No balance changed.
- Not run on purpose: frame-time before/after (CPU at 100%, numbers are noise; one 4K pair gave gpu avg 43.8 vs 43.6 ms but
  CPU-contended, 80 vs 109 frames); full suite (GitHub does it; a pre-merge full run was green, 25 suites).

## Packet: kaiju-sim-review (transitions)
- Save/reload: SaveFile.VERSION 2 -> 3. migrate() drops nodes in tuning "save"."refunds" (evolve3: 444500 per level) and banks
  the refund; v1 saves migrate through v3 too. Test tests/lib/flow_save.gd: v2 save with evolve3 + r_beam comes up v3, node gone,
  rubble +444500, r_beam/evolve2 kept, tree size 3; re-migrating a v3 save changes nothing; a v2 save without the node keeps its bank.
- Generation: city plan spans 3 districts (50/80/150 half, coast 70 m past each edge). Rooftop squads now stand on their column's
  real top (a squad could float over an empty column); RiverQuay (city.river_quay) puts crate stacks on the street side of the river's
  edge (nothing parks or is lit beside water, so those cells were bare); prop only, no RNG.
- Identity: r_beam, i_brood, c_ink require evolve2 (ids unchanged). evolve3 removed from the tree.
- Determinism: all seeds unchanged; fixtures re-pinned (list in the PR body).

## Fixture changes (PR body)
- tests/lib/fixture_rings.gd: city_diag_fill (seeds 1, 43, 50) and junction_island (40, 55, 60) and the sim suites build the
  pre-widening plan (rings 42/70/125/210): in the widened plans none of ~500 seeds needs the diagonal fill (7 do) or the island
  (0 do) once RiverQuay covers the riverside; old seeds kept.
- Street digest 3ce3931c7b6a5cdc -> 1532d9c3297b48fe (plan changed). Camera ADULT 1.7 -> 1.3 body scale. flow_sfx pitch pair
  [1,4] -> [1,3] with size_pitch [1.3,1.12,0.88] (the adult keeps the deepest voice).
- Not exercised: topple/swipe fixtures pick a shed when no tier-2 tower is in the arena; a real tall tower fails 'nothing inside the
  body' at seeds 3, 8, 22 (8-102 chunks); pre-existing, handed to the VFX lead's collapse item. Seed 108 (stage 1) leaves one bare
  cell at a bridge crossing. Frame time before/after skipped (noise). 

## Army contact after wider cities (PR note; probe = 12 seeds, 40 s autoplay, old rings vs new, same code)
- Cause: army tank entry. Young: arena 52.5 + entry_depth 10 = 62.5 > army.spawn_radius 60, so entries flipped from the city edge
  (old 54.5 <= 60) to "round the kaiju"; Behemoth/Colossus: fewer tanks reach range. Data fix only: growth.stages[].army.spawn_radius
  64 / 52 / 57 (young / Behemoth / Colossus); no speed or damage change.
- Old rings | new, row off | new, row on  (contact seeds of 12, tanks that reach range, mean share of tank-steps in range)
  young    2, 3, 0.28%  | 0, 0, 0.00%  | 3, 3, 0.29%
  Behemoth 9, 20, 3.39% | 7, 9, 1.72%  | 10, 18, 3.32%   (r52)
  Colossus 12, 32, 1.45%| 7, 12, 1.00% | 10, 19, 1.55%   (r57; r48 gave 2.45%, r56 1.92%, r58 1.12%)
- Military fixture: RAMPAGE_SEEDS 3,6,9 -> 3,11,15,25 (MIN_PARKED_IN_RANGE 20 and the 95% band unchanged; 2,3,11 gave 21 here, 16 on CI = float drift, repeats exact
  on one machine). Seeds 0-70 at the Behemoth park in range on only 3 (5), 11 (16), 15 (20), 25 (13), 42 (7), 17 (2). Military now: 38 tank-steps, band 100%.
  Growth "army that learnt" now sums city seeds 0-5 (local ratio 1.71, each 1.45-2.17; seed 0 alone read 1.54 here, 1.26 on CI), bar 1.3 kept.
  Save: v3 refund step kept beside the base's city_seconds default (#161).
- Driving-hull check: with Colossus r48 the check saw 3 of 23790 tank-steps past 10 deg (tier 3 seed 3, tank 3, hull turning
  6 deg a step at the south ring avenue z ~150.2, the plan edge; on a road, no rubble there). Not reproduced at r57/r58; root cause not
  found (a tank turning while moving at a junction on the plan edge); bar not widened.
