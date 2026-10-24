# Gait step-len handoff (builder "volley"), 2026-10-23 16:3x
## State: running a check (sim, taskforce_gate on the review-fix code); pushed once as 14f47473, review FIX (#173) in progress
## Task
D-177 "Motion first", the director's top complaint (the adolescent's twitchy walk and swivelling turn). From the
VFX lead's probe: (1) per-stage step length in data, read by the sim; (2) a held analog curve must not swivel.
Sim and data only; gait_clip.gd and tests/run_motion_tests.gd (branch claude/gait-fix) are the VFX lead's, untouched.
Bars: sim step within 2% of each stage's clip half-stride; 0 degrees of held-curve yaw with no foot down for the
Behemoth (38.5 on the base) and the Colossus (46.0); tapped and stepped turns as today.
## Branch and commit
Branch claude/gait-step-len off origin/claude/look-options cf40e09b, worktree .claude/worktrees/agent-ac92f78143e5f1af5.
First push 14f47473 (code 8bdbc732, merged with the base); the sim review of PR #173 said FIX, fixed below. Push only
as `git push origin claude/gait-step-len:claude/gait-step-len` (the upstream is look-options by accident). A
local-only scratch branch scratch/gait-merge (the throwaway merge with gait-fix) is left; never pushed, the lead
lists it for the director's hygiene pass.
## Review FIX (#173): one root, the swing ran for ANY heading change, not only the stick's turn
- Hand-over lurch: emergence leaves body.heading along the river about 90 deg off sim.facing; a stick held from the
  first live tick swung the catch-up about the planted feet (5.2 u Behemoth, 10.3 u Colossus in 12 frames). Fix:
  _swing(was, most) clamps the swing to the turn the stick applied (absf(turn)); a larger catch-up stays about
  the middle, as before the gait fix.
- Dash: Dash.step resets facing every frame so the swing was never undone; a stick 0.2 rad off the axis slid the
  dash 3.8 u (Behemoth) and 7.2 u (Colossus). Fix: no swing while dash.on().
- tests/run_gait_tests.gd (new suite "gait", 10 checks): hand-over (12 frames, < 3 u), dash 0.2 rad off axis (< 1 u
  sideways), straight top speed = the stage's speed (within 1%). RED before the fix: 4 failures (the four numbers
  above); green after. Smoke 47 checks green after (held curve still 0.0, stepped-turn bars unchanged).
- The young croc's step_len is dropped from the data: the baby does not step (pivot 0, D-131), the sim never read
  it, the motion gate skips it, and only my smoke young data check read it (now stepping stages only).
## What changed
- data/tuning.json contact.bodies.reptilian[i].step_len = 2.79 / 2.33 (Behemoth / Colossus, rig units at body
  scale 1; the young entry has none). contact.step_len 2.33 stays as the fallback and for gait_clip.gd (VFX lead's).
- sim/body_contact.gd: `_step_len` (the stage's own, read in use_species) replaces cfg["step_len"] in _plant_both and
  walked (two places). Every turn of a stepping body (turns_in_steps) is now swung about the planted foot (_swing),
  smooth corrections too, not only stepped turns; the baby (no planted feet, D-131) and the beam sweep are unchanged.
- Split at a natural seam: BodyContact._sweep and sweep_pose moved to BodyVolume (sweep(from, from_heading, to,
  to_heading) -> chunks broken; step_s set by BodyContact). body_contact.gd 340 lines, body_volume.gd 130.
  tests/lib/sim_body_contact.gd calls BodyVolume.sweep_pose.
- tests/lib/smoke_stage_gait.gd (new, called from smoke_step_turn.gd in place of its adult-only stride check): each
  stage on its own tuning and speed (CityGrowth.for_stats, the young croc walks at 3.3, lead 16:0x): the data step
  and the sim's measured step (distance / phase) vs the clip's half-stride (2%), and the held-curve route (stick swept
  at 30 deg/s from t=2 s, 6 s, the motion gate's) aloft yaw for the stepping stages (bar 0.0).
## Held-curve aloft yaw, degrees (Behemoth / Colossus), each variant measured on the smoke route
- base 38.5 / 46.0 (red).
- A, the lead's "yaw summed over steps in a row makes a real stepped turn": 7.2 / 5.8.
- B, A + smooth yaw only inside the sim's planted window (square): 10.2 / 9.1 (worse).
- C, A + smooth yaw weighted by the slice bell: 8.0 / 9.6, and the adult's yaw-rate-jump bar failed (42% > 25%).
- D, A + smooth turns swung about the planted foot: 0 / 0. D without A: 0 / 0. SHIPPED: D alone (no carried sum, no
  new state, tapped and stepped turns untouched).
- Why: a straight walk has a foot down in every phase bin (measured), the aloft frames only appear during the smooth
  curve: smooth yaw turned the body about its middle, dragged the planted feet, and the view re-stepped (a catch
  step, both feet off for about 0.25 s). Pivoting over the planted foot, as a stepped turn does, removes the drag.
## Evidence so far
- Red on the base (smoke, quick): young data 1.165 vs clip 1.094; Behemoth data and sim step 2.139 vs 2.561; Behemoth
  held curve 38.5; Colossus 46.0 (Colossus step already right).
- Green: smoke 13 of 13 functions, 48 checks, 0 failures (all three stages' stride, held curve 0.0, baby 0.60 s bar,
  adult turn bars).
- Scratch merge with origin/claude/gait-fix e73d6c78, tests/run_motion_tests.gd: 29 checks, 5 failures, none mine:
  young catch-step shuffle (curve 2.2 a second, bar 0.5), knee pops (shin jerk p99 young 6.0, Behemoth 6.3, bar 5),
  planted leg locked straight (reach up to 0.99 on the turns, bar 0.97, Behemoth and Colossus): the VFX lead's view
  bars. Step length at every stage, "never yaws with no foot down" (Behemoth, Colossus; young skipped by D-131)
  and the pivot bars PASS.
- Lints clean (gdlint, gdformat, tuning_keys, complexity ratchet) on the code.
## Unfinished
- Running: sim, taskforce_gate, military, sim_play on 8bdbc732 (a smooth correction now swings about the foot, so
  seeded autoplay positions may shift a little: fix behaviour or re-pin, never a threshold, D-144).
- tools/lint/complexity_ratchet.py and tools/check_scripts.sh before the push; push; report the data keys and sha.
## Parked
claude/strike-delay (local commits, merged with the base 14:50): strike 33 checks, powers, fire, carving, sim green;
growth, destruction, military, taskforce_gate, demoend, sim_play need a rerun on it. Its handoff is
agent-handoffs/strike-delay.md on that branch.
## Rules learnt the hard way
- The worktree guard refuses `git` inside python text and `cd` to another worktree; use Edit/Write for those files.
- A throwaway merge needs its own branch and a class-cache import after switching (new class names).
