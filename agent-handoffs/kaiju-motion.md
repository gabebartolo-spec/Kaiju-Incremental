# Kaiju-motion handoff, 2026-10-17 00:40
## State: awaiting lead (reptile round 4 critic on PR #10; hydra + species critic on PR #11)

## Task
D-031: species-true kaiju locomotion. Reptile = Godzilla-to-T-rex lean (20-30 deg from vertical,
director) with T-rex grace; insectoid = skittering mantis; cephalopod = sliding/gripping octopus.
Presentation only. Evidence -> lead -> motion critic -> director. D-032: rig cost recorded, not
a limit.

## Branch and commit
- claude/kaiju-motion -> PR #10 (reptile), round 4 at ed5e96d: jaw bone (rig_voxel split_jaw,
  "close" angle), level shoulders (0.9 deg max), eased plants + 5% jitter, trip, dust/nudge.
  Force-push is denied here: merge, never rebase a pushed branch.
- claude/kaiju-motion-species -> PR #11, stacked on #10 (base claude/kaiju-motion). Retarget to
  claude/look-options once #10 merges. Mantis baby/adolescent/adult rigs, hexapod + radial gaits,
  octopus stand-in, grip hook, smoke 13.

## Unfinished changes
- none uncommitted. Next: act on the lead's round-3 / species critic verdicts.
- Hydra adult rigged (octo_2, 16 tentacles found, b0a34cc). Open: a stray voxel fragment near
  the head and a pale patch at the mantle front in hydra_game.mp4; baby/adolescent hydra GLBs to
  come from the lead (rig at 100/130 with species "cephalopod").
- D-035 (docs/SPECIES.md): locomotion should anticipate reptile tail-sweep/momentum, insect
  jump/hover/climb, octopus grab-and-throw and squeezing through gaps. Not started.
- Mantis GLBs are untextured (palette colours); textured exports would let rig_voxel sample skins.

## Evidence so far
- capture_motion.gd: --cam=game|side|fixed, event labels, --trace CSV; slide 0.0 cm for all.
- Rhythm (round 3): plants every 0.52 s; speed dips 6.1 -> 1.4 at each plant, pelvis drops 0.5.
- Clips: side-session-notes/local_9fac90d2.../kaiju-motion/{round2,round3,species1}/.
- Rig cost 0.08-0.31 ms avg per frame.

## Attempts (fix-loop record)
- Reversal foot slide -> step/hop rules + eased sink -> 0.
- Leg z-fight stripes -> inset joint filler layer.
- Tail lift sign inverted; then raised + delayed sweep + flick.
- Uneven steps after adding the hold: stride longer than reach + pelvis resonance at stride
  frequency -> stance 0.55 hip, landing clamp anticipating the hold, slot bookkeeping, stiffer
  pelvis -> even 0.52 s steps.
- Mantis: head zone override, antenna islands, root penalties.

## Open decisions
- Licensing register lacks rows for Tripo kaiju sculpts (lead).

## Running jobs
- none. No override.cfg should remain (delete if present).

## Findings for the lead
- Plot pelvis height + forward speed per frame (capture_motion --trace) to prove rhythm: it
  exposed the uneven stepping that stills hid.
- Log plant/lift events with reasons: two "rescue" rules were silently driving the gait.

## Rules learnt the hard way (under 10 lines)
- Windowed Godot steals focus from the director's fullscreen games: focus-guard blocks it then.
  Work headless, retry captures minutes apart, batch all clips into one short windowed run.
- Never edit .gd while a local suite/capture runs; after switching branches run --import.
- gdlint: 400 lines/file, <=4 args, signals before consts, public vars before private.
- Kill only Godot PIDs you started (check CreationDate/CommandLine).
