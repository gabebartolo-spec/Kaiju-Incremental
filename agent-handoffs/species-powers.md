# Species-powers handoff, 2026-10-17 00:45
## State: awaiting lead (PR #12 review round 1 fixes pushed, 588369e; CI running)

## Task
Per-species upgrade branches from docs/SPECIES.md (D-035) and helicopters (D-037), sim-first,
with a player-effect fixture per node, placeholder VFX, the branch on the upgrade screen,
captures of each species' first new power. Brief from the lead (local_9fac90d2-fae7-4940-b4ac-144a87f28e6e).

## Branch and commit
claude/species-powers-3c8e02 (worktree .claude/worktrees/city-layout-56adda), PR #12 into
claude/look-options. The PR body holds the branch table, pacing tables, the D-039 projection and
the round-1 fix list.

## What exists
- data/upgrades.json: 12 nodes with "species" (r_tail, r_momentum, r_shear, r_beam; i_scuttle,
  i_glide, i_climb, i_brood; c_hydra, c_squeeze, c_grab, c_ink), row 5, ultimates need evolve3.
- data/tuning.json: "powers" and "air" sections (every tunable from the lead's rule-4 list),
  branch stat defaults (0) in "kaiju", army young_damage_mult.
- sim/species_powers.gd (blocking, momentum, tail, climb, glide, beam, ink, coats),
  sim/tentacles.gd (limbs, grab/throw), sim/brood.gd, sim/air_wing.gd (helis), sim/army.gd (tanks,
  moved out of RampageSim; same RNG stream). RampageSim.step(dt, move, pressed, buttons) with
  HELD / ULTIMATE flags. UpgradeTree.new(defs, levels, species_id) filters other branches.
- Building slow: an unscaled footprint (block_radius 1.3, capped under half a street), tested as
  a circle against the chunk square. Streets are free at every size; alleys hold the body unless Squeeze.
- AirWing: the call-in clock runs only below the cap (no respawn farm).
- scenes/powers_view.gd (placeholder looks; rig hooks through has_method, grab rides limb_tip),
  helicopter_model.gd, Rampage.scripted capture hook and a _steps counter for autoplay, HUD ultimate line.
- tests: run_powers_tests.gd (24), run_tentacles_tests.gd (17), lib/powers_base.gd, flow 26.
- tools/pacing.gd (--species, --verbose, --grow=N), tools/capture/capture_branch.gd.

## Evidence so far
Local run_tests.sh all pass (smoke 11, sim 39, powers 24, tentacles 17, city 5, flow 26, harness
self-test). gdlint/gdformat clean on all .gd. The street-speed and heli-respawn checks were shown
failing on the old code. Clips, stills and contact sheets are in the notes folder species-powers/
(captured before round 1; the blocking change doesn't alter what they show).

## Open decisions
- D-039 city growth decided; cost re-tune is the lead's follow-up (projection in the PR body).
- D-040: ultimates on E / pad Y and hold-to-glide confirmed. Nothing open on my side.
- Rig hooks: tail_sweep/grab/throw/jaw_open/limb_tip pushed on #11 (338b880). climbing(on) asked
  for, not yet built. Not tested against a combined build.

## Running jobs
None. No override.cfg left.

## Findings for the lead
- A pacing tool (scripted player + cheapest-first buys) caught that the tree is about 0.9 h,
  not 3-5 h. Its --grow projection showed that city growth alone doesn't lengthen play.
- Showing a new check failing on the old code caught that my first heli-respawn test would
  not have detected the bug (it killed the heli straight after spawning, before the timer ran out).
- core.autocrlf=true: check_ci_shards.sh fails locally on CRLF working copies (it reads "flow\r").
  It is not a real failure; the committed blobs are LF.

## Rules learnt the hard way
- Write python edit scripts to the scratchpad; heredoc escapes ("\\n") can corrupt GDScript.
- Hand layouts must sit inside the arena (+-44.5): the clamp looks like a slowdown.
- Forcing chunks_destroyed in a test also needs chunks_total raised, or the run ends "fallen".
