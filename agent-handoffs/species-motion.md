# Species-motion handoff, 2026-10-17 02:40
## State: running a check (CI captures of round 3b; then send to lead)

## Task
Mantis (insectoid) and octopus (cephalopod) locomotion, taken over from kaiju-motion (which keeps
the reptile). QA round 3 findings 1-11 (lead brief). Evidence -> lead, never the director.
Director: insect must "disturb and disgust" (skitter, twitch, exoskeletal); octopus must slide,
push and pull, grab edges, never tip-toe; never wind-up-toy.

## Branch and commits
- claude/species-motion, cut from claude/kaiju-motion-species (PR #11, stacked on PR #10).
  No PR of its own yet: plan is a PR into claude/kaiju-motion-species once the lead OKs clips.
- 4f98a07 rigs (octopus ownership grown over voxels; mantis limbs whole) + tools/capture/bone_sheet.py
- 6aa486f mantis gait (holds/darts, leg-led turns, HexapodUpper twitches, roar flare),
  capture_motion --pose-trace, tools/capture/motion_report.py
- 324d14a octopus gait (3 front arms take turns, drag/surge body, breathing, roar puff/ripple)
- 7b7759b mantis mandible bones (rig) + flare; turn rate 9.5
- 05c904f merged PR #11 head a6c1f0b (pose-trace moved to tools/capture/pose_trace.gd for the
  400-line cap); all suites pass locally. Lead PASSED octo_bone_sheet_r3.
- kaiju-motion agreed the split. kaiju-look-test (D-041 voxel skin) reads my rigs: rerun its
  tools/kaiju_skin/bake_all.sh after any rig change; it needs the _mantle scale mirrored.

## File split (agreed with kaiju-motion)
Mine: scenes/gait_hexapod.gd, hexapod_upper.gd, gait_radial.gd, cephalopod_stand_in.gd,
assets/kaiju/insectoid_*, cephalopod_*, radial/hexapod parts of tools/blender/rig_voxel.py.
Theirs: biped files, kaiju_rig.gd / kaiju_gait.gd / kaiju_model.gd core. Shared: capture_motion.gd.

## Measured (motion_report.py, headless 60 fps)
- Mantis holds 0.08-0.45 s irregular (cv ~0.3), body travel in a hold 0.0000; darts ~23 u/s.
- Mantis body turn 0.28 s adult / 0.20 baby; a foot is in the air before the body turns.
- Mantis rest: twitch onsets every 0.03-0.17 s; longest still 0.13 s.
- Octopus grips every 0.6-0.9 s adult / 0.38-0.52 baby, straight walk by 3 arms in turn
  (baby t2 t4 t6); body 0.9-1.1 u/s before a grip, 6-11 u/s just after.
- Rigs (bone_sheet.py): octopus fragments/slate islands/unchained long runs all 0;
  mantis fragments 0. Tentacle counts now 10/7/13 (dropped head-shell ridges).

## Evidence locations
side-session-notes/local_9fac90d2.../species-motion/: octo_bone_sheet_r3.png (+ _before),
mantis_bone_sheet_r3.png, mantis_r3a/ (first mantis clips + numbers.txt; older twitch amplitudes).

## Running jobs
- CI capture runs 38921990591, 38922002812, 38922014860, 38922028125 (capture.yml dispatched
  --ref claude/look-options -f ref=claude/species-motion; main's copy fails as "workflow file
  issue"). Download: gh run download <id> --dir <dir>.
- Local tests (tools/run_tests.sh) in background, log $TEMP/sm_tests.log.

## Next
1. Download CI clips, check, send round 3b (mantis + octopus) to the lead.
2. Octopus: building-edge grips in a city capture (grip_finder) not yet shown; octopus turn is
   0.7-1.0 s (not in brief). Baby readability at game cam unverified.
3. Open PR into claude/kaiju-motion-species when the lead OKs.

## Rules learnt
- focus-guard blocks ALL windowed Godot while the director plays fullscreen: use CI capture.
- capture_motion steps 1/60 s per frame: record with --fixed-fps 60, never 30 (half speed).
- Movie writes at 1920x1080 regardless of --resolution locally.
- Static typing: Variant -> float() is an error; use PackedFloat32Array, typed dicts.
- Object has _set(): never name a helper _set.
