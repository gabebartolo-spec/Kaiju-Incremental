# Kaiju voxel skin (was: look test) handoff, 2026-10-17 03:50
## State: running a check (PR #15 open, Auto-fix on; 12 CI capture runs for its evidence)

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
merge #11 first, then look-options, or #10's squash conflicts. Head 4efc470. All 9 skins rebaked
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

## Running jobs
CI captures on 63b2234 (ids in scratch ci_runs2.txt): reptilian rigid clip 38934348115 / stills
38934357962, skin 38934366730 / 38934377957; insectoid rigid 38934388712 / 38934398600, skin
38934408909 / 38934418490; cephalopod rigid 38934427444 / 38934435081, skin 38934447283 /
38934457743. Rigid clips are slowest (~1 h, lavapipe). Then: gh run download each into
scratch dl/<sp>/<v>_<clip|stills>/, run scratch py/compose_pr.py, post clips/crops on PR #15
(upload to the notes folder + a PR comment), fill the Evidence section, send the lead.

## Open decisions / touch points
Messages sent to kaiju-motion and species-motion (02:00): no edits to their files; they or I rerun
bake_all.sh after rig changes; asked kaiju-motion whether the bent arms are rest or gait pose. No
replies yet.

## Rules learnt the hard way
- Never wrap windowed Godot in a script: the focus guard must see the command. Use CI captures.
- gh workflow run prints the run URL; a "newest run after" poll can pick another session's dispatch.
- A fresh worktree has LFS fonts as pointers: flow then floods font errors and times out. git lfs pull.
- APPDATA override for Godot hides Python user site-packages (PIL): set per command.
- Godot front faces are clockwise; Tripo textures are packed JPEGs; Blender heat weights fail on Tripo.
