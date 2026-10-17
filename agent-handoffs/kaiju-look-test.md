# Kaiju voxel skin (was: look test) handoff, 2026-10-17 16:10
## State: paused (lead: no more work on the old reptile; resume when the lead sends the croc titan swap)

## Task
D-041: every kaiju draws as voxel cubes on a smooth skin (VoxelSkin). PR #15 is MERGED into
claude/look-options (squash 7ff1f03 of 2290d50). Follow-up PR #19 (claude/kaiju-skin-weights, base
claude/look-options): the bake can take a hand-made Blender rig's weights. Lead (15:50): retarget
#19, let its CI run, then STOP. The director: don't spend usage on models we won't use. The current
Tripo reptile adult is replaced by the D-046 croc titan; no captures, tuning or tests on the old
reptile; don't touch the mantis or octopus skins. Lead = local_9fac90d2-fae7-4940-b4ac-144a87f28e6e.

## Branch and commit
claude/kaiju-skin-weights, PR #19 into claude/look-options, merge 9f952ea. look-options merged in
after #15's squash: conflicts in voxel_skin.gd, bake.py, reptilian_adult.vskin and this file
resolved to this branch's versions (look-options held exactly 2290d50's, so the branch is #15 + the
weights change). Local suites green (smoke 23, sim 39, powers 24, tentacles 17, city 5, flow 26),
gdlint clean. Worktree: .claude/worktrees/kaiju-look-test-a763a6. The session's PR monitor is bound
to #15.

## What exists (merged in #15)
- tools/kaiju_skin/bake_all.sh (GODOT=<godot> bash ...): dump_rest.gd (each rig's rest pose as the
  game builds it) -> bake.py -> assets/kaiju/<name>.vskin (gzip). Stamp = sha256 of .kvox + .rig.json
  (+ Blender skin files in #19); smoke fails a stale skin.
- scenes/voxel_skin.gd (VoxelSkin): MultiMesh cubes (centre in the instance transform,
  INSTANCE_CUSTOM small ints: compatibility renderer keeps it at half precision) + filler mesh.
  Debug flag VoxelSkin.show_rigid_voxels ("--kaiju-rigid") = the old rigid voxels.
- voxel_skin.gdshader: cube centre from the blended bones, rotation = main bone's (scale stripped),
  one size. voxel_skin_fill.gdshader: linear skin, faceted normals.
- Bake rules: lattice-smoothed .kvox split (12 passes, joint-related bones only); HINGES (jaw,
  mandible_l/r) never blend; arms baked into the rig's lowered rest pose.
- tools/capture/capture_skin.gd: --find (most-bent joints), stills (--frames), clips
  (--clip=game|close --from --to, draws every 2nd frame for CI).

## PR #19 (Blender weights)
assets/kaiju/skin_weights.json {kaiju: path to .skin.json}. bake.py blender_weights(): 4 nearest
welded positions (inverse distance) via kvox_cell_to_skin, bones summed per "game" name, jaw voxels
all jaw. Tested on blender-reptile's test rig (2aa4b6c) for reptilian_adult: knee seam gone,
forearm pinholes mostly gone (evidence: side-session-notes/<lead>/kaiju-voxel-skin/blender-weights/).
Reptile filler 50k -> 111k vertices. Export format (blender-reptile): KSKW, u32 version, u32 N,
u16 bones, 32-byte records from byte 14 {f32 xyz, u8 bone[4], f32 weight[4]}; producer:
blender -b --python tools/blender/motion_test.py -- auto <new.glb> <out_dir> export 160.

## Next (when the lead messages the croc titan swap)
Point skin_weights.json at the croc titan's export (and its new .kvox/.rig.json), rerun
bake_all.sh, smoke, CI captures with -f renderer=forward_plus, report. Nothing else until then.

## Accepted limits (in #15's Not exercised)
Lattice weights: a ribbed seam at a full knee bend and hairline pinholes on short limbs; narrowing
the blend (gap + streaks) and shadowless filler (no change) were tried and reverted.

## Rules learnt the hard way
- capture.yml falls back to gl_compatibility after a Forward+ timeout: dispatch with
  -f renderer=forward_plus. Compatibility keeps MultiMesh custom/colour data at half precision.
- Never report on a frame you have not looked at: a black or failed grab is not "no defect".
- Never wrap windowed Godot in a script: the focus guard must see the command.
- gh workflow run prints the run URL; a "newest run after" poll can pick another session's run.
- A squash-merged base makes the stacked branch conflict on the same files: compare blobs to the
  merged SHA, then take the branch's side.
- APPDATA override hides Python user site-packages (PIL); a scratch inspect.py shadows stdlib.
- Fresh worktrees have LFS fonts as pointers: git lfs pull, or flow times out.

## Running jobs
CI on PR #19 (the lead asked to let it run). Nothing else.
