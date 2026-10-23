# Gait step-len handoff (builder "volley"), 2026-10-23 15:0x
## State: waiting for 16:01 (director: no Godot until then); code and tests written, not yet run green
## Task
D-177 "Motion first", the director's top complaint (the adolescent's twitchy walk and swivelling turn). From the
VFX lead's probe: (1) per-stage step length in data, read by the sim; (2) a held analog curve must step its turn,
not swivel. Sim and data only; gait_clip.gd and tests/run_motion_tests.gd (branch claude/gait-fix) are the VFX
lead's, untouched. Bars: the sim step within 2% of each stage's clip half-stride; 0 degrees of held-curve yaw with
no foot down for the Behemoth (38.5 on the base) and the Colossus (46.0 on the base); tapped and stepped turns as today.
## Branch and commit
Branch claude/gait-step-len off origin/claude/look-options cf40e09b, worktree .claude/worktrees/agent-ac92f78143e5f1af5.
Not pushed (the branch's upstream is look-options by accident: push only as `git push origin
claude/gait-step-len:claude/gait-step-len`). No PR (the lead opens it).
## What changed
- data/tuning.json contact.bodies.reptilian[i].step_len = 2.19 / 2.79 / 2.33 (young / Behemoth / Colossus, rig
  units at body scale 1). contact.step_len 2.33 stays as the fallback and for gait_clip.gd (the VFX lead's).
- sim/body_contact.gd: `_step_len` (the stage's own, read in use_species) replaces cfg["step_len"] in _plant_both,
  walked (two places). A held curve: `_smooth_yaw` counts the yaw turned smoothly over steps in a row and
  `_step_yaw` the yaw (either way) since the last footfall; a footfall whose step turned less than turn_min ends the
  curve (`_smooth_yaw` = 0). `_steps_this_turn` counts `_smooth_yaw` >= smooth_below as a real turn, so it is stepped
  (slices at the footfalls) like a tapped one. Standing resets it.
- The lead's wording was "yaw turned smoothly since the last footfall"; reset at every footfall it would never reach
  0.35 rad on the probe's 30 deg/s route (about 0.24 rad a Behemoth step, 0.29 a Colossus step), so the sum carries
  across footfalls until a step with no turn ends it. Tapped and stepped turns add nothing to `_smooth_yaw`.
- Split at a natural seam (the file would have reached 390): BodyContact._sweep and sweep_pose moved to
  BodyVolume (sweep(from, from_heading, to, to_heading) -> chunks broken; step_s set by BodyContact). body_contact.gd
  349 lines, body_volume.gd 130. tests/lib/sim_body_contact.gd calls BodyVolume.sweep_pose.
- tests/lib/smoke_stage_gait.gd (new, called from smoke_step_turn.gd, which replaces its adult-only stride check):
  at all three stages the data step and the sim's measured step (distance / phase) vs the clip's half-stride, and the
  held-curve route (stick swept at 30 deg/s from t=2 s, 6 s, the motion gate's) aloft yaw for the stepping stages.
- Lead 15:1x: the smoke gait tests now drive each stage with its own tuning (CityGrowth.for_stats(stats), as
  Rampage and the motion gate do; the young croc walks at its stage's 3.3, not the adult's 5.5), in
  smoke_stage_gait.gd and in smoke_step_turn.gd `_turn`; the adult-only stride/step_len outputs of `_turn` are gone.
  Young and baby bars are rechecked after 16:01 (the baby's 0.60 s turn bar may move: re-pin only if measured).
- Lead 15:1x: if the held-curve aloft yaw stays above 0, also apply a smooth turn only while a foot is planted
  (`_planted()`: the first slice_open of each step); patch ready in the scratchpad (gait_planted_patch.py), measure
  both variants and report the numbers with the push.
## Review packet (shared sim rules, reviewer is not the author)
Transitions: stepped turn start/stop (`_real_turn`), footfall bookkeeping in walked(), the step clock (phase) per
stage, set-off from a stand (`_stand`), the sweep split. Invariants: tapped turns unchanged (`_smooth_yaw` only grows
in smooth steering); a stage without step_len falls back to contact.step_len; the baby never steps (pivot 0) so
its turns stay smooth (D-131); determinism (no clock, no RNG added); no save change. Not exercised: play feel.
## Evidence so far
- RED on the base (smoke, quick, 14:4x): 5 failures: young data 1.165 vs clip 1.094; Behemoth data and sim step 2.139
  vs 2.561; Behemoth held curve 38.5 deg aloft; Colossus held curve 46.0 deg aloft (Colossus step already 2.33).
- Lints clean (gdlint, gdformat, tuning_keys, complexity ratchet) on the code.
## Unfinished (after 16:01 only)
- Run smoke green; then taskforce_gate, sim (body contact), sim_play, military and any suite that tips; re-pin or fix
  behaviour, never a threshold (D-144).
- Scratch-merge origin/claude/gait-fix (b73b2ad4) on a throwaway branch, run its motion suite: step and held-curve
  bars must be green (its jerk, reach, lift, catch bars are the VFX lead's); delete the throwaway branch.
- Push, report data keys and sha.
## Parked
claude/strike-delay (local commits only, tree clean): strike 33 checks, powers, fire, carving green; sim green; growth
and destruction need a rerun on it; military, taskforce_gate, demoend not run. The base moved: merge it before pushing.
## Rules learnt the hard way
- The worktree guard refuses `git` inside python text and `cd` to another worktree; use Edit/Write for those files.
