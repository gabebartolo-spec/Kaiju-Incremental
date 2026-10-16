# Kaiju voxel skin (was: look test) handoff, 2026-10-17 02:45
## State: running a check (12 CI capture runs for the PR evidence; full test suite)

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
claude/kaiju-voxel-skin (pushed), cut from origin/claude/kaiju-motion-species (PR #11, stacked on
#10) + origin/claude/look-options merged in. Head 877ed7e. No PR yet. This worktree is
.claude/worktrees/kaiju-look-test-a763a6 (switched branch).

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
- KaijuModel: static show_rigid_voxels ("--kaiju-rigid" user arg) = A; else VoxelSkin.load_for + sync.
- tests/run_smoke_tests.gd: +_check_skins_fresh, +_check_voxel_skin (default skin for all three,
  no rig voxels drawn, finite pose, mouth shows on held jaw, flag = no skin). Floor smoke 13 -> 19.
  The stale check was shown failing (appended a byte to insectoid_baby.rig.json).
- tools/capture/capture_skin.gd: --find (most-bent near-side joints) / stills + bone pixels.
- export_presets include_filter "*.kvox, *.vskin" (kvox was never exported: pre-existing gap).
  .gitattributes: *.kvox, *.vskin binary.

## Evidence so far
- smoke 19/19 locally; gdlint/gdformat clean on changed files.
- Local side stills (before the director's fullscreen game blocked windowed Godot): reptile arms
  bent and lowered, no shoulder sheet; mantis fine; octopus mantle blotches are in the .kvox (same in
  A's old clip).
- Most-bent joints: reptile leg_r1@572 leg_r0@574 (+jaw@677); mantis arm_r1@216 head0@730
  arm_r2@632; octopus tentacle5_0@418 tentacle8_5@658 tentacle5_4@701.

## Running jobs
CI capture runs (scratch ci_runs.txt): reptilian rigid clip 38923658204 / stills 38923677785, skin
clip 38923695073 / stills 38923713484; insectoid rigid 38923732976 / 38923752364, skin 38923771628 /
38923789957; cephalopod rigid 38923807867 / 38923825633, skin 38923842735 / 38923860421.
Download: gh run download <id> -D <dir>. Then compose before|after per species + crops, open PR.
override.cfg is in the worktree root (untracked): delete before ending.

## Open decisions / touch points
Messages sent to kaiju-motion and species-motion (02:00): no edits to their files; they or I rerun
bake_all.sh after rig changes; asked kaiju-motion whether the bent arms are rest or gait pose. No
replies yet.

## Rules learnt the hard way
- Never wrap windowed Godot in a script: the focus guard must see the command. Use CI captures.
- gh workflow run prints the run URL; a "newest run after" poll can pick another session's dispatch.
- APPDATA override for Godot hides Python user site-packages (PIL): set per command.
- Godot front faces are clockwise; Tripo textures are packed JPEGs; Blender heat weights fail on Tripo.
