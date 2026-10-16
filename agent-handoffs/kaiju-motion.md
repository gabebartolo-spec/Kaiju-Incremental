# Kaiju-motion handoff, 2026-10-17 01:30
## State: awaiting lead (reptile round 4 critic on PR #10; species round 2 critic on PR #11)

## Task
D-031: species-true kaiju locomotion. Reptile = Godzilla-to-T-rex lean (20-30 deg) with T-rex
grace; insectoid = skittering, disturbing mantis; cephalopod = sliding/gripping octopus/hydra
(D-036). Presentation only. Evidence -> lead -> motion critic -> director. D-032: cost recorded,
not a limit. D-035 (docs/SPECIES.md): powers; hooks on KaijuModel for species-powers session.

## Branch and commit
- claude/kaiju-motion -> PR #10 (reptile). Round 4 at ed5e96d (+ lint fix): jaw bone (rig_voxel
  split_jaw + "close"), level shoulders (0.9 deg), eased plants + 5% jitter, trip, dust/nudge.
  Force-push is denied: merge, never rebase a pushed branch.
- claude/kaiju-motion-species -> PR #11 (base claude/kaiju-motion; retarget to look-options once
  #10 merges). Round 2 at 5ac909e: mantis twitch/fold/bursts/knee snap, hydra turn-arm-over-arm,
  power hooks (tail_sweep, jaw_open, grab, throw, limb_tip), all 3 cephalopod stages rigged.

## Unfinished changes
- none uncommitted. Next: lead verdicts on PR #10 round 4 and PR #11 round 2.
- Mantis textured GLBs coming from the lead -> re-rig at 100/130/160 (species insectoid).
- Adult hydra: two raised arches have no chain (ride the mantle); max_arms 16 is the cap.
- D-035 locomotion anticipation (insect jump/climb, octopus squeeze through gaps) not started.

## Evidence so far
- capture_motion.gd: --cam=game|side|fixed, event labels, --trace CSV (+ _plants.csv).
- Slide 0.0 cm everywhere; reptile plants every ~0.44 s +-5%, speed dip at plants.
- Clips: side-session-notes/local_9fac90d2.../kaiju-motion/{round2,round3,round4,species1,species2}/.

## Attempts (fix-loop record)
- Reversal foot slide -> step/hop rules + eased sink -> 0. Z-fight stripes -> inset filler.
- Uneven steps after the hold: stride outran reach + pelvis resonance -> stance 0.48 hip,
  landing clamp anticipates hold, rescue steps counted as slot steps, stiffer pelvis.
- Jaw: red mouth-interior voxels give the cut and the close angle (cap 0.7 rad).
- Radial: tips by furthest-surface claiming; baby head fixed by mantle-centre, thin-tip and
  on-bone rules.

## Open decisions
- none (licensing rows added by lead, 7cae54e).

## Running jobs
- none. Remove override.cfg after any capture.

## Findings for the lead
- Plot pelvis height + forward speed per frame (--trace) to prove rhythm; it exposed uneven steps.
- Log plant/lift events with reasons: two "rescue" rules were silently driving the gait.
- Bone-ownership plots (front/side, coloured per bone) catch rig faults before any capture.

## Rules learnt the hard way (under 10 lines)
- Windowed Godot steals focus from the director's fullscreen games: focus-guard blocks it then.
  Work headless, retry captures minutes apart, batch all clips into one short windowed run.
- Never edit .gd while a local suite/capture runs; after switching branches run --import.
- gdlint: 400 lines/file, <=4 args, 20 public methods, signals first, public vars before private.
- Kill only Godot PIDs you started (check CreationDate/CommandLine).
