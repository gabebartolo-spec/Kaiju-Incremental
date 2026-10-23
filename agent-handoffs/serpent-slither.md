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
- `scenes/serpent_stand_in.gd`: 48 boxes, 3.6 -> 0.6 wide, every 4th darker, head lighter; head leads a turn
  (spring, snaps still). `scenes/serpent_proto.gd/.tscn`: real city ground/sky (noon), buildings left out (all,
  or near a capture route), its own camera (round 2 below).
  Play it: `godot --path . res://scenes/serpent_proto.tscn` (WASD/stick). Croc game untouched.
- `data/tuning.json` "serpent" section with `_doc` (all numbers).
- `tests/run_serpent_tests.gd` (suite `serpent`), `tools/capture/capture_serpent.gd`.

## Round 2 (motion critic FIX + director "Higher, more top-down", 2026-10-24)
- Camera: `scenes/serpent_camera.gd` (SerpentCamera): 46 m up, 24 m back (62 deg down), fixed yaw/pitch,
  Damped follow of the centreline's middle (0.6 s), opens at its steady lag (no first-frame lurch).
- Girth 1.5x (head 3.6, tail 0.6). Turn: jerk-limited (slow-in/out), turn_rate 1.25. Stop: last 2.5 m/s eased.
- S kept while slowing (weave amplitude never eases down while moving), lookahead 8 m.
- `scenes/serpent_settle.gd`: 0.45 s settle after the head stops (curves relax toward the tail, tail draws
  up, head still); the drawn trail is re-laid from the settled shape when it sets off (SerpentTrail.relay).
- Head leads: neck_bend shares [1, .75, .45, .2] over the front 4 segments + head_lift 0.8 m/rad.
- Clip timeline: turn at 0.8 s, U-turn 2.4 s, let go 4.6 s, head stops 5.33 s, shot settled by 7 s.

## Measured (round 2; suite prints them)
- Slip 0.55% (bar 2%; bad 99%). Wave 0.010% off (bar 1%; bad 20%). Corner-cut 0.0003/0.0002 m (bar 0.12).
- 90 deg turn 1.567 s (bar 1.5 +/- 0.1). Tightest turn 5.60 m = 1.6 widths; drawn bend 8.35 m = 2.3 widths.
- Stop: 0.72 s after let-go; travel 0 after stop; settle peaks 0.031 m/frame; 0 m/frame after it.
- Camera: never turns (0.000000); in the clip worst jolt 13.6 m/s^3 at 4.87 s, 0.046 m/s at 7 s, 62 deg.
- Clip: swath 12.2 m; closest strands 2.53 m; S depth by quarter head->tail 2.1, 0.6, 1.7, 1.3 m (the 2nd
  quarter, laid in the U-turn, is flattened by the bend limit).

## Evidence
- Suites: `serpent` 8 of 8 functions, 18 checks, 0 failures; `smoke` 13 of 13, 47 checks (local). Lints clean.
- Clip (local RTX 4070 SUPER, NVIDIA in log, off-screen no_focus override.cfg, removed after): lead scratchpad
  `serpent_clip/serpent_slither.mp4` (7.0 s, 1920x1080, 60 fps).

## What looked wrong / open
- Passes through trees, lamps, cars, people (no crushing this step); cleared patch is a big empty plaza.
- Stand-in box joints show steps; haze washes the green; head box colour barely distinct.
- The U-turn quarter reads as a plain arc (bend limit 1.5 widths flattens the S there).
- The drawn S is not the sim footprint (crushing later must use the drawn body or move the weave to the sim).
- Native carve DLL absent in this worktree (harmless; GDExtension load error in logs).

## Next (lead decides)
Director's look at the clip; then (research order) voxel skin + BOUNDS check, helix climb, constrict, tail grab;
sidewinding dash.
