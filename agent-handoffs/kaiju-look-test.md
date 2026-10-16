# Kaiju look test handoff, 2026-10-17 01:06
## State: available (results sent to the lead; awaiting their verdict)

## Task
Director (2026-10-17): "its looking very rough so far, would this work better if our kaiju werent
voxel?" Picked a side-by-side test: the same reptile adult, same walk/turn/roar, same city, at the
gameplay camera and a side camera, three ways: A current voxel-per-bone rig, B smooth skinned Tripo
mesh, C voxel look on a smooth skin. Deliver: one labelled clip, 2x hip/knee crops, a cost/risk note.
Results go to the lead (local_9fac90d2-fae7-4940-b4ac-144a87f28e6e), not the director. Throwaway
branch: no PR unless asked.

## Branch and commit
claude/kaiju-look-test-a763a6, cut from claude/look-options 72cb249 with origin/claude/kaiju-motion
(b7b699e, PR #10 round 4 rig) merged in, so all panels use the newest pushed locomotion. Nothing of
kaiju-motion's files edited.

## Files (all in tools/look_test/)
- export_skin.py: `blender -b --python tools/look_test/export_skin.py -- <glb> assets/kaiju/reptilian_adult <out>`
  writes skin.kmesh (B: Tripo mesh in rig space, weights), skin_albedo.jpg, voxel.kmesh (C).
- kaiju_skin.gd: the adapter. Hides KaijuRig's voxels, builds a Skeleton3D with one bone per rig
  bone, copies each bone node's rig-relative transform into it every frame (sync()). Bind = rest head.
- look_test.gd: capture driver (capture_motion.gd's script), --variant=A|B|C|N --cam=game|side.
- compose.py: ffmpeg side-by-side + joint crops (needs default APPDATA for PIL: user site-packages).

## How B and C are weighted
A's own bone split (the kvox flags byte), smoothed 12 passes over the voxel lattice, blending only
bones that form a joint (same/parent/child) so thigh-against-tail stays separate. B samples that
field at each mesh vertex (2-voxel gaussian, bones related to the nearest voxel's). C = every
exposed cube face of A's voxels; each cube corner is a lattice point averaging its related cells, so
neighbouring cubes share corners and never part (watertight), GPU-skinned with the same skeleton.

## Attempts (fix-loop record)
- B smoothing along Tripo mesh edges: low-poly mesh -> ~30-voxel blend, candy-wrapper legs. Replaced
  by sampling the lattice field.
- B inside-out: the x flip to game axes mirrors the mesh; triangles reversed in export.
- C smeared strips: lattice glued thigh to tail where they touch in bind pose -> joint-related only.
- Joint-distance gate on blending: tore where ownership boundaries sit far from the joint. Reverted.
- Blender automatic (heat) weights: failed for every bone, on the raw mesh and on a watertight voxel
  remesh proxy. Two failures -> stopped (rule 8). Tripo auto-rig is the production route for B.

## Rules learnt the hard way
- Setting APPDATA for Godot isolation also hides Python's user site-packages (PIL): set it per command.
- Tripo GLB textures are packed JPEGs: write the packed bytes as .jpg, never "save as png".
- Godot front faces are clockwise; mirrored glTF triangles must be reversed.

## Results
Deliverables + NOTE.md (costs, defects, what C needs, risks) in the shared notes folder
side-session-notes/local_9fac90d2-.../kaiju-look-test/. Defects found: B shoulder spikes stretch into
a sheet; C cubes shear into slabs on the front of a bent knee. Cost over no-kaiju: A +0.43 ms GPU,
B ~0, C +0.24 ms; adapter CPU in the noise.

## Next (if the lead wants C pursued)
Fix C's knee shear (rigid per-cube transform from blended centre, or subdivide stretched faces); try
B with a Tripo auto-rig. Generated meshes live in scratch only (regenerate with export_skin.py).

## Running jobs
None. override.cfg removed.
