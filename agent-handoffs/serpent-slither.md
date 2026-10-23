# Handoff: serpent slither prototype (builder)

Serves D-197 (the serpent: "an actual serpent ... it needs to slither"), D-198 (sweep "Wide, ~6 m each side",
90 deg turn "About 1.5 s", sidewinding "Yes, as its dash" NOT built, prototype "Yes, now"), D-200 ("head aims, body
follows"), D-201 ("animations lead"), D-206 (starts a spitting cobra, later a rattle and a thicker constrictor body),
D-208 (turning/steering exceptional; body contact damages; held button climbs, NOT built), D-210 (defensive coil
idle, tongue flicking). First step only: slither, turn, stop. No PR, no merge: prototype for the director via the lead.

## State (2026-10-24, round 4)
- Pushed to `claude/serpent-slither` (local branch `serpent-r4`; the old worktree `agent-ae5ae30e1d30f454a` holds the
  branch name). No PR. Croc game untouched. Play: `godot --path . res://scenes/serpent_proto.tscn` (WASD/stick).
- Why rounds 1-3 failed (D-188, method changed): every kinematic bar passed but the critic read "a smooth plausible
  rope on a rail, not a snake". Round 4 method: (1) reference-led targets, (2) a stand-in that reads as a snake,
  (3) bars in screen terms.

## Reference (sources; targets in `tests/lib/serpent_stop_checks.gd` `_proportions`)
- Hu, Nirody, Scott, Shelley, PNAS 2009 "The mechanics of slithering locomotion", PMC2700932 (opened): milk snakes
  L 30 cm, dimensionless wavelength 0.4 +/- 0.1 (2.5 waves), amplitude A 0.1 +/- 0.03, period 2 s (0.5 Hz), steady
  0.22 L per period = 0.11 body lengths/s, burst 0.4 (0.2 BL/s). NB the round-1 research note read 0.22 as per second.
- Jayne 2020 Integr Comp Biol, PMC7391877: terrestrial lateral undulation, every body point follows one path, wave
  speed equals forward speed. PMC11181092 ("Geometric phase predicts locomotion performance in undulating living
  systems across scales", opened): body shapes fit as sin(2 pi n s / L), n waves along the body; its snake example
  uses n = 1.5 (sidewinding), lizards and nematodes more.
- Length/girth (memory, not opened): cobras 35-40, boas 25, lab snakes ~30. Real snakes 25-40 girths.
- Not found: a frame-by-frame video measure of curvature along the body; the head-sway and "tighter neck" cues are
  from the critic sheets and the serpenoid, not a cited measurement.

## Before / after (round 3 -> 4)
- Length 40 -> 60 m; max girth 3.6 -> 1.8 m (L/girth 11 -> 33); waves along the body 0.9 -> 1.75 (path wavelength 44 ->
  34.3 m); swing +-6 kept (wave_amp 5.6 mean, crests differ x1.28, so up to ~6.4; clip measures +7.2/-6.3 with the tail
  whip); footprint ~35 m long (was ~31) x ~15 m wide (was ~17); speed 7 -> 10 m/s forward = 0.17 BL/s (was 0.18; the
  longer body is faster in metres), wave 0.46 Hz (was 0.3), tightest drawn bend 3.0 m = 1.7 girths.
- NB the lead's first plan (52 m, 2 waves, +-6) is geometrically impossible (needs a 179 deg head swing); 60 m / 1.75
  solved by integrating the serpenoid (heading swing 78 deg, forward progress 0.59 per metre of body).

## What was built (round 4)
- `scenes/serpent_tube.gd` (SerpentTube): one smooth tube over a Catmull-Rom of the joints (ring every 0.35 m), width
  by the `shape` table (rounded snout, head 1.44 m, neck 0.94, body 1.8, long thin tail, tip 0.11), cobra-ish head,
  two eyes, dark bands that ride the body, forked red tongue. Replaces the 48 boxes (plain colour).
- `scenes/serpent_weave.gd`: wave number and size wobble by distance travelled (no two crests alike), 60 m body.
- `scenes/serpent_stand_in.gd`: tail whip (wider than the S, from 60% of the body), wind-up before a turn (head cocks
  away 0.22 rad and rears 0.9 m for 0.3 s, then looks into it), neck bend, jab and look from the idle.
- `scenes/serpent_coil.gd` + `serpent_settle.gd` (D-210): on a stop the body draws into a defensive coil over 1.6 s
  (head end first), 3.3 loops of radius 2.9 stacked 1.5 m apiece (pile 4.9 m), head and an S neck rising 2.2 m above it;
  then the idle: breathing, head looks about +-0.35 rad, bursts of 2-3 tongue flicks every 2-4 s with a 0.7 m jab.
  Deterministic (fixed hash, no clock). The coil forms beside and behind the stopped head, on the side the body lay.
- `sim/serpent_body.gd`: speed push builds at pace_jerk 60 m/s^3 (let-go no longer jolts the camera).
- `scenes/serpent_camera.gd`: pre-ease removed, follow 0.22 s; still within 0.42 s of the head stopping.
- `tests/run_serpent_tests.gd` (core: trail, turn, slip, wave, corner) and `tests/lib/serpent_stop_checks.gd`
  (proportions with a known-bad body, U-turn counter-curve, wind-up, coil footprint, idle, camera in screen terms with a
  slow-camera known-bad). `tools/capture/capture_serpent.gd`: 9.4 s clip, idle and camera-settle readouts.

## Measured (round 4)
- Slip 0.001% (bar 2%), wave 0.09% off (bar 1%), corner-cut 0.006 m, 90 deg turn 1.567 s, stop 1.02 s after let-go.
- 33 girths, 1.75 waves, wave 0.46 Hz, crests differ x1.28, U-turn keeps 4 inflections (S not a horseshoe).
- Coil: reaches 9.1 m from the head, 5.4 m off the S's centreline (bar swing + girth = 8.1), 7.7 m high at the head.
- Idle at 1080p: head tip wanders up to 14 px, body 32 px wide (0.44 widths; critic bar 0.3-0.5 widths); tongue out
  to 1.0, jab 0.7 m. Camera: head 42% down going north, 55% across going east, still 0.42 s after the stop.
- Clip (local RTX 4070 SUPER, NVIDIA in log): lead scratchpad `serpent_clip/serpent_slither.mp4`, 9.4 s, 1920x1080, 60 fps.
- Suites: `serpent` 6 of 6 functions, 38 checks, 0 failures; `smoke` 13 of 13, 47 checks. gdlint/gdformat clean
  (gdtoolkit 4.5 in a scratch dir), tuning_keys and complexity_ratchet ok.

## Body contact (D-208) for later, not built
`VoxelFrame.carve_capsule(a, b, radius, force)` sweeps a sphere a-b: one capsule per drawn joint pair (60 of them,
`SerpentStandIn.joints`, 1 m long), radius 0.5 x `width_at(d)` (0.9 m at the body, 0.05 at the tail), centre y = lift +
height/2, force from the serpent's weight. The sim only knows the centreline (`SerpentBody.centre_at`), but the drawn S
swings +-7 m about it, so the weave must move into the sim before crushing (the open item from round 1). Swath: ~15 m
wide x 35 m long moving; the coil is a 7.6 m disc (radius 3.8) 5 m high beside the head. Cost: 60 capsules a frame.

## What looked wrong / open
- The snake is small in the 1080p frame (15 px/m at the camera): a 60 m body at 1.8 m girth. A lower camera or
  thicker girth (2.2 m = 27 girths) is a call for the lead. Camera stays 46 up / 24 back (round 3's).
- The S flattens through the tightest part of a U-turn (bend limit leaves little budget), the tail whips thinly.
- Passes through trees, lamps, cars, people (no crushing). Haze washes the green. Eyes are plain yellow balls.
- No sidewinding dash, no climb, no rattle or constrictor body yet.
