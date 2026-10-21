# turn-step handoff, 2026-10-21
## State: handing off at ~245k context; option B (stepped turn) is NEXT, test written, no code yet
## Task
Lead 10: fix the turn (comments #16, 2026-10-21 #3 "swivelling on the spot like a plastic toy") on
PR #144 (claude/turn-weight). Lead's ruling (director 2026-10-21 "bigger = slower but not TOO
slow, lumbering within reason, its not fun to play if hes too sluggish"): sim turn rate scaled by
body size; adult 90 deg in about 1.0-1.2 s; >=2 footfalls; yaw only with a foot down; baby keeps
its <=1.5 s about-face; planted-foot drift <5 cm. Then ONE adult turn90 CI clip at --cam=game.
Also: ci_capture.sh reads its own run id from `gh workflow run`'s output.
## Branch and commit
Worktree Kaiju-Incremental-wt/turn-step, local branch claude/turn-step tracking
origin/claude/turn-weight (base 9fc46308). Push with `git push origin HEAD:claude/turn-weight`.
## Changes (uncommitted, worktree turn-step)
- sim/body_contact.gd _rate(): turn_rate and turn_rate_still / body_scale^turn_size_exp.
- data/tuning.json contact: turn_rate 3.5 -> 1.85, turn_rate_still 6.0 -> 3.0, turn_size_exp 1.0
  (the baby, scale 0.5, keeps its old 3.7/6.0 rad/s; exp 0.5 failed city rise-point 10.9 s and
  the powers beam graze; turn_slow 0.35 made city worse, 11.4 s).
- tests/lib/smoke_step_turn.gd (smoke, StepTurn): adult turn90 at 60 Hz, 3 checks (time
  1.0-1.25 s, >=2 footfalls, drift <5 cm).
- tools/capture/capture_walks.gd (from walk-m2 517fa36c, no --bare, local FOCUS_FOLLOW).
- tools/capture/ci_capture.sh reads its run id from `gh workflow run` output.
## Evidence so far
Fail first (9fc46308): adult 90 deg 0.60 s, 21 yaw frames both feet up. Now: adult 1.10 s,
4 footfalls, drift 0.0 cm; adolescent 0.80 s; baby 0.60 s. Still 36 yaw frames with both feet up
(FOLLOW-UP, lead chose A: not pinned in the test, measured by scratchpad probe_turn.gd).
Full local suite: all pass but native (no local dll); military re-pinned RAMPAGE_SEEDS
[2,4,8] -> [3,6,9] (5 -> 154 tank-steps in range; seeds 0-11 also showed a hull-touch fail on
some other seed: latent); claws check now uses per-run cities (its 5 pairs were one city).
Cause (per-frame log): the node turns about kaiju_pos, ~8.6 body units behind the planted feet
(adult; baby 4.7, adolescent 5.2), so 10 deg swings the stance foot 1/3 stride -> catch re-steps
that overlap the other foot's swing.
## Attempts (fix-loop record, all reverted)
hold yaw aloft (body lag 0.8 rad, HeadLead slide fails); defer re-step (foot dragged 20 m);
hurry other foot down (drag 10 m); turning cadence 1.4/2.0 (more aloft); sim pivot about the feet
(12 aloft); pivot + forward-speed cycles (16 aloft).
## Option B (lead 10 QC FIX, 2026-10-21): the turn still reads as a swivel
Pass bar (tests/lib/smoke_step_turn.gd, extended; on d24fe80e it FAILS aloft 36 and slices 50%,
passes the rest, so smoke is red on #144 until B lands): adult 90 deg in
1.0-1.25 s; >=3 distinct (alternating-side) footfalls; 0 frames yawing with both feet up; >=70%
of the yaw in the 0.15 s after a footfall (slices, not a smooth swivel); drift <5 cm; baby 90 deg
within 10% of 0.60 s. Then ONE ~6 s adult turn90 clip at --cam=game with the label OFF (add a
--no-label arg to capture_walks.gd). Commit by name, push HEAD:claude/turn-weight.
Design (sim stays the authority, it decides the steps; the gait follows):
1. Pivot about the feet in the sim (tried once, worked as designed): per-stage "pivot" in
   contact.bodies = planted-feet mean local z 4.7 / 5.2 / 8.6 (baby/adol/adult, body units);
   in BodyContact.steer: `was := heading` before the facing turn, after _face():
   `sim.kaiju_pos += (was - heading) * pivot * sim.body_scale()`. Alone it gave 12 aloft frames
   because the gait cycled from |node velocity| (the tail-end swing); forward-only speed made it
   16: the gait must not time steps off the node's speed at all (step 3).
2. A sim step clock in BodyContact: phase += travelled / step_len (step_len per stage, from the
   clip stride: world stride baby 2.19 adol 5.12 adult 6.29 at their scale, half a stride per
   step; shorter while turning so 3 steps fit 1.1 s). Each footfall (phase crosses a half) opens
   a yaw slice: facing may turn only for the first part of each step (a data share), at the rate
   that lands 90 deg in ~3 slices; between slices facing holds (turn_left keeps growing -> the
   head/neck lead via _look_ahead, already there).
3. ClipGait reads the sim's step phase (pass it through KaijuModel.animate like turn_ahead) and
   sets the walk clip_time from it, aligned so the clip's plant frames (compute at init from
   pose.planted, as _yaw_span does) land on the sim's footfalls. Then footfalls = yaw slices,
   and no re-step shuffles if pivot (1) keeps the planted feet put.
Watch: seed-sensitive fixtures (military RAMPAGE_SEEDS, city rise-point 10 s, claws, powers
beam graze); re-probe and re-pin, never loosen. Baby must stay within 10%.
## Running jobs
none. Clip: CI run 39584466780 (ci_capture.sh took the run id from gh's output), notes
walk-m2/clips/turn_adult_turn90_after.mp4, 6 s 60 fps game cam, drift 0.0 cm.
Review (10 fps crops 3.3-4.8 s): head leads at 3.6 s; the body swings over ~0.8 s (was 0.4 s),
tail sweeping wide; leg poses change through it, but from the game cam it still reads as a smooth
pivot more than distinct steps. B (gait rework) is the lead's call to the director.
## Findings for the lead
Both-feet-up frames in a turn come only from overreach re-steps (straight walking has 0); the
node turns ~8.6 body units behind the adult's feet.
