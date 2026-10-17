# Kaiju voxel skin (was: look test) handoff, 2026-10-17 15:20
## State: running a check (PR #15 CI on the merged head; then send the lead the SHA to merge)

## Task
D-041 (director picked C): every kaiju draws as voxel cubes on a smooth skin. Lead's brief (01:50):
1 bake the arm rest pose lowered (no runtime stretch); 2 bone array covers the hydra (79) and
hexapod; 3 one-command export for all 9 kaiju, bone splits from the current .kvox (kaiju-motion owns
the reptile, species-motion the mantis and octopus; re-export when their rigs change); 4 KaijuModel
uses C by default, A behind a debug flag, gameplay hooks keep working; 5 PR into claude/look-options
with before/after game-cam clips for all three species + 2x joint crops, CI green. Lead =
local_9fac90d2-fae7-4940-b4ac-144a87f28e6e. The look test (rounds 1-2) is done: branch
claude/kaiju-look-test-a763a6 (0d00544), notes in side-session-notes/<lead>/kaiju-look-test/.

## Branch and commit
claude/kaiju-voxel-skin, PR #15 into claude/look-options (open, Auto-fix on). Synced with #11's
latest (kaiju-motion-species, which holds #10) and look-options (#10 merged there as aaa60f7):
merge #11 first, then look-options, or #10's squash conflicts. Head 6dfa6b3 (snarl mouth, mantle + mouth smoke checks; smoke floor 20). All 9 skins rebaked
after the sync (bone counts changed). This worktree is .claude/worktrees/kaiju-look-test-a763a6.

## What exists
- tools/kaiju_skin/bake_all.sh (GODOT=... bash ...): dump_rest.gd (Godot headless: every rig's rest
  pose as the game builds it) -> bake.py (numpy) -> assets/kaiju/<name>.vskin (gzip, ~0.4-2.2 MB each,
  8.8 MB total). Turned bones (lowered arms) are supersampled so the turned shell has no pinholes.
  Header carries a source stamp (sha256 of .kvox + .rig.json); smoke fails on a stale skin.
- scenes/voxel_skin.gd (VoxelSkin): MultiMesh cubes (INSTANCE_CUSTOM packs cell, mouth flag, 3 bones,
  2 weights as exact floats) + filler ArrayMesh (joint faces, inset 0.3, CUSTOM0/1 weights). sync()
  uploads up to 128 bone matrices; uses rig.skins[bone] transform when a gait scales a skin (octopus
  mantle). Rig voxel MMIs -> layers 0 (gait toggles still run). Mouth inside/seam from the jaw pose.
- scenes/voxel_skin.gdshader (rigid cubes: blended centre, main bone's turn, gap_fill grow),
  scenes/voxel_skin_fill.gdshader (linear skin, derivative normals).
- KaijuModel: 4 lines (VoxelSkin.attach / sync_if). Debug flag VoxelSkin.show_rigid_voxels
  ("--kaiju-rigid" user arg) = A. kaiju_model.gd sits at the 400-line gdlint cap.
- tests/run_smoke_tests.gd: +_check_skins_fresh, +_check_voxel_skin (default skin for all three,
  no rig voxels drawn, finite pose, mouth shows on held jaw, flag = no skin). Floor smoke 13 -> 19.
  The stale check was shown failing (appended a byte to insectoid_baby.rig.json).
- tools/capture/capture_skin.gd: --find (most-bent near-side joints) / stills + bone pixels.
- export_presets include_filter "*.kvox, *.vskin" (kvox was never exported: pre-existing gap).
  .gitattributes: *.kvox, *.vskin binary.

## Evidence so far
- Local, head 63b2234: smoke 19, sim 39, powers 24, tentacles 17, city 5, flow 26 all pass.
  Stale-skin check shown failing first. gdlint/gdformat clean repo-wide.
- Joints (capture_skin --find, new rigs): reptile leg_r1@572 leg_r0@574 jaw@676; mantis arm_r1@131
  arm_r2@403 leg_r1@726; octopus tentacle6_2@635 tentacle1_0@656 tentacle11_5@869.
- Earlier (old head) CI stills: mantis A sheds floating shards at arm_r2, C stays whole.

## Lead review of #15 (12:55): FIX
1 mantis C clip shattered; 2 its fog differs; 3 reptile thigh smeared at f572; 4 reptile jaw a loose
scatter at f676; 5 add a close 3/4 camera (2x game zoom) on the sharp turn + roar. Octopus skipped,
no gait edits (D-044 locomotion paused), capture on CI (repo public, CI back).
Cause of 1+2: CI's forward_plus run hit the 50-min timeout and capture.yml fell back to
gl_compatibility, which keeps MultiMesh custom data at half precision: my packed floats (to ~2M)
scrambled bones/cells. Fixed in 5f807cb: centre in the instance transform, INSTANCE_CUSTOM =
small ints (b0+128*mouth, b1, b2, w0), w1 in colour alpha, uniform to_skin. 3: max_grow 0.15 +
filler shaded with normals snapped to its main bone's axes. 4: bake HINGES (jaw, mandible_l/r)
never blend with the parent. 5: capture_skin.gd --clip=game|close --from --to (draws every 2nd
frame; dispatch with -f renderer=forward_plus so CI never silently falls back).

## Review round 2 (lead 14:22, FIX): sheared cubes
Mantis scythe slats (close f335, joints f403), reptile thigh ribbed ramp (f572/574), reptile
forearm speckle (close f220). Fixes: 8f5a798 cube turn = main bone's rotation only (scale stripped),
growth off (max_grow 0): changed ~0.05% of pixels, so scale was not the cause; f790f6a narrower
joint blend (LATTICE_PASSES 12 -> 4), all rebaked. New head f790f6a: the scythe at f335 already
read as a clean cube grid on 8f5a798 (A sheds shards there).

## Review r2 outcome (head 4be3650 = 8f5a798 behaviour)
- Scythe slats: fixed (main-bone rotation only, no growth). Evidence review-r2/scythe_zoom.png.
- Thigh band at full knee flex: remains (mild ribbing). The clamp (LATTICE_PASSES 4, f790f6a) opened
  a gap with streaked filler: worse, reverted (4be3650). Two failed attempts: stop (rule 8).
- Forearm speckle at close f220: REAL (hairline gaps between cubes turned by different bones). I
  first told the lead "no speckle" without looking (black frame grab): corrected 15:10.
- Options sent: (a) accept until Blender weights [recommended], (b) 5-8% uniform overscale,
  (c) blended turn (brings shear back).

## Running jobs
PR #15 CI on the head after this commit. Lead accepted round 3 (thigh seam accepted, in Not
exercised). Merged look-options (tank #17): conflicts in run_smoke_tests (kept both: skin + tank
checks), rampage.gd (kept FOCUS_FOLLOW, dropped unused TANK_GREEN), floors (smoke 23). rampage.gd
hit 409 lines: TankModel.box now holds the shell box helper. Lead merges exactly the SHA I send.

## Next (lead, 14:55)
Separate small PR: Blender-weights input for the bake. Optional per-kaiju weights file (per
voxel, sampled from the source mesh's vertex weights), part of the stale stamp, hinge rule kept.
Build and test against blender-reptile's current test rig (branch claude/blender-reptile-f5388e,
tools/blender/motion_test.py) exported as a weights file; the real source will be the hand rig on
the D-045 Tripo reptile.

## Open decisions / touch points
Agreed with kaiju-motion: rest pose = standing arms (5c6e703, director's lower T-rex hang); reptile
adult rests in a snarl (bone_snarl.jaw: mouth shows true colours at rest). Agreed with
species-motion: mantle scale reads rig.skins["mantle0"] (smoke-proven); their rigs regrown
(octopus 61/43/79 bones, mantis 32). Both rerun bake_all.sh after rig changes, or ping.

## Rules learnt the hard way
- Never wrap windowed Godot in a script: the focus guard must see the command. Use CI captures.
- gh workflow run prints the run URL; a "newest run after" poll can pick another session's dispatch.
- CI capture.yml falls back to gl_compatibility after a Forward+ timeout: always dispatch with
  -f renderer=forward_plus. Compatibility keeps MultiMesh custom/colour at half precision.
- Never report on a frame you have not looked at: a black or failed grab is not "no defect".
- A scratch file named inspect.py shadows Python's stdlib for scripts in that folder.
- A fresh worktree has LFS fonts as pointers: flow then floods font errors and times out. git lfs pull.
- APPDATA override for Godot hides Python user site-packages (PIL): set per command.
- Godot front faces are clockwise; Tripo textures are packed JPEGs; Blender heat weights fail on Tripo.
