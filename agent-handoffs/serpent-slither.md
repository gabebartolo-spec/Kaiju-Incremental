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
- Turn legs: the S's heading is a serpenoid plus `wave_arc` 1.0 of its odd harmonics (toward a triangle heading: a
  chain of arcs), `SerpentWeave.shape`; a pure serpenoid runs nearly straight across each axis crossing. Arcs sit near
  the bend limit, so crests went alike: wave_wobble_len 0.12 -> 0.16 keeps them varied. Straight-run test now counts the
  whole body (tail included).
- Stop cue (`SerpentStandIn._bunch_up/_bunched`): braking under stop_bunch_speed 1.8 m/s (~5.4 s on the clip) starts a
  stop_bunch_s 0.3 s bunch-up, tail first, head last (each joint's swing deepens by stop_bunch 0.5, chain drawn up
  behind the head); the hood flares full with it, folding at stop_rear_rate once stopped. The coil starts from it.
- Idle: head sway idle_track 0.25 rad over idle_track_s 2.0 (mostly one sine); breath idle_breath 0.05, ring 0.04,
  every 2.0 s; tongue wags tongue_wag 0.22 rad (12.6 deg) side to side once per flick, alternate flicks reversed.
- Camera (`SerpentCamera.follow(body, delta, joints)`, `keep_in`): in a turn the aim shifts just enough to keep the
  whole drawn body camera_keep_in 12% inside the frame (girth padded), eased over camera_shift_s 0.5 and faded with
  the turn over camera_turn_s 1.5, both by travel (they hold once it stops).
- Coil (`serpent_settle.gd`, `serpent_coil.gd`): coil_pitch 1.6 (was 2.0) so the coil path holds the whole body (no tail stub);
  coil_rise 1.3 (was 1.0) keeps the closer rings apart in 3D; coil_s 2.4 (was 2.0) slows the slide; the stretch still
  lying where it stopped is pulled taut (stop_taut: fully by the coil's end, smoothed 6 passes x 6 joints, none within
  8 m of the head's stop) so the thin tail is not swung round the old S's bends; the stop's rear and raised front come
  down over the first 35% of the coil (SETTLE_DOWN) so they never pass beside the forming rings at their height; the
  neck's arch arrives level and the head then tips nose-down, so no neck crest stands above the head.
- Shadows: `SerpentProto._shade_sun` sets the prototype sun's shadow_blur to sun_shadow_blur 0.5 (see below).
- Capture: `--shadow_bias --normal_bias --sun_blur` trials; probe: camera per frame, `--set=key:v`.

## Measured (round 6; scripts in `serpent_clip/r6/`: an.py, an2.py, frame.py, tail.py, crit.py, speckle.py)
- Turn 3.2-4.6 s, whole body: longest run inside a 10 deg band 7 m (round 5 code 8), 20 deg band 8-9 m (r5 11), chord
  sagging under 0.3 m 9 m (r5 10); weakest lobe 80% of the swing. Suite (every 0.1 s, whole route) 8.0 m, bar 8.
- Framing 3.0-5.0 s: the tube's lowest edge 92.6% down the frame (r5 98-99%: off the bottom). Sideways camera accel
  peak 14.1 m/s^2 (r5 15.3). Camera still 0.45 s after the stop (bar 0.5); worst jolt 131 m/s^3 at the let-go.
- Stop: bunch-up 5.4-5.7 s, hood full at 5.7 s; head stops 5.73 s. Coil 2.4 s; idle from ~8.7 s.
- Tail: stub 0 m (r5-like settings 6 m); tail tip during the coil peaks 28 m/s and 234 m/s^2 sideways (r5-like 42 m/s,
  505 m/s^2; every 2 frames). Coil: 0 self-intersecting frames, closest pass 1.02 of touching.
- Idle (8.6-10.6 s, critic hd.py on frames shifted onto round 5's coil): head axis std 5.5 deg (r5 2.6; +-8 deg is
  5.7); tongue wags 12.6 deg (seen at 8.45-8.6 s); breath 5% girth, 4% rings every 2 s (the critic's 2% method unknown).
- Suites: serpent 6/6 functions, 48 checks, 0 failures; smoke 13/13, 47 checks. gdlint/gdformat clean, tuning_keys and
  complexity_ratchet ok.

## Shadow speckle (for the lead)
- Not acne: it is the soft shadow filter's scattered samples, spread by the sun's shadow_blur (1.5, set in
  `scenes/city_environment.gd`). speckle.py (light dots inside the raised head's shadow, 5.5 s still): blur 1.5 11.7%,
  blur 0.5 0.3%, blur 0 0.3%. Shadow bias 0.02-0.8 and normal bias 0.2-5 do not clear it (7-20%; bias 0 with normal
  0.5 adds acne on the body). light_angular_distance overridden after load did not change the frame (untested further).
- Fix in the prototype: sun_shadow_blur 0.5. For the main game: shadow_blur 1.5 -> 0.5 in city_environment.gd.

## Tripo baby on this body (feasibility only, no build)
- Yes. `cascadeur_bridge/serpent/models/baby/serpent_baby_tex.glb` (8b868b25 textured, 10,390 faces): one continuous
  tube, body lying in a flat S, neck reared ~90 deg, hood baked flared, tongue a thin strand from the mouth.
- Steps: Blender (CPU, no GPU lock): fit a centreline through ring centroids (top view S + the vertical neck), map each
  vertex to (arc length, frame offset) and lay it straight (an inverse curve-deform); six views before/after; a
  61-bone chain along the straight spine, weights by arc length to the two nearest bones; hood fold as a shape key or
  two hood bones; tongue cut (the procedural tongue stays). Godot: Skeleton3D posed each frame from
  `SerpentStandIn.joints` + `lifts` with the tube's own ring frames (`SerpentTube.build` already computes them).
- Risks: the hood is flared in the mesh (needs a fold rig); unbending the tight neck-to-ground bend stretches texture
  there; its length/girth ratio vs our 33 girths and tip width may force a non-uniform stretch; triangle density may
  crease in the 1.6-width bends and the coil; the voxel lattice skin (D-041/D-045) still has to be applied on top.

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
