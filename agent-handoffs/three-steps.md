# three-steps (builder, branch claude/three-steps, worktree ../Kaiju-Incremental-wt/three-steps)
Task (lead brief): D-135 three growth steps (young, Behemoth, Colossus), evolve3 and the Apex row cut, cities ~15% wider.
Lead opens/reads the PR; I push. Godot = Desktop\Godot_v4.7.2...console.exe (no godot_quiet.sh exists on this machine).

## State
- Merged origin/claude/look-options (fire spread #152, turning #149) into the branch; conflicts in upgrades.json (r_beam now evolve2,
  fire nodes kept) and run_military_tests.gd (took origin's RAMPAGE_SEEDS version, header comment only).
- Post-merge touched-suite run: scratchpad full7.txt (fire military powers growth street city sim empty_space flow).
- After-pacing (reptilian, --verbose, timeout 13000 s) running -> scratchpad pace_after_rept.txt. Before: pace_before_rept.txt.
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
