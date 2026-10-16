# Species-motion handoff, 2026-10-17 02:40
## State: running a check (CI captures of round 3b; then send clips to the lead)

## Task
Mantis (insectoid) and octopus (cephalopod) locomotion, taken over from kaiju-motion (it keeps
the reptile). Lead's QA round 3 findings 1-11. Evidence goes to the lead, never the director.
Director: the insect must "disturb and disgust" (skitter, twitch, exoskeletal); the octopus must
slide, push and pull, grab edges, never tip-toe; never wind-up-toy.

## Branch and commit
- claude/species-motion at 5cfdd4d (pushed). Cut from PR #11's head; since merged with PR #11's
  head (0490f07, includes KaijuGrip and close_jaw) and claude/look-options (capture.yml that can be
  dispatched). Merge, never rebase.
- No PR of its own yet. Plan: a PR into claude/kaiju-motion-species once the lead OKs the clips.
- Key commits: 4f98a07 rigs + tools/capture/bone_sheet.py; 6aa486f mantis gait + motion_report.py;
  324d14a octopus gait; 7b7759b mantis mandibles; pose-trace lives in tools/capture/pose_trace.gd.

## Unfinished changes
- None uncommitted. All suites pass locally (smoke 13, sim 39, powers 24, tentacles 17,
  city 5, flow 26).

## File split (agreed with kaiju-motion)
Mine: scenes/gait_hexapod.gd, hexapod_upper.gd, gait_radial.gd, cephalopod_stand_in.gd,
assets/kaiju/insectoid_*, cephalopod_*, radial/hexapod parts of tools/blender/rig_voxel.py.
Theirs: biped files, kaiju_rig.gd / kaiju_gait.gd / kaiju_model.gd core, kaiju_grip.gd.
Shared: capture_motion.gd, rig_voxel.py main().

## Measured (motion_report.py on --pose-trace, headless 60 fps)
- Mantis holds 0.08-0.45 s, irregular (cv ~0.3); body travel during a hold 0.0000; darts ~23 u/s.
- Mantis body turn 0.28 s adult / 0.20 s baby; a foot is in the air before the body turns.
- Mantis rest: twitch onsets every 0.03-0.17 s; longest still 0.13 s. Roar rears the body and
  flares the scythes and mandibles.
- Octopus grips every 0.6-0.9 s adult / 0.38-0.52 s baby; the straight walk uses 3 arms in turn.
  Body 0.9-1.1 u/s just before a grip, 6-11 u/s just after.
- Rigs (bone_sheet.py): octopus fragments, slate islands and unchained long runs all 0 (the lead
  PASSED octo_bone_sheet_r3); mantis fragments 0. Tentacles 10/7/13; max bones 79 (adult octopus).

## Evidence locations
side-session-notes/local_9fac90d2.../species-motion/: octo_bone_sheet_r3.png (+ _before),
mantis_bone_sheet_r3.png, mantis_r3a/ (first mantis clips, older twitch amplitudes, numbers.txt).

## Running jobs
- CI capture runs 38923718118 (mantis adult side), 38923730820 (mantis adult game),
  38923742801 (octopus adult side), 38923755282 (octopus baby game), dispatched with
  --ref claude/species-motion. A background watcher downloads each to scratchpad/ci/<run id>.
  If the session is gone: gh run download <id>.

## Attempts (fix-loop record)
- Octopus ownership: thickness test from the chain -> slate mid-tentacle. Region grow from seeds
  fixed it, but tentacles then grew over the head; a tapered growth bound plus lowering the tip
  path's core plus dropping chains lying high root-to-tip fixed it. The missed-arm detector needs
  "tip out past the mantle" or it chains head shells.
- Mantis holds drifted using the smoothed velocity; anchoring the hold to the world point fixed it.
- The body turn was 1.7 s while it held its yaw; a constant-rate swing gated on a leg being in the
  air gave 0.2-0.35 s.

## Open decisions
- None waiting on the director.

## Next
1. Check the CI clips (80x150 readability, framing, the roar), then send round 3b to the lead.
2. Octopus building-edge grips are not yet shown in a city capture; the octopus turn takes 0.7-1.0 s.
3. kaiju-look-test (D-041 voxel skin) bakes from my rigs: tell it after any rig change, and it
   needs the _mantle scale mirrored.

## Rules learnt
- focus-guard blocks ALL windowed Godot while the director plays fullscreen: use the CI capture.
- capture_motion steps 1/60 s per frame: record at --fixed-fps 60, never 30 (plays at half speed).
- A local movie writes 1920x1080 whatever --resolution says.
- Static typing: float(Variant) is an error; use PackedFloat32Array or typed dicts. Never name a
  helper _set (Object has one).
