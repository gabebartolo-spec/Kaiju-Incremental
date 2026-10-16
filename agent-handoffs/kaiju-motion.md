# Kaiju-motion handoff, 2026-10-16 22:15
## State: running a check (species PR suites); reptile PR #10 green, awaiting lead review

## Task
D-031: rebuild kaiju locomotion per species (reptile = JP T-rex, insectoid = skittering mantis,
cephalopod = sliding/gripping octopus). Presentation only; the gait reads the node's motion.
Brief from the lead (local_9fac90d2-...); evidence goes to the lead for a motion-critic review.

## Branch and commit
- claude/kaiju-motion -> PR #10 into claude/look-options (reptile + gait system), CI 8/8 green.
- claude/kaiju-motion-species (local, on top of #10): hexapod + radial gaits, mantis rig, octopus
  stand-in, rig_voxel.py hexapod/radial skeletons, rampage grip hook. PR into look-options
  after #10 merges (or stacked on #10's branch).

## Unfinished changes
- species branch: commit after suites pass; add insect/octopus drift checks to smoke; PR.
- Insectoid baby/adolescent use the adult rig until the lead's nymph sculpt exists
  (rig it: blender -b --python tools/blender/rig_voxel.py -- <glb> assets/kaiju/insectoid_baby insectoid 110).
- Octopus sculpt: when it exists, rig with species "cephalopod" (radial skeleton) and drop
  CephalopodStandIn from KaijuModel.

## Evidence so far
- tools/capture/capture_motion.gd: scripted walk/curve/sharp turn/stand+stomps/roar/reversal;
  prints foot drift + rig ms. Reptile adult/baby drift 0.0000, insect 0.0000, octopus tips n/a.
- Rig cost 0.06-0.30 ms avg per frame (budget 0.5).
- Clips (60 fps mp4) in side-session-notes/local_9fac90d2.../kaiju-motion/.
- Smoke check "the reptilian's planted feet hold" (seen failing with reach-stepping disabled).

## Attempts (fix-loop record)
- Foot slide 6-8 units on reversals -> out-of-reach feet step/hop, pelvis sink capped (was
  accumulating every frame), stance excursion capped by speed -> 0.
- Leg gaps on bent voxel limbs -> RigJoints overlap bands; less crouch/tilt.
- Upright Godzilla posture -> lean 0.3-0.48 rad, tail lowered and straightened.
- Insect front legs landing past reach -> home pulled in 15%, landing clamped to 90% reach.
- Octopus arms coiled under the body -> per-chain contraction (min 0.7), all arms aim forward.

## Open decisions
- Licensing register has no row for any Tripo kaiju sculpt (reptiles already in assets/, mantis
  added on the species branch). Lead to record/clear; I marked nothing CLEARED.
- Roar wind-up (0.3 s head back) starts at the ability event; breath VFX could start after it.

## Running jobs
- Local suites on the species branch (background); no override.cfg left after captures (delete
  override.cfg in this worktree when done).

## Findings for the lead
- capture_motion's printed foot drift caught every slide bug before any clip was watched
  (evidence: drift 8.05 -> 0.0000 across 4 fixes, PR #10).
- Measure the persistent-state mutation trap: modifying a spring's state inside a clamp made the
  pelvis sink every frame (hip 5.1 -> 1.7); clamps belong in the pose, not the state.

## Rules learnt the hard way (under 10 lines)
- Never edit .gd files while a local suite runs: it compiles scripts lazily and fails spuriously.
- New class_name files need a headless --import before a --script run sees them.
- gdlint caps files at 400 lines; split helpers (BipedHead, BipedSwing, RigJoints).
