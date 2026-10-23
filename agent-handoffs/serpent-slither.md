# Handoff: serpent slither prototype (builder)

Serves D-197 (the serpent: "an actual serpent ... it needs to slither"), D-198 (sweep "Wide, ~6 m each side",
90 deg turn "About 1.5 s", sidewinding "Yes, as its dash" NOT built, prototype "Yes, now"), D-200 ("head aims, body
follows"), D-201 ("animations lead"), D-206 (starts a spitting cobra, later a rattle and a thicker constrictor body),
D-208 (turning/steering exceptional; body contact damages; held button climbs, NOT built), D-210 (defensive coil
idle, tongue flicking). First step only: slither, turn, stop. No PR, no merge: prototype for the director via the lead.

## State (2026-10-24, round 6)
- Pushed to `claude/serpent-slither` (local branch `serpent-r6`, worktree `agent-a2e3137d7a069a721`). No PR. Croc game
  untouched. Play: `godot --path . res://scenes/serpent_proto.tscn` (WASD/stick).
- Clip: lead scratchpad `serpent_clip/serpent_slither.mp4` (round 6, 10.6 s; RTX 4070 SUPER in the log); round 5's kept
  as `serpent_slither_r5.mp4`, round 4's as `_r4.mp4`. Round 6 work files (probe, metrics, stills): `serpent_clip/r6/`.
- Round 5 critic (FIX): reads as a snake, run good, not yet an exceptional predator. Lead ruling for round 6: motion and
  camera only; do NOT polish the stand-in tube's head, hood or colour (the real model comes from Tripo). Haze: lead's.

## Round 6 changes (motion and camera)
- Turn legs: the S's heading is a serpenoid plus `wave_arc` of its odd harmonics (toward a triangle heading: a chain of
  arcs), `SerpentWeave.shape`; a pure serpenoid runs nearly straight across each axis crossing. Straight-run test now
  counts the whole body (tail included).
- Stop cue (`SerpentStandIn._bunch_up/_bunched`): braking under stop_bunch_speed 1.8 m/s (~5.4 s on the clip) starts a
  stop_bunch_s 0.3 s bunch-up, tail first, head last (each joint's swing deepens by stop_bunch 0.5, chain drawn up
  behind the head); the hood flares full with it, folding at stop_rear_rate once stopped. The coil starts from it.
- Idle: head sway idle_track 0.21 rad over idle_track_s 2.0 (mostly one sine); breath idle_breath 0.05, ring 0.04,
  every 2.0 s; tongue wags tongue_wag 0.22 rad (12.6 deg) side to side once per flick, alternate flicks reversed.
- Camera (`SerpentCamera.follow(body, delta, joints)`, `keep_in`): in a turn the aim shifts just enough to keep the
  whole drawn body camera_keep_in 12% inside the frame (girth padded), eased over camera_shift_s 0.5 and faded with
  the turn over camera_turn_s 1.5, both by travel (they hold once it stops).
- Coil (`serpent_settle.gd`): coil_pitch 1.6 (was 2.0) so the coil path holds the whole body (no tail stub);
  coil_rise 1.3 (was 1.0) keeps the closer rings apart in 3D; coil_s 2.4 (was 2.0) slows the slide; the stretch still
  lying where it stopped is pulled taut (stop_taut: fully by the coil's end, smoothed 6 passes x 6 joints, none within
  8 m of the head's stop) so the thin tail is not swung round the old S's bends; the stop's rear and raised front come
  down over the first 35% of the coil (SETTLE_DOWN) so they never pass beside the forming rings at their height.
- Shadows: `SerpentProto._bias_sun` sets the prototype sun's shadow bias / normal bias from sun_shadow_bias /
  sun_normal_bias (Godot defaults 0.1 / 2.0 kept). See "Shadow speckle" below: bias does not fix it.
- Capture: `--shadow_bias --normal_bias --sun_angular --sun_blur` trials; probe: camera per frame, `--set=key:v`.

## Measured (round 6)
- FILL IN after the final clip.

## Shadow speckle (for the lead)
- FILL IN.

## Tripo baby on this body (feasibility only, no build)
- FILL IN.

## Reference (sources; targets in `tests/lib/serpent_stop_checks.gd` `_proportions`)
- Hu, Nirody, Scott, Shelley, PNAS 2009, PMC2700932: milk snakes L 30 cm, dimensionless wavelength 0.4 +/- 0.1,
  amplitude 0.1 +/- 0.03, 0.5 Hz, steady 0.11 body lengths/s, burst 0.2. Jayne 2020, PMC7391877: every body point
  follows one path, wave speed equals forward speed. Real snakes 25-40 girths (cobras 35-40; memory, not opened).

## Body contact (D-208) for later, not built
`VoxelFrame.carve_capsule(a, b, radius, force)`: one capsule per drawn joint pair (60), radius 0.5 x `width_at(d)`,
centre y = lift + height/2. The drawn S swings +-6 m about the sim centreline, so the weave must move into the sim
before crushing. Swath ~15 m wide x 35 m long moving; the coil is a ~11 m disc beside the head, ~4 m high pile.

## Open (not judged passing; the lead's critic judges the read)
- The raised head and hood are pale and large from the camera (look work parked for the Tripo model).
- The coil slide is still quick (about 25 m/s mid-slide for a 10 m/s snake); a slower coil pushes the idle later.
- No sidewinding dash, no climb, no rattle or constrictor body yet.
