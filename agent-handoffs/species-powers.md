# Species-powers handoff, 2026-10-16 23:58
## State: awaiting lead (PR into claude/look-options open; CI pending; pacing question sent to lead)

## Task
Per-species upgrade branches from docs/SPECIES.md (D-035) and helicopters (D-037), sim-first,
with a player-effect fixture per node, placeholder VFX, the branch on the upgrade screen,
captures of each species' first new power. Brief from the lead (local_9fac90d2-fae7-4940-b4ac-144a87f28e6e).

## Branch and commit
claude/species-powers-3c8e02 (worktree .claude/worktrees/city-layout-56adda), PR into
claude/look-options. The PR body holds the branch table (node, cost, needs, play change, sim effect).

## What exists
- data/upgrades.json: 12 nodes with "species" (r_tail, r_momentum, r_shear, r_beam; i_scuttle,
  i_glide, i_climb, i_brood; c_hydra, c_squeeze, c_grab, c_ink), row 5, ultimates need evolve3.
- data/tuning.json: "powers" and "air" sections; branch stat defaults (0) in "kaiju".
- sim/species_powers.gd (blocking, momentum, tail, climb, glide, beam, ink, coats),
  sim/tentacles.gd (limbs, grab/throw), sim/brood.gd, sim/air_wing.gd (helis), sim/army.gd (tanks,
  moved out of RampageSim; same RNG stream). RampageSim.step(dt, move, pressed, buttons) with
  HELD / ULTIMATE flags. UpgradeTree.new(defs, levels, species_id) filters other branches.
- scenes/powers_view.gd (placeholder looks + rig hooks via has_method), helicopter_model.gd,
  Rampage.scripted capture hook, HUD ultimate line, "ultimate" action (E / pad Y).
- tests: run_powers_tests.gd (20), run_tentacles_tests.gd (13), lib/powers_base.gd, flow +4.
- tools/pacing.gd (pacing estimate), tools/capture/capture_branch.gd.

## Evidence so far
Local run_tests.sh all pass (smoke 11, sim 39, powers 20, tentacles 13, city 5, flow 26, harness
self-test). gdlint/gdformat clean. Clips + stills + contact sheets in the notes folder
species-powers/ (reptilian/insectoid/cephalopod _branch.mp4).

## Open decisions
1. Pacing: lead said keep shared costs; branches paced vs the curve (table in PR body; 0.6-0.9 h total).
   flattened by run 11. I recommended "city grows per evolution" as a separate task and left the
   shared costs alone. Question sent to the lead; no answer yet.
2. Ultimate on a second button (E), hold-to-glide: flagged for the director in the PR.
3. Rig hooks tail_sweep(side) / grab(limb, at) / throw(toward) / jaw_open(open): AGREED by
   kaiju-motion (23:57). It is adding them on its PR #11 and will ping when they're pushed;
   PowersView already calls them through has_method, so nothing changes here.

## Running jobs
None. No override.cfg left.

## Findings for the lead
- A pacing tool (scripted player + cheapest-first buys) caught that the tree is about 0.9 h,
  not 3-5 h. Worth keeping for every balance PR.
- core.autocrlf=true: check_ci_shards.sh fails locally on CRLF working copies (it reads "flow\r").
  It is not a real failure; the committed blobs are LF.

## Rules learnt the hard way
- Bash heredocs with `'''` python strings sometimes break; write the python script to the
  scratchpad and run it. Python "\\n" in a heredoc became a real newline in GDScript.
- Fixtures need hand layouts small enough that the young kaiju (body scale 0.5) reaches them.
