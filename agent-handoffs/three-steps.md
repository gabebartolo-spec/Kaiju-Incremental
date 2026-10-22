# three-steps (builder, branch claude/three-steps, worktree ../Kaiju-Incremental-wt/three-steps)
Task (lead brief, D-135/D-136 + comment #100): cut evolve3 and the 4th growth row, widen the 3 cities ~15%, prove it.
No PR from me; the lead opens it. Godot: Desktop\Godot_v4.7.2...console.exe; DLL copied from ../fire-spread/native/bin (gitignored).
Director pause: no Godot until 22:40 (2026-10-22). Baseline worktree ../Kaiju-Incremental-wt/three-steps-base (detached, delete at the end).

## State (edit, never append)
- WIP commit cf317593 on claude/three-steps (not pushed yet): data/tuning.json (3 stages; rooftop + size_pitch arrays 3 long;
  size_pitch [1.3,1.12,0.88] keeps the deepest voice on the adult, because flow's "baby > adult x1.2" bar needs the gap),
  data/upgrades.json (evolve3 gone; r_beam, i_brood, c_ink require evolve2), tools/pacing.gd, capture kit/scripts
  (stage4_memory.gd -> adult_memory.gd, bench_rampage.gd --stage=N), tests (growth, powers, flow_layout, fade_spawn, scans,
  military, street replay, camera, README rows).
- breath_snout_ahead [10.4,10.4,10.3,13.5] left alone on purpose: indexed by 1-based size_tier, slot 0 is spare, so it is already
  baby/adolescent/adult. No jet/bomber set-piece exists in code at this tip; nothing to move.
- Rings back to 50/80/150 (lead: 75 breaks the ~15% ruling; fix the generator). New generator rule: scenes/river_quay.gd (RiverQuay,
  data city.river_quay): crate stacks every 8 m on the street side of the river's water edge (nothing parks / no lamp beside water,
  so those cells were bare); untested until 23:35. Then re-run empty-ground over shipped seed + 20 others (scan_half.gd / city suite).
- Done since: save v3 migration (tuning "save"."refunds" evolve3 444500; test tests/lib/flow_save.gd); sim/army.gd rooftop squads use the
  column's real top (a squad floated over an empty column, found by luck); tests/lib/sim_suite.gd CITY_SEED 0 -> 3 (seed 0 has no tall
  tier-2 office in the half-50 arena; the topple/swipe fixtures need one; offices exist at seeds 3, 8, 22).
- TODO after the 23:35 Godot pause: (1) re-run city empty_space sim sim_play military street streamview flow load; (2) re-pin
  city_diag_fill SEEDS {1,43,50} and junction_island SEEDS {40,55,60} (premise: bare cell without the fix, none with it) by scanning
  seeds, record old+new for the PR body; (3) street PINNED digest (run prints the new one: deliberate plan change); (4) military
  "tanks hold standoff": 0 parked-in-range tank-steps (4410 in reserve) at 48/80/145; hypothesis: arena 52.5+entry_depth 10 > army
  spawn_radius 60 at half 50 flips the entry mode; probe scratchpad probe_mil.gd; diagnose, never loosen; fixture scans: scan_fix.gd;
  (5) pacing after + bench_rampage --stage=3 before/after; (6) full suite; (7) packet, push, remove three-steps-base worktree.
- Pause rule: no Godot until 23:35 (director). Check `date`.
- Baseline numbers: pacing before (reptilian) runs in the base worktree -> scratchpad pace_before_rept.txt; baseline tests
  base1.txt. After: pacing + bench_rampage --stage=3 (render, off-screen, override.cfg already in the worktree) on both trees.

## Sim-review packet (fill in at the end)
Transitions: save/reload (evolve3 level in an old save is dropped silently, its 444500 rubble not refunded: lead call, no
migration written), tick (none), generation (city plan now spans 3 districts), identity (r_beam/i_brood/c_ink requires).
