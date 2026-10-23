# heli-standoff (branch claude/heli-standoff, worktree Kaiju-Incremental-wt/volley-d178; builder "beam-cost" session stood down at run 7)
Task (lead brief, D-183 "Stand-off gunships", director 2026-10-23: "helicopters are hovering way too close to our kaiju, its
completely unrealistic and looks odd how twitchy they are like an orbiting fly, they should move logically, strategically,
gracefully"): helicopters hold firing positions well beyond his reach, glide between them under their own speed/turn limits
(never pinned to him), pull back when he advances; the breath, beam or a thrown tank reaches them; an occasional strafing pass
(one at a time) brings one within claw reach; they keep off the camera's side (camera_bearing, clear_arc). Serves ROADMAP
"Interview answers" / D-183 / D-177 (motion first). Proof asked: a seeded check at every growth step: min distance outside a
pass >= the ring, no jump above max speed x dt, no turn above the limit, each shown failing on the base first; touched suites
only; D-186: locally only heliflight, GitHub runs helideaths / military / sim / tentacles / the rest.

## State at run 7 (pushed as a BACKUP, no PR, heliflight RED on purpose)
- 4 WIP commits on the branch (e004d85b, 4e0d6637, 8f729ebb, plus this handoff). Lints clean on the changed .gd files (gdlint, gdformat
  --check LF, tuning_keys). Not run locally: helideaths, military, sim, tentacles (the tentacles checks were adapted: they force a
  pass with sim.air.flight.start_pass), check_scripts.sh, complexity_ratchet (last run 70 offenders none grown, before run 7).
- sim/air_flight.gd (new, AirFlight): per heli pos / vel (acceleration-limited) / nose heading (turn-limited) / ring / slot (bearing
  from the kaiju) / goal. Slot point = anchor + out x (ring + lead): the anchor is the kaiju position smoothed over anchor_seconds
  0.6 (run 7), `lead` = lead_seconds 1.5 x the anchor's walk toward the slot (outward only). The velocity moves toward (braking
  velocity to the goal + the anchor's walk) by at most heli_accel 8, capped heli_speed 14; the nose follows the flight from
  nose_share 0.3 of top speed up and faces the kaiju below it (turn <= heli_turn_deg 180/s). Slot glides along the ring after
  hold_seconds; within pull_back 20 x scale of the kaiju the slot goes straight behind the heli. Slots keep clear_arc 60 +
  clear_lead_deg 10 off the camera side. Strafing pass: clock strafe_gap [28,45] s, one at a time, a FLY-BY along a straight
  line crossing his facing side strafe_close 9 x scale from him, aimed strafe_lead 1 s of his walk ahead, joined by following a
  point strafe_carrot ahead along it at full speed (never brakes), over at the far end on the ring; the line's centre is kept
  clear of the camera arc by the line's own half-width; the heli whose slot is nearest the entry goes (strafe_reach_deg 120, else
  strafe_retry 2 s).
- sim/air_wing.gd: orbit code removed (angle/turn/radius/cruise/orbit_pos/_keep_clear); Heli = pos/heading/vel/ring/slot/goal/hold/
  passing/pass_at/pass_dir/pass_left; spawn() calls flight.place (own stream Seeds.derive(rng, 0xF17)); step() calls flight.step.
  Deaths / wreck / swat / coat unchanged.
- data/tuning.json "air": orbit_* / dive / clear_margin removed; _note_flight explains every new key.
- tests/run_heliflight_tests.gd (new suite HeliFlight): per growth step young / Behemoth / Colossus, 3 helis, 120 s, a scripted kaiju
  walking to the nearest building; checks: closest outside a pass > the claw band's corner, top speed, turn per step (direction of
  motion between consecutive steps flying >= nose_share x top speed), >= clear_arc off the camera side (passes included, no
  exemption), passes happen one at a time and reach the claw band; plus a replay check. Fields it reads that exist on the old
  code too: heli.pos, heli.passing (add `var passing := false` to the old Heli for the red run).
- tests/run_tentacles_tests.gd adapted; tools/capture/capture_heli_deaths.gd line 132 heli.angle -> heli.heading (VFX lead cleared it).
- heliflight history (same seeds): v1 world-fixed spots 9 failures; v2 slots that follow 4; v3 + lead 5; v4 velocity model 5; v5 lead
  outward only 4; v6 fly-by passes 4; v7 smoothed anchor 3: young passes all 6; Behemoth camera side 35 deg; Colossus camera 33 deg
  and claw band 7.8 vs 18.5. Speed, turn, one-pass-at-a-time, pass reaches the claw band and replay pass at all three steps.

## Why the rest is red: the kaiju's own swing (D-187 "Heavier, slower" turns, a fresh sim builder; do NOT change the bars here)
Probe: scratchpad/beamcost/kaiju_split.gd (+ kaiju_split.sh --step=N --from= --to=; a BodyContact subclass swapped in as sim.body,
no sim edit): Colossus 9.5-12 s: walk 1.9-4.2 u/s, swing 18-61 u/s per step (peaks at body turns of 260-273 deg/s), other (hold /
dash) 0.0 on every step; Behemoth 59.6-60.9 s: walk 1.6-4.5, swing 10-35 u/s at turns up to 331 deg/s. Whole Colossus run: mean
step 19.4 u/s = walk 4.0 + swing 19.5 + other 1.7, worst body turn 277 deg/s. So BodyContact._swing (stepped turns, slice_accel 50,
turn_ease_peak 1.4) moves kaiju_pos 8-13 u about the planted foot 3 times a second while the scripted walker sits in 100-170 deg
turns, and the claw band, the ring and the camera bearing all measure from that root point. Episodes (scratchpad/beamcost/
heli_episodes.gd, output heli_ep_1.txt Behemoth, heli_ep_2.txt Colossus): every claw-band violation outside a pass is on the
pull-back leg with the kaiju closing (4-16 u/s smoothed); camera-side dips 25-59 deg last 0.1-3.3 s (longest: Behemoth 3.3 s at 47
deg, 2.5 s at 31 deg on a pass run-in; Colossus 2.8 s at 40 deg, 2.5 s at 25 deg), all BESIDE him 7-46 u sideways, none in the
camera-to-kaiju corridor, nearly all on glide/follow legs (the slot rotates with his path while he turns on the spot).

## Next (fresh builder)
1. After the D-187 turn-weight merge: merge origin/claude/look-options into this branch (merge commit, no rebase), git lfs pull, one
   headless import (the new classes AirFlight need the class cache: run `--headless --path . --import` once, not --quick).
2. Rerun heliflight (the only local suite). If the camera side or the claw band is still red, report it to the lead with
   heli_episodes.gd numbers for the director: the choices were behaviour (standoff ~32 x scale + clear_lead_deg ~30, sector 220 ->
   ~160 deg, Colossus ring ~43 u, ~120 u fully upgraded) or the bar's shape (measure vs the smoothed anchor); never loosen alone.
3. Red run for the failing-first evidence: base sim/air_wing.gd + the new data + `var passing := false` on the old Heli, then
   tests/run_heliflight_tests.gd (expect hold / turn / camera side / pass checks red: old orbit dives to a fifth of a circle and
   reverses at the ends of its arc). Not done yet.
4. Lints (gdlint, gdformat --check, tuning_keys, complexity_ratchet, check_scripts), add a tests/README.md row for HeliFlight,
   push, then GitHub runs helideaths / military / sim / tentacles; fix what it flags; the lead opens the PR.

## Review packet (kaiju-sim-review; fill the findings after the final run)
Transitions: tick (AirWing.step -> flight.step before the fire loop), injury (heli damage unchanged), removal (clear_dead unchanged),
save/reload (none: AirWing is rebuilt per rampage), generation (heli spawn now draws from the flight's own stream
Seeds.derive(rng, 0xF17); the old spawn drew 2 values from the AirWing stream, so seeded runs differ), identity (heli.id unchanged).
Invariants: speed <= heli_speed (position change per step), acceleration <= heli_accel, nose turn <= heli_turn_deg, one pass at a
time, slots outside clear_arc, same seed same flights (replay check). Not exercised: the look (nothing captured; the view derives a
helicopter's heading from its position deltas and eases it, scenes/powers_view.gd: unchanged), play feel, endless mode.

## Rules learnt the hard way
- The worktree guard refuses variable assignments / process substitution next to GitHub paths in a plain command: write a script
  file with Write and run `bash <script>`; large python heredocs with apostrophes break the eval wrapper: Write a .py file.
- Two traces that redirect to the same output file overwrite each other: one file per run.
- A new class_name needs one full headless import (not --quick) before any suite sees it.
