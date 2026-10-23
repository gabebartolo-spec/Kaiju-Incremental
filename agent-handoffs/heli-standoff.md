# heli-standoff (builder "beam-cost" session, branch claude/heli-standoff, worktree Kaiju-Incremental-wt/volley-d178)
Task (lead brief, D-183 "Stand-off gunships", director 2026-10-23: "helicopters are hovering way too close to our kaiju ...
twitchy like an orbiting fly, they should move logically, strategically, gracefully"): helicopters hold firing positions
well beyond his reach, glide between them under their own speed/turn limits (never pinned to him), pull back when he
advances; the breath, beam or a thrown tank reaches them; an occasional strafing pass (one at a time) brings one within claw
reach; they keep off the camera's side (camera_bearing, clear_arc). Serves ROADMAP "Interview answers" / D-183 / D-177.
Prove: seeded check at every growth step: min distance outside a pass >= the ring (I use: beyond the claw band), no jump above
max speed x dt, no turn above the limit, each shown failing on the base first; touched suites only; review packet below.

## State (not pushed; WIP commit e004d85b is the first design, later work uncommitted)
- sim/air_flight.gd (new, class AirFlight): per-heli pos / vel (acceleration-limited) / nose heading (turn-limited) / ring /
  slot (bearing) / goal. Goal = a slot on the heli's ring round the kaiju, `lead_seconds` of the kaiju's smoothed walk ahead;
  the velocity moves toward (braking velocity toward the goal + the goal's own walk) by at most heli_accel, capped heli_speed.
  Slot glides along the ring after hold_seconds; within pull_back of the kaiju the slot goes straight behind the heli.
  Strafing pass: clock strafe_gap, one heli at a time, in to strafe_close x scale ahead of the kaiju then out to a side slot.
- sim/air_wing.gd: orbit code removed (angle/turn/radius/cruise/orbit_pos/_keep_clear); Heli has pos/heading/vel/ring/slot/goal/
  hold/passing/pass_out/pass_left; spawn() calls flight.place; step() calls flight.step. Deaths/wreck/swat unchanged.
- data/tuning.json "air": orbit_* / dive / clear_margin removed; standoff 24, standoff_jitter 0.1, spawn_far 1.8, pull_back 20,
  heli_speed 14, heli_accel 8, heli_turn_deg 180, nose_share 0.3, watch_seconds 1, lead_seconds 1.5, arrive 2, hold_seconds,
  glide_deg, slot_tries, strafe_*, clear_arc 60, clear_lead_deg 10 (_note_flight explains each).
- tests/run_heliflight_tests.gd (new suite HeliFlight): per growth step (young/Behemoth/Colossus) 3 helis, 120 s, scripted
  kaiju walking to the nearest building; checks: closest outside a pass > claw band corner, top speed, turn per step (direction
  of motion between steps at >= nose_share x top speed), >= clear_arc off the camera side, passes happen one at a time and reach
  the claw band; plus a replay check. tests/run_tentacles_tests.gd adapted (force a pass via sim.air.flight.start_pass).
- tools/capture/capture_heli_deaths.gd line 132: heli.angle -> heli.heading (cleared by the VFX lead).

## Findings (reach numbers, reptilian, via scratchpad/beamcost/heli_probe.gd)
bs (body scale) 0.50 / 0.92 / 1.35 at the three steps with no upgrades (1.03 / 2.27 / 3.77 with every node); claw band reaches
hypot(13 bs, swipe_width x bs) <= 13.8 bs; breath reaches >= 25 bs from the origin; kaiju speed 3.3-8.3 u/s and it LURCHES
(position steps of up to 1.7 u in a step while it smashes), so a heli that must swing its nose round before backing off loses
10-17 units to a walking kaiju; angular error of a following heli = lag / ring, up to 25-40 deg at the young step.
heliflight history (all on the same seeds): v1 orbit-like spots fixed in the world: 9 failures (helis left behind land on the
camera side); v2 slots that follow + forward-only flight: 4 failures (camera side 49 / 34 / 40 deg, Colossus claw 13.6 vs 17.7);
v3 + lead_seconds: 5 failures (camera 49/34/40, claw 7.8, 13.6); v4 velocity model: 5 failures (camera 0 / 8 / 32; Behemoth closest
2.2): tracing (scratchpad/beamcost/heli_trace.gd, heli_trace.sh --step=N).

## Next
Read heli_trace_0/1.txt, fix what puts a heli at 2.2 u / 0 deg (a pass leg? the pass goal ahead of the kaiju?), widen
clear_lead_deg if lag alone explains the camera bearing, rerun heliflight; then red run (base air_wing.gd + the new data + a
shim `passing` field) for the failing-first evidence; then tentacles, helideaths, military, sim; lint (gdlint, gdformat, tuning_keys,
complexity_ratchet, check_scripts); review packet here; push claude/heli-standoff:claude/heli-standoff; report the sha to main.
If the young step cannot hold 60 deg off the camera side naturally, report the trade (wider clear_lead_deg shrinks the allowed
sector from 240 deg), do not loosen the bar.

## Review packet (to fill when the design is final; kaiju-sim-review)
Transitions: tick (AirWing.step -> flight.step before the fire loop), injury (heli damage unchanged), removal (clear_dead
unchanged), save/reload (none: AirWing rebuilt per rampage), generation (heli spawn draws from the flight's own stream
Seeds.derive(rng, 0xF17); the old spawn used 2 draws of the AirWing stream), identity (heli.id unchanged).
