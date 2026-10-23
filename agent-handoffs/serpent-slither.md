# Handoff: serpent slither prototype (builder)

Serves D-197 (the serpent: "an actual serpent ... it needs to slither"), D-198 (sweep "Wide, ~6 m each side",
90 deg turn "About 1.5 s", sidewinding "Yes, as its dash" NOT built, prototype "Yes, now"), D-200 ("head aims, body
follows"), D-201 ("animations lead"), D-206 (starts a spitting cobra, later a rattle and a thicker constrictor body),
D-208 (turning/steering exceptional; body contact damages; held button climbs, NOT built), D-210 (defensive coil
idle, tongue flicking). First step only: slither, turn, stop. No PR, no merge: prototype for the director via the lead.

## State (2026-10-24, round 8)
- Pushed to `claude/serpent-slither` (local branch `serpent-r7`, worktree `agent-aca27d68ea73cc1d6`). No PR. Croc game
  untouched. Play: `godot --path . res://scenes/serpent_proto.tscn` (WASD/stick).
- Clip: lead scratchpad `serpent_clip/serpent_slither.mp4` (round 8, 10.6 s; RTX 4070 SUPER in the log); earlier rounds
  kept as `serpent_slither_r7.mp4`, `_r6`, `_r5`, `_r4`. Round 7/8 scripts, stills, probes, frames: `serpent_clip/r7/`.
- Round 7 critic: FIX on one item only (all else passes): 7.40-7.65 s the tail's end stood up off the coil as "a thin
  leaf-shaped blade". Round 8: the tuck (`SerpentSettle._tuck`): as the stopped stretch goes taut, its last 6 m
  before the head's stop hook round onto the top of the outer ring (0.5 m inside its outer radius, on the ground
  under the raised turn), then steer back onto the taut stretch (no blend, so no fold); the tail's end is drawn in
  along the ring, not sticking out. Tail cap blunter: `shape` 59.7 m 0.34 (a third of the girth to 99.5%).
  Side effect: the 6.8-7.3 s reel-in now curves round the ring's east side (r8 vs r7 at 6.8/7.0/7.2 compared).
- Round 6 critic (FIX): run, turn, framing, camera, coil, idle sway, breathing, tongue PASS (untouched); fix the tail,
  the stop cue and the shadow's stair-stepped edge. Round 7 did only those three (below). Lead ruling still stands:
  no look polish on the stand-in's head, hood or colour (the real model comes from Tripo).

## Round 7 changes (the critic's three fixes)
- Tail (shape table only, no motion change): `shape` 46 m 0.7, 54 m 0.46, 58 m 0.36, 60 m 0.06, so it keeps over a
  third of the girth to the last 3% (was 0.24 at 54 m, a needle). Coil: the outer turn (the tail's) starts
  coil_tail_pitch 1.2 m (not coil_pitch 1.6) from the turn inside it, easing to 1.6 over the turn
  (`SerpentCoil.ring_radius`), so the tail lies tucked against the coil, not a thin ring a gap apart.
- Stop cue: the bunch-up also lays the joints closer along the bunched S (`_bunched`, stop_shorten 0.1: the body
  60 -> 52.8 m drawn, its bands closing up toward the head, 5.4-5.7 s) and the hood flares stop_flare 1.5 of full
  (2.55 -> 3.28 m wide at 5.7 s, +29%; hood thinning capped at full). Footprint solved by timing: the coil is laid
  from the shortened body, and `SerpentSettle._lengthened` lets the body grow back as the head leads it in (tail
  held still until the head has gone the 6 m shortfall, ~0.5 s): whole again by 6.2 s, the coil itself unchanged.
- Shadow: `SerpentProto._sharpen_sun` sets the sun's shadow reach sun_shadow_distance 90 m (preset 160) and the
  shadow atlas sun_shadow_atlas 8192 px (preset 4096); blur stays 0.5. Re-applied whenever the graphics preset
  (Settings, on its first frame) has overwritten them. Found: capture shadow trials applied before Settings' first
  frame were silently undone (round 6's bias trials survived only because bias is not a preset key).
- Tests: the read checks add "braking, the body bunches up at least 8% shorter", "whole again half way into the
  coil" and "the tail keeps a third of the girth to 96% of its length".

## Round 6 changes (motion and camera; still in place)
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
- Capture: `--shadow_bias --normal_bias --sun_blur --sun_distance --sun_atlas --sun_filter --sun_off` trials (applied
  on frame 3, after the preset); probe: camera per frame, `--set=key:v`.

## Measured (round 7 clip; scripts in `serpent_clip/r7/`: probe.sh, tailgap.py, stair.py, hoodw.py, side.py)
- Suites: serpent 6/6 functions, 51 checks, 0 failures (coil footprint 7.8 m, bar 8.1; closest pass 1.08, r6 1.02;
  tail joints 1.9 m from a ring, bar 2.6); smoke 13/13, 47 checks. gdlint/gdformat clean, tuning_keys and
  complexity_ratchet ok.
- Tail: coiled, its outer ring lies against the next one (3D gap at the tip 0.76 m incl. the 1.2 m ring rise, r6
  1.29-2.03 m; planar ~0). Still trailing out of the coil while it is reeled in (6.8-7.5 s), now thick.
- Shadow edge right of the raised head (stair.py, 8.8 s still, same window): edge RMS off a smooth curve 0.74 px ->
  0.32 px (still) / 0.26 px (clip), biggest row jump 2.47 -> 1.28 px. Speckle (r6 speckle.py) 0.6% -> 0.7% (still).
  Single trials: 90 m alone 0.40, 8192 alone 0.35, soft_high filter alone 0.73 (no help), 80 m 0.67, split 0.05 worse.
- Unchanged items checked: critic cam.py camera shift within 0.33 px/frame of r6; edge.py frame-edge counts match;
  hd6 idle head-axis std 4.6 deg (r6 5.4 on the same window); capture: head stops 5.73 s, camera still 0.45 s.

## Shadows (for the lead: main-game settings)
- Speckle (round 6): the soft filter's scattered samples spread by shadow_blur 1.5 (`scenes/city_environment.gd`);
  blur 0.5 clears it (bias and normal bias do not). Stair steps (round 7): shadow-map resolution at this distance;
  reach 90 m plus an 8192 atlas clears them. For the main game: shadow_blur 1.5 -> 0.5, and the preset rows'
  shadow_distance / shadow_size (medium and high: 160 m, 4096) toward 90 m / 8192, if the croc's camera allows.

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
