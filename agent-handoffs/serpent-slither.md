# Handoff: serpent slither prototype (builder)

Serves D-197 (the serpent: "an actual serpent ... it needs to slither"), D-198 (sweep "Wide, ~6 m each side",
90 deg turn "About 1.5 s", sidewinding "Yes, as its dash" NOT built, prototype "Yes, now"), D-200 ("head aims, body
follows"), D-201 ("animations lead"), D-206 (starts a spitting cobra, later a rattle and a thicker constrictor body),
D-208 (turning/steering exceptional; body contact damages; held button climbs, NOT built), D-210 (defensive coil
idle, tongue flicking). First step only: slither, turn, stop. No PR, no merge: prototype for the director via the lead.

## State (2026-10-24, round 5)
- Pushed to `claude/serpent-slither` (local branch `serpent-r5`, worktree `agent-a267b04515be1a3be`). No PR. Croc game
  untouched. Play: `godot --path . res://scenes/serpent_proto.tscn` (WASD/stick).
- Clip: lead scratchpad `serpent_clip/serpent_slither.mp4` (10 s, 1920x1080, 60 fps, RTX 4070 SUPER in the log); round
  4's kept as `serpent_slither_r4.mp4`. Size stills beside it: `serpent_size_A.png` (today), `_B.png` (body 1.5x,
  head 2x, hood spread), `_C.png` (camera 25% closer; a 15 deg lower pitch read worse: the snake got smaller).
- Size stays the director's call: defaults unchanged (girth_scale 1, head_scale 1, run_hood 0).

## Why round 4 failed (critic FIX) and what changed
- Turn, a 25 m straight leg: the weave measured its side offset and lag in the sim head's CURRENT heading frame, so
  mid-turn the frame rotated under the drawn head, the pull (tanh, 0.5 rad) saturated and flattened the S. Round 5
  (`scenes/serpent_weave.gd`): the serpenoid's offset is laid in the sim centreline's own frame (point + normal x
  offset at each centreline arc position), so the S swings about the curve itself; a crest on a turn's inner side
  gives way by wave_inner_give x bend x offset; the drawn head steers for the S 1.5 m ahead by pure pursuit with the
  bend eased under min_bend_widths (1.5 widths); it is held 3 m behind the sim head (never nearer 1 m) so a turn the
  head is making never moves a point already laid. `SerpentTrail.course_at` added.
- Wind-up: windup_lead 0.22 -> 0.5 rad, windup_lift 0.9 -> 2.2 m, windup_s 0.3 -> 0.4 (test reads 0.43 rad, 2.47 m).
- Stop: as it brakes (stick let go) the front rears stop_rear 2.6 m over stop_rear_reach 8 m, the head draws back
  stop_recoil 1.2 m, the hood half spreads (`SerpentStandIn._brace`).
- Coil (`serpent_coil.gd`, `serpent_settle.gd`): one precomputed path, the body follows it head first (follow-the-
  leader on a 3D track: the stopped shape, then the coil path). Outer ring first (radius 4.8, tangent to the head's
  way), spiral in 2.0 m a turn to 1.6 m, each turn 1.0 m above the one outside it; the neck rises in a helix inside
  the last ring and arches (2.4 m) into the head at 7.7 m, tipped 0.25 rad nose-down toward the camera; the cobra
  hood (2.6x wide, 45% thinner) spreads as it rises. Ring placement tries 5 straight run-ins x 2 sides and takes the
  one clear of the still-lying body and inside the S's footprint; the head turns in up to 0.8 rad if its snout would
  leave the footprint. Tube rings are now framed in 3D (a vertical neck stays round).
- Idle: breath 3% of girth and 3% of ring radius every 2.6 s; head sway 0.26 rad (15 deg) over 5 s; tongue bursts
  every 1.0-1.5 s, tongue 3.0 m long (was 1.3), 0.22 m thick (was 0.09), fork 0.4 rad; eyes and tongue cast no shadow.
- Camera (`serpent_camera.gd`): the lead's heading is eased over camera_sway_s 0.4 s of travel (by distance, so it
  holds still after a stop). Sideways camera accel peak 13.6 m/s^2 vs 20.3 with round 4's follow (-33%).
- Size tunables (data/tuning.json "serpent"): girth_scale, head_scale (tube, eyes, tongue), run_hood; the capture takes
  --girth_scale --head_scale --run_hood --cam_zoom --cam_pitch --still --label --out for labelled stills.
- Tests: new `tests/lib/serpent_read_checks.gd` (the clip's route: straight runs, lobe swing about the centreline,
  tube self-intersection every frame of the stop and coil, each with a known-bad). Stop checks: chain spacing now
  measured in 3D; the "head above the pile" check uses the head's highest joint (it tips nose-down).
- `tools/capture/serpent_probe.gd`: the clip route (or --route=stop, the suite's stop) headless, joints/lifts/widths
  every N frames as JSON, plus the camera sway readout. Scratch analysis scripts live in the lead scratchpad `r5/`.

## Measured (round 5)
- Turns (suite, every 0.1 s of the clip route): longest straight run 8.0 m (heading inside a 10 deg band; bar 8; the
  cruise itself is 6-7 m), weakest whole lobe 75% of the ruled 5.6 m swing (bar 60%); tightest drawn bend 2.81 m
  (1.6 widths). Slip 0.001%, wave 0.06% off, corner-cut 0.0025 m, 90 deg turn 1.567 s, stop 1.02 s after let-go.
- Coil: 0 self-intersecting frames, closest pass 1.02 of touching (known-bad half-girth spiral 0.50); 7.8 m off the S's
  centreline (bar 8.1); head 7.0-7.7 m up; chain whole in 3D. Camera still 0.42 s after the stop.
- Idle (clip frames, 7.8-9.9 s): 1.46% of the frame, 3.4% of a crop round the coil, changes per 0.1 s.
- Suites: `serpent` 6 of 6 functions, 43 checks, 0 failures; `smoke` 13 of 13, 47 checks. gdlint/gdformat clean
  (gdtoolkit 4.5), tuning_keys and complexity_ratchet ok.

## Reference (sources; targets in `tests/lib/serpent_stop_checks.gd` `_proportions`)
- Hu, Nirody, Scott, Shelley, PNAS 2009, PMC2700932: milk snakes L 30 cm, dimensionless wavelength 0.4 +/- 0.1,
  amplitude 0.1 +/- 0.03, 0.5 Hz, steady 0.11 body lengths/s, burst 0.2. Jayne 2020, PMC7391877: every body point
  follows one path, wave speed equals forward speed. Real snakes 25-40 girths (cobras 35-40; memory, not opened).

## Body contact (D-208) for later, not built
`VoxelFrame.carve_capsule(a, b, radius, force)`: one capsule per drawn joint pair (60), radius 0.5 x `width_at(d)`,
centre y = lift + height/2. The drawn S swings +-6 m about the sim centreline, so the weave must move into the sim
before crushing. Swath ~15 m wide x 35 m long moving; the coil is a ~11 m disc beside the head, 3.8 m high pile.

## What looked wrong / open (not judged passing; the lead's critic judges the read)
- Speckled shadows: the reared head (5.3-6.0 s) and the raised head over the coil cast dithered shadows (the medium
  preset's soft_low filter with sun_angular 1.0 on a caster 3-7 m up). Eyes and tongue no longer cast; the head and
  neck still do. A fix is a game-wide shadow setting or a blob shadow: a call for the lead.
- The raised head and hood are pale and large from the camera; the hood has no markings. Rearing at the stop is hard to
  read at 62 deg pitch (vertical motion foreshortens). The wind-up read is unverified at game camera.
- The drawn head moves 12.6-23 m/s along the S (the body slides a little slower round an inner crest, faster round an
  outer one, plus the catch-up); round 4 printed 8.6-9.8 by a different measure. Watch for surging bands.
- The capture's camera jolt readout rose to 112 m/s^3 at the let-go (4.87 s; round 4: 30). Not seen in frames; check.
- A ~5 m tail stub trails out of the coil (the coil path is shorter than the body). Passes through trees and cars.
- No sidewinding dash, no climb, no rattle or constrictor body yet.
