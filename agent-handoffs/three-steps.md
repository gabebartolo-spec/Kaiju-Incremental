# three-steps (builder, branch claude/three-steps, worktree ../Kaiju-Incremental-wt/three-steps)
Task (lead brief, D-135/D-136 + comment #100): cut evolve3 and the 4th growth row, widen the 3 cities ~15%, prove it.
No PR from me; the lead opens it. Godot: Desktop\Godot_v4.7.2...console.exe; DLL copied from ../fire-spread/native/bin (gitignored).

## State (edit, never append)
- Edits done (uncommitted at the time of writing): data/tuning.json (3 stages, half 48/80/145, coast_z -118/-150/-215 (gap 70
  kept), districts [48,80,145], district_lot_grow [0,1,2], rooftop + size_pitch arrays 3 long), data/upgrades.json (evolve3
  gone; r_beam, i_brood, c_ink require evolve2), tools/pacing.gd, capture kit/scripts, tests (see diff).
- breath_snout_ahead [10.4,10.4,10.3,13.5] left alone on purpose: indexed by 1-based size_tier, slot 0 is spare, so it is already
  baby/adolescent/adult.
- No jet/bomber set-piece exists in code at this tip; nothing to move.
- To do: full suite (log in scratchpad full1.txt), re-pin street digest, pacing before/after, adult-city frame time before/after
  (tools/capture/bench_rampage.gd --stage=3), sim-review packet below, commit + push.

## Sim-review packet (fill in at the end)
