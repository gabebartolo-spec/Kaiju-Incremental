# Handoff: serpent slither prototype (builder)

Serves D-197 (the serpent: "an actual serpent ... it needs to slither") and D-198 (sweep "Wide, ~6 m each side",
90 deg turn "About 1.5 s", sidewinding "Yes, as its dash" (NOT built), prototype "Yes, now"). First step only:
slither, turn, stop. No PR, no merge: prototype for the director's judgement via the lead.

## State (2026-10-24)
- Branch `claude/serpent-slither` (from origin/claude/look-options 746e02a1), pushed. Worktree
  `.claude/worktrees/agent-ae5ae30e1d30f454a`. No PR (brief).
- Lead's scale ruling: game units, 40 units long, +/-6 swing; cleared patch, no crushing this step.

## What was built
- `sim/serpent_trail.gd` (SerpentTrail): head centreline recorded every `sample` m of travel (ring buffer by sample
  number; heading, speed, turn lerped per sample within a step). `at(behind)` = point on the path. Pure.
- `sim/serpent_body.gd` (SerpentBody): stick -> speed (accel/decel), heading (turn_rate, turn_accel, lands exactly,
  min_radius so it cannot pivot at rest), moves only along its heading, feeds the trail. Pure, not in RampageSim.
- `scenes/serpent_weave.gd` (SerpentWeave): presentation S-wave. A drawn head pure-pursues a point swinging
  A sin(2 pi s / 40) beside the sim head (5 m ahead), curvature clamped to 1/(1.5 x head_width), and lays its OWN
  SerpentTrail; the drawn body follows that. (Offsetting the centreline per sample was tried first: kinks where a
  turn starts, the inside of a turn folds; 3 variants failed the slip bar, so the method changed.)
- `scenes/serpent_stand_in.gd`: 48 boxes, 2.4 -> 0.4 wide, every 4th darker, head lighter; head leads a turn
  (spring, snaps still). `scenes/serpent_proto.gd/.tscn`: real city ground/sky (noon), buildings left out (all,
  or near a capture route), game camera (CameraTuning at body scale 1.3, follows centreline 0.3 L behind head).
  Play it: `godot --path . res://scenes/serpent_proto.tscn` (WASD/stick). Croc game untouched.
- `data/tuning.json` "serpent" section with `_doc` (all numbers).
- `tests/run_serpent_tests.gd` (suite `serpent`), `tools/capture/capture_serpent.gd`.

## Measured (suite prints them)
- Slip 1.10% of speed (bar 2%; a body-frame wave: 100%). Wave speed 0.039% off forward (bar 1%; bad: 23%).
- Corner-cut 0.0003 m centreline, 0.0002 m drawn (bar 1 voxel 0.12 m; straight spine 5.4 m).
- Still 0.3 s after stop: 0.000000 m/frame; stops 0.50 s after release. 90 deg turn 1.483 s.
- Tightest turn radius 5.19 m, drawn bend 5.41 m (2.2-2.3 body widths, bar 1.5).
- Capture: swath 13.5 m straight (vs street 4, avenue 6), closest strands 3.85 m apart (no self-overlap).

## Evidence
- Suites: `serpent` 7 of 7 functions, 14 checks, 0 failures; `smoke` 13 of 13, 47 checks, 0 failures (local).
- Lints: gdlint, gdformat --check, tuning_keys, complexity_ratchet all clean.
- Clip (local RTX 4070 SUPER, log says NVIDIA, off-screen no_focus override.cfg, removed after):
  scratchpad `serpent_clip/serpent_slither.mp4` (7.0 s, 1920x1080, 60 fps) under the lead session's scratchpad
  `.../b2b0bc5b-915b-4abe-b67a-dbc9a0712bcb/scratchpad/serpent_clip/`.

## What looked wrong / open
- Reads small at the game camera: a ground-hugging 2.4-wide body seen from the croc's adult camera sits mid-upper
  frame over lots of foreground. Camera framing for the serpent is a director/lead call.
- Passes through trees, lamps, cars, people (no crushing this step); the cleared patch is a big empty plaza.
- Stand-in box joints show steps; haze washes the green.
- The drawn S is not the sim footprint (sim centreline vs drawn body): crushing later must use the drawn body or
  move the weave into the sim.
- Native carve DLL absent in this worktree (harmless here; GDExtension load error in logs).

## Next (lead decides)
Director's look at the clip; then (research order) voxel skin + BOUNDS check, helix climb, constrict, tail grab;
sidewinding dash.
