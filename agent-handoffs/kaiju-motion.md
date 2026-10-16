# Kaiju-motion handoff, 2026-10-16 23:05
## State: running a check (species suites + city captures); reptile round 2 awaiting lead critic

## Task
D-031: rebuild kaiju locomotion per species. Reptile = Godzilla-to-T-rex lean (20-30 deg from
vertical, director correction) with T-rex grace; insectoid = skittering mantis; cephalopod =
sliding/gripping octopus. Presentation only. Evidence -> lead -> motion critic -> director.
D-032: looks first; rig cost no longer a limit but recorded in PRs.

## Branch and commit
- claude/kaiju-motion -> PR #10 into claude/look-options. Round 2 at 0bd36d1 (+ d948f25,
  an `-s ours` merge of the pre-rebase head: force-push is denied here, never retry it).
- claude/kaiju-motion-species (local, on top of #10): hexapod + radial gaits, mantis rigs
  baby/adolescent/adult (assets/kaiju/insectoid_*), octopus stand-in, rig_voxel.py
  hexapod/radial skeletons, rampage grip hook, foot_planted emits, smoke 13. Not pushed yet.

## Unfinished changes
- Species branch: commit (assets + gaits + smoke), push as claude/kaiju-motion-species, PR into
  look-options after #10 (body drafted in scratchpad pr_species.md; update ids/clip names).
- Send lead: city_*.mp4 (real rampage among buildings) + bug/octo clips for the critic.
- Octopus sculpt (lead generating ff432a4f): rig with species "cephalopod" (radial skeleton),
  then drop CephalopodStandIn in KaijuModel.

## Evidence so far
- tools/capture/capture_motion.gd (--cam=game|side|fixed): slide 0.0 cm for reptile adult/baby,
  insect baby/adolescent/adult; rig 0.08-0.3 ms avg.
- Reptile torso 24 deg standing / 27 walking from vertical; tail -3 deg (measured in engine).
- Clips: side-session-notes/local_9fac90d2.../kaiju-motion/ (round 1) and /round2/.
- Mantis bone-ownership plots: scratchpad rig/bones_all.png.

## Attempts (fix-loop record)
- Foot slide on reversals -> step/hop rules + eased pelvis sink -> 0.
- Z-fight stripes on legs -> joint overlap voxels moved to an inset filler layer.
- Tail "banana": lift sign was inverted (negative raised it); now soft chain + delayed sweep.
- Mantis: knees/hips by arc fraction; limb roots penalised; antennae as islands handled;
  head-zone override so the head turns as one piece.

## Open decisions
- Licensing register has no rows for Tripo kaiju sculpts (lead to record; nothing marked by me).
- Roar wind-up starts at the ability event (breath VFX starts during it).

## Running jobs
- Background: species suites (/tmp/kgtests3.log), city captures (scratchpad clips/city_*.avi).
- Delete override.cfg in this worktree when captures finish.

## Findings for the lead
- capture_motion's printed foot drift caught every slide bug before any clip was watched.
- Clamps belong in the pose, not in spring state (pelvis sank every frame, hip 5.1 -> 1.7).
- Measure posture in engine (pelvis->neck angle) before arguing about it from stills.

## Rules learnt the hard way (under 10 lines)
- Never edit .gd while a local suite or capture runs; switch branches -> --import first.
- gdlint: 400 lines/file, <=4 args/function, signals before consts.
- Kill only Godot PIDs you started (check CreationDate/CommandLine).
