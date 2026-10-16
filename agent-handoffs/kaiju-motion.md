# Kaiju-motion handoff, 2026-10-17 08:00 (final)
## State: available (reptile done and merged; only duty left: keep PR #11 in sync and CI green)

## Task
D-031: species-true kaiju locomotion. This role is REPTILE only (lead split, 2026-10-17).
species-motion (local_87c25bd4) owns the mantis and octopus: hexapod/radial gaits, their assets
and their parts of rig_voxel.py. Presentation only; the sim decides nothing from any of this.

## Branch and commit
- claude/kaiju-motion -> PR #10 (reptile): MERGED into claude/look-options (squash aaa60f7).
  The branch can be deleted by the lead. Force-push is denied: merge, never rebase.
- claude/kaiju-motion-species -> PR #11, base claude/look-options. Holds #10 plus the species
  work; fast-forwarded to claude/species-motion 3e41996 (mantis/octopus round 3) on 2026-10-17.
  Lint, smoke 13, sim 39, powers 24, tentacles 17, city 5 green locally; slide 0.0 cm x3.
- Keeping #11 in sync: merge origin/claude/look-options in. After a squash-merge of a PR this
  branch already holds, conflicts resolve to ours (verify look-options == that branch first).
  species-motion merges into claude/species-motion; fast-forward #11 to it when it asks.

## Unfinished changes
- none uncommitted.

## What the reptile ended with (all merged in #10)
- Shoulders locked to the line of travel: spine1 = exact inverse of the pelvis yaw/roll/sway
  (keeps lean, drop, surge); SWAY 0.03, HIP_YAW 0.06. capture_motion prints SHOULDERS
  drift/tilt/yaw (adult 0.00% drift; a constant -3.95 deg yaw is the sculpt's asymmetry).
- Arms: posed, never simulated. Hang, ~60 deg elbow, hands resting in front of the belly
  (director's pick). Also the KaijuRig rest pose for bipeds (BipedSwing.rest_arm_bases), so the
  D-041 skin binds to it. Stride swing +-0.14 rad, turn brace <= 0.2 rad, raised only to roar.
- Jaw baked into the voxels at rest (rig_voxel.close_jaw): baby/adolescent shut (hairline,
  no throat gap); adult a tight snarl in true colours (director's pick B; rig arg 0.35,
  rig.json "snarl": true). Director REJECTED skin-coloured mouth insides.
- rig_voxel: reclaim_plates (shoulder plates and inboard shoulder on the spine), no chest
  joint band on arm roots, clean_blemishes (the adult's chest "nips": 4 voxels).
- Gait: decisive stop (a step in flight never slows), roar waits for a swinging foot,
  stomp steps replace settle steps, baby camera-dip floor.
- Rig commands (copy each GLB to its own scratch folder first; blender -b only):
  blender -b --python tools/blender/rig_voxel.py -- <rep_<stage>_tex_olive.glb copy>
    assets/kaiju/reptilian_<stage> reptilian <100|130|160> [0.35 for the adult]
  GLBs: ~/Downloads/kaiju_tripo/rep_{baby,adol,adult}_tex_olive.glb.
- D-041 skins (kaiju-look-test, PR #15) bind to the .kvox, .rig.json and rest pose. After any reptile
  re-rig or rest-pose code change, run GODOT=<godot> bash tools/kaiju_skin/bake_all.sh (about a minute)
  or ping kaiju-look-test. Its smoke test catches .kvox/.rig.json drift, not rest-pose code.

## Attempts (fix-loop record)
- Posing arm bones by rotating about their own x rolled them (claws floated): aim joints instead.
- Floating shoulder shards: per-bone --tint capture found the joint band of chest on the arm.
- A jaw turned shut every frame opened a throat gap the inset filler showed as a lattice: bake it.
- Adult jaw fully shut sank into the skull (dark wedge): director chose a resting snarl.

## Open decisions
- none.

## Running jobs
- none. Remove override.cfg after any capture.

## Findings for the lead (not yet in any learnings log)
- capture_motion --tint (each bone a flat colour) found rig faults frame steps could not.
- Exporting APPDATA for Godot hides Python's user site-packages (cv2): unset it for Python.
- Merging a base with a duplicate of your work (squash): diff base vs your old branch first.

## Rules learnt the hard way (under 10 lines)
- Windowed Godot steals focus from the director's fullscreen games; focus-guard blocks it.
  Use headless runs and CI captures (tools/capture/ci_capture.sh --movie ...).
- Never edit .gd while a local suite/capture runs; after switching branches run --import.
- gdlint: 400 lines/file, <=4 args, 20 public methods; check after every merge (caps break).
- Kill only Godot PIDs you started.
