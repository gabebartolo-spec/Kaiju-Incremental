# Jets handoff, 2026-10-18
## State: running a check (CI capture of a Colossus under the pass, queued behind military-ai's)
## Task
D-072 (director): all four jets go in, each its own PR into claude/look-options, report to
"Kaiju: Lead". Order: (1) interceptor strafing pass  <- this PR, branch claude/jets-interceptor;
(2) bombs (delta, ground-attack); (3) the bomber as a stage set-piece.
Director's answers (log under D-072): strikes wreck buildings as collateral but pay no biomass;
jets arrive at Colossus (the bomber is the Apex set-piece); the cephalopod can grab a jet. Built.
## Branch and commit
claude/jets-interceptor in ../Kaiju-Incremental-wt/jets, off look-options 2d66383.
746fc05 sim + tests + model; 943b6c1 presentation + sound + capture; 83322c5 the director's
answers (collateral, Colossus, grab, clearance). Pushed. No PR yet.
## What is built
- sim/strike_wing.gd (StrikeWing): call-in like AirWing.cap (after_chunks, max, max_per_chunks,
  first_delay, interval); a pass enters `approach` short of the kaiju, flies across the camera
  (square to camera_bearing +-yaw_jitter, alternate sides), warns (jet_inbound) warn_seconds
  before the first round, lands `rounds` rounds strafe_step apart on a line centred on the
  kaiju's spot (hit = within body radius; damage - armor, floor army.min_damage), leaves at
  2*approach (jet_left). Flies `clearance` over reach_height(). Each round chews the top chunk of
  each column within round_radius (damage_chunks; the rubble is taken back = no biomass).
  hit(): only hit_air attacks (never stomps); clear_dead() pays rubble, emits jet_destroyed;
  tentacles._grab takes jets too (kind "jet"). Seeds.derive 0x7E7.
- Stages: jets.max 0 base, Colossus 1 (after_chunks 600), Apex 2 (after_chunks 900).
- RampageSim: owns `strike`; step after air; hit_area calls strike.hit; result "jets".
  rampage_sim.gd is at the 400-line gdlint cap: damage_cells and _apply merged to make room.
- data/tuning.json `jets` (all numbers), vehicles.jet_heights, sfx volume_db jet_flyby/cannon.
- scenes/jet_model.gd, scenes/jets_view.gd (owned by PowersView, events via its fallthrough).
- assets: build_jets.py -> jet_interceptor.blend/.glb (LFS); tools/blender/vox_jet.py ->
  assets/vehicles/jet_interceptor_body.kvox + .parts.json (byte-identical to the board LEAD passed).
- sfx: build_sfx.py --only jets -> assets/sfx/jet_flyby.ogg, jet_cannon.ogg (synthesized).
- tests: new suite `jets` (11, registered in run_tests.sh, ci_shards, README); smoke 28
  (interceptor loads its voxels); growth 25 (jets from Colossus on).
- capture: tools/capture/capture_tanks.gd --jets (Colossus in its city, one pass, still / 0.5 s).
- Sim-review packet: notes folder jets/sim-review-packet.md (goes in the PR).
## Evidence so far
All 10 suites green locally + harness self-test at 83322c5. Known-bad: rounds that ignore
position fail the dodge check (9 vs 9); a late warning fails the warning check (0.00 s);
collateral that pays biomass fails the collateral check.
## Next
CI capture (1080p --movie) -> stills, 3 s clip, 2x crop -> self QA -> PR body + sim packet ->
LEAD. Then PR 2 (bombs) from a fresh branch once this merges.
## Findings for the lead
- With the line centred on the kaiju the edge rounds land wide, so even with no warning a
  kaiju has ~0.25 s to step off; warn_seconds adds to that. Tune with the stage answer.
## Rules learnt the hard way
- gdlint max-file-lines 400: rampage_sim.gd and powers_view.gd are near it; new views go in
  their own file (JetsView), like RooftopView.
- Strict typing: no `as Dictionary` on a Variant; type event values into locals first.
- Test fixtures: never raise chunks_destroyed past a tiny test city (ends the run); lower the
  threshold instead.
