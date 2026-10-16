# Kaiju look test handoff, 2026-10-17 01:47
## State: available (round 2 sent to the lead; awaiting verdict)

## Task
Director (2026-10-17): "would this work better if our kaiju werent voxel?" Side-by-side test, same
reptile adult, same walk/turn/roar, same city, gameplay + side camera: A current voxel-per-bone rig,
B smooth skinned Tripo mesh, C voxel look on a smooth skin. Results go to the lead
(local_9fac90d2-fae7-4940-b4ac-144a87f28e6e), not the director. Throwaway branch, no PR.
Round 2 (lead, 01:23): fix C's knee shear (rigid cubes); B on Tripo's auto-rig; 2x knee, hip, jaw
crops at the most-bent frame; re-render A|B|C. Arms "outstretched like a zombie" is kaiju-motion's,
not ours, and must not decide the pick.

## Branch and commit
claude/kaiju-look-test-a763a6 (from look-options 72cb249 + origin/claude/kaiju-motion b7b699e merged,
unedited). Round 1 = 38d38d1.

## Files (tools/look_test/)
- export_skin.py: `blender -b --python ... -- <tex glb> assets/kaiju/reptilian_adult <out> [--tripo_rig=<rigged glb>]`
  -> skin.kmesh (lattice weights), skin_tripo.kmesh (Tripo rig weights), voxel.kmesh (round 1 C),
  voxel_rigid.kmesh (round 2 C, KMS2 with cube centres), voxel_fill.kmesh (inset lattice filler).
- kaiju_skin.gd: adapter. Modes skin/voxel (Skeleton3D, GPU skin) and rigid (uploads 27 skin
  matrices to voxel_rigid.gdshader each frame).
- voxel_rigid.gdshader: cube centre from the blended skin; rotation = main bone's (snap_turn=1);
  cube grows by gap_fill x bone disagreement (zero at rest).
- look_test.gd: --variant A|B|C|N, --cam game|side|profile, --skin=, --c_mode=rigid|voxel,
  --still_frames=; prints FIND knee/hip/jaw (most-bent frames: 573, 574, 677).
- compose.py <clips> <stills> <out> <ffmpeg> <knee> <hip> <jaw> (default APPDATA, for PIL).

## Round 2 findings so far
- C rigid cubes alone: no slabs, but the outer side of a full knee bend tumbles or opens gaps (tried
  blended turn gap_fill 3 and 1.5, snapped turn). Fix that held: rigid cubes on top + round 1's
  watertight lattice inset 0.25 voxel underneath (A's joint-band trick): gaps show skin, not sky.
- Tripo auto-rig = Mixamo humanoid, 65 bones, NO tail, NO jaw. Mapped Hips/Spine*/Neck/Head/legs/arms
  (hands, fingers, toes folded in); tail and jaw keep lattice weights, blended by lattice share.
  Mesh identical to the textured one (0.00 voxel match). Shoulder sheet gone; thigh faceted at full bend.

## Rules learnt the hard way
- APPDATA override for Godot hides Python user site-packages (PIL): set per command.
- Tripo GLB textures are packed JPEGs. Godot front faces are clockwise; mirrored glTF must flip.
- Write override.cfg in its own command before a windowed Godot call (focus-guard checks first).
- Blender heat weights fail on Tripo meshes, even remeshed.

## Results
Round 2 deliverables + NOTE.md in side-session-notes/<lead>/kaiju-look-test/round2/. Remaining
defects: C filler sheet over the shoulder in the roar, filler patches at the bent knee; B hip folds at
full flex, faceted knee. Cost over empty city: A +0.46 ms, B +0.07, C +0.43.

## Running jobs
None. override.cfg removed. Meshes in scratch only (regenerate with export_skin.py).
