# Audit-sim handoff, 2026-10-22
## State: running a check (trace compare, then the full suite)
## Task
Task 018, package 3 of the code audit: bring `rampage_sim.hit_area`, `convoy._drive`, `structure._topple_check`,
`voxel_support._flood`, `city_gen._blocks` and `city_gen.map`, `city_lots._fill_row`, `claw_swipe._undermine`,
`collapse.settle` under the .gdlintrc limits (40 lines, cc 12) with named helpers, behaviour identical.
Separated from fire spread by director ruling: this branch is on origin/claude/look-options (95f01083) and carries no
fire code. Backup of the old fire-mixed branch: `claude/audit-sim-pre-rebase`.

## Branch and commit
claude/audit-sim, on 95f01083. Not pushed yet (see Running jobs). Never force-push; if the remote branch exists
and is not an ancestor, push to claude/audit-sim-v2.

## What changed (before -> after, lines/cc by the ratchet scanner; helpers all <= 40 lines, cc <= 12)
- collapse.settle 75/19 -> 8/3 (`_fall`, `_topple`, `_fall_event`)
- structure._topple_check 52/23 -> 17/5 (`_floor_loads`, `_held_across`, `_overhang`, `_tip`)
- claw_swipe._undermine 43/18 -> 24/8 (`_lanes`)
- rampage_sim.hit_area 33/17 -> 12/7; the per-building part is `AreaHit.building` (new sim/area_hit.gd; the
  file was at the 400-line cap)
- convoy._drive 62/33 -> 21/8: `_idle`, `_wait`, `hull_rate`, `_back`, new sim/convoy_leg.gd (ConvoyLeg: the
  leg's geometry, pace, stopper, advance), `ConvoyRoute.arrive` (was Convoy._arrive); `_onto_axis` and
  `_sweep_fits` lost their underscore because ConvoyLeg/Convoy call them across classes
- voxel_support._flood 46/26 -> 24/8 (`_take`: label and push one neighbour, same six in the same order)
- city_gen.map 90/23 -> ~34/1 scanner (`_grid_lines`, `_alleys`, `_streets`, `_axis_streets`, `_kind`, `_point`,
  `_diagonal_streets`); city_gen._blocks 80/25 moved to new sim/city_blocks.gd (CityBlocks: `add`, `_cells`,
  `_append`, `_edges`, `_inset`, `_parks_and_plaza`, `_parks`, `_plaza`); city_gen.gd was at the 400-line cap
- city_lots._fill_row 83/24 -> 7/1 (`Row` class, `_row`, `_span`, `_mid`, `_lot_height`, `_lot_rect`, `_entry`)
- tools/lint/complexity_baseline.txt: 7 rows dropped (map, _undermine, settle, _drive, hit_area, _topple_check,
  _flood). `_blocks` and `_fill_row` were never in it (the scanner misses them, below).
- tools/trace_replay.gd (new): the replay-hash tool.

## Evidence so far
- Replay trace: `tools/trace_replay.gd`, seeded runs at stages 1-4 x 3 species x 2 seeds (24 runs) + a hash of the
  generated city layouts and street plans (stages 0-4, 6 seeds). Each run folds every tick's state (kaiju pos/facing/hp,
  rubble, chunks, every building's alive count, every tank's pos/hp, every fall) and the step's events into SHA-256.
  Before (95f01083) vs after: see "Result" below. GDScript flood (native library not built here).
- gdlint, gdformat --check, tuning_keys, complexity_ratchet, check_scripts: clean (344 scripts).
- Corrected cc scan (signature-aware): every function named above is within 40 lines and cc 12.

## Result
IDENTICAL: 24 runs (stages 1-4, 3 species, 2 seeds; 12 end by time, 12 by defeat) + the layout hash b632a13e2539... match line for line, before (95f01083) vs after. Per-run lines in the lead report.

## Sim-review packet (kaiju-sim-review)
- Transitions affected: world tick (RampageSim.step -> hit_area, damage, Collapse.settle, Structure topple check,
  VoxelSupport flood, ClawSwipe undermine, Convoy tank driving); city generation (CityGen.map / generate, CityLots).
  No save schema, recruitment, injury or identity change.
- Invariants: (1) same RNG draws in the same order: map draws xs, zs, avenues x, avenues z, alleys x, alleys z, then one
  roll per block cell in i-major order; `_fill_row` draws terrace height, style, yards, then per lot span, height, roll,
  tower, pencil, style, yard; both held by the layout hash. (2) same float operation order (block edges are kept as 64-bit
  floats, not rounded through a Vector2/4 before the district test). (3) same event stream and order (fall_start fields).
  (4) tank drive: shuffle only when the hull is the stopper and move == 0, as before.
- Not exercised: native (GDExtension) flood path (library not built on this machine; CI builds it), tiers
  past 600 steps at stages 1-2, GDScript flood speed (6 extra calls per cell; the native path is the shipped one).
- Review needed: kaiju-sim-review by a reviewer who is not the author.

## Attempts (fix-loop record)
None failed.

## Open decisions
None. Not done: finding #3's "10 pass-through accessors" in rampage_sim (not a function over a limit; touching
callers is beyond the listed functions). Ask the lead if wanted.

## Running jobs
none (full suite: see report).

## Findings for the lead
- tools/lint/complexity_ratchet.py ends a function at the first line back at the `func` indent, so a multi-line
  signature (closing `)` at base indent) is read as a 2-line function. Missed offenders include CityLots.fill_block
  (49 lines), VoxelSupport.islands (38/17) and landing (41/9), and `_blocks`/`_fill_row` themselves. Fix: skip the
  signature to its closing `:` before counting. Not done here (not in scope).
- A new `class_name` file needs a Godot import before check_scripts or a suite sees it.
