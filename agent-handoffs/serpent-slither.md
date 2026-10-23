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

## Round 3 (critic round 2 FIX; method changed per D-188, 2026-10-24)
- S: `SerpentWeave` is now a serpenoid: the drawn head's heading swings alpha cos(2 pi s/44) about
  the sim course (alpha solved so the swing is wave_amp 6 m), a tanh-soft pull holds it to the swing,
  a tanh-soft bend limit (1.5 girths, 4% margin), constant path speed v/progress(alpha) (no surge),
  sub-stepped at the sample spacing. In a turn the S keeps only the bend the turn leaves.
- Stop: `SerpentSettle` = visible settle over 0.6 s (curves ease 20%, tail curls in 1 girth) then a
  living idle (0.35 m travelling sway at the tail, 6% breathing swell, faded in 0.6 s); no travel.
- Camera: `SerpentCamera.target` = head + heading x (speed x 0.4 s - 7.2 m), eased then Damped;
  head 36% down the frame on a long north leg (test), yaw fixed.
- Clip 8 s: preroll 14 s (S along the whole body), turn 0.8 s, U-turn 2.5 s (stick lean 1.5 s then
  due south), let go 5.4 s, stop 6.13 s, settle + idle to 8 s.
- Slip is now measured as the distance a joint leaves the drawn track it lay on a frame before
  (Geo.off_path_near), not a neighbour-joint tangent (that estimate could not resolve the path).

## Measured (round 3)
- Slip 0.002% (bar 2%; bad 99%). Wave 0.012% off (bar 1%; bad 39%). Corner-cut 0.0003/0.0004 m.
- 90 deg turn 1.567 s. Tightest turn 5.60 m, drawn bend 5.61 m (1.6 girths).
- Stop 0.72 s after let-go; travel 0; tail drawn in 3.55 m (0.99 girth); idle max 0.016 m/frame,
  0.35 m off the settled shape, drift 0.002 m. Camera: head 36% (test), never turns.
- Clip: swing +6.6/-6.6 m (ruled ~6), 16.7 m across with girth; U-turn 180 deg; closest strands 2.5 m;
  S depth by quarter 1.7/1.9/1.0/2.8 m; tail tip bends 73 deg over its last 4 segments; north leg in
  the clip (transient after the turn) 40-42% down; opening second drawn head 8.6-9.8 m/s, camera
  6.98-7.04 m/s (no dip); worst camera jolt 30 m/s^3 at let-go, 0.054 m/s at 8 s.

## Evidence
- Suites: `serpent` 8 of 8 functions, 20 checks, 0 failures; `smoke` 13 of 13, 47 checks. Lints clean.
- Clip (local RTX 4070 SUPER, NVIDIA in log, off-screen no_focus override.cfg, removed after): lead scratchpad
  `serpent_clip/serpent_slither.mp4` (8.0 s, 1920x1080, 60 fps).

## What looked wrong / open
- In the tightest turn (radius 5.6 m vs the 5.4 m bend limit at 3.6 m girth) the S has almost no bend
  budget left, so the turn quarter is mostly arc (depth 1.0 m vs 1.7-2.8 elsewhere).
- Passes through trees, lamps, cars, people (no crushing this step); cleared patch is a big empty plaza.
- Stand-in box joints show steps; haze washes the green.
- The drawn S is not the sim footprint (crushing later must use the drawn body or move the weave to the sim).

## Next (lead decides)
Director's look at the clip; then (research order) voxel skin + BOUNDS check, helix climb, constrict, tail grab;
sidewinding dash.
