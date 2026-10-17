# Kaiju voxel skin (was: look test) handoff, 2026-10-17 17:20
## State: awaiting lead (croc titan #19 evidence sent; don't merge; auto-fix off)

## Task
D-041 voxel skin is merged (#15, squash 7ff1f03). PR #19 (claude/kaiju-skin-weights -> claude/look-
options): the bake takes a hand-made Blender rig's weights. Lead 16:30: swap in the D-046 croc titan
as the reptilian adult (Tripo 351ad916, GLB ~/Downloads/kaiju_tripo/rep_croctitan_adult.glb, never
commit it) with blender-reptile's skin export (3ea955d); jaw a rigid hinge, clean mouth split;
evidence = game camera clip + 2x crops (hips, knees, shoulders, jaw, tail; walk + roar), before (old
auto rig) vs after (Blender weights), same seed. Send stills, clip, head SHA to the lead. Don't merge.
Auto-fix OFF. Baby/adolescent unchanged. Lead = local_9fac90d2-fae7-4940-b4ac-144a87f28e6e.

## Branch and commits
claude/kaiju-skin-weights: 8d6f8e7 = BEFORE (croc titan on rig_voxel's auto rig, lattice weights,
plus the new tools); 5182944 = AFTER; 73d84a1 = shoulder-hole fix (head). Local suites green on both (smoke 23 on before; all six
on after: smoke 23, sim 39, powers 24, tentacles 17, city 5, flow 26). gdlint/gdformat clean.

## How the croc titan is built (one-off asset steps, scratch GLB copy)
1. blender -b --python tools/blender/rig_voxel.py -- <glb> <out>/reptilian_adult reptilian 160 0
   (jaw arg 0: the croc's mouth is shut; rig_voxel's upright-biped skeleton is wrong for this body,
   so only its voxels and colours are kept)
2. blender -b --python tools/kaiju_skin/skin_faces.py -- <glb> assets/kaiju/test/croctitan.skin.json
   -> croctitan.skinf (10,721 welded triangles; every GLB point lands on a welded position, 0.0000 m)
3. python tools/kaiju_skin/rig_from_skin.py assets/kaiju/reptilian_adult.kvox
   assets/kaiju/test/croctitan.skin.json -90.5,82.5,-58,87
   (rig.json from the Blender skeleton; voxel owners = Blender weights' argmax; mouth line = motion_test
   KNOWN["C"] mouth (y 1.5->34 behind the snout, z 82.5->87) re-origined on the pelvis (y 92): skin
   z = y - 92. Straight cut: head1/jaw voxels in front of the gape and under the line are jaw.)
4. GODOT=<godot> bash tools/kaiju_skin/bake_all.sh (only reptilian_adult.vskin changes)

## Sampling finding (lead asked)
4-nearest IDW on this sparse mesh (gap median 1.07 m): >20% unrelated-bone weight on 4.5% of voxels
(old reptile 0.9%). Barycentric on the triangles (bake.sample_skin, used when a .skinf exists): gap
0.20 m, the SAME 4.6%: the leg/tail and leg/spine1 mixing at the hip is in blender-reptile's authored
weights, not the sampler. IDW vs barycentric: argmax differs on 2.4%, weight moved >25% on 1.0%.
Ownership sheets: scratch ct/after_owners.png, after_mouth.png (straight split; nearest-position
split near the line combed the lips, dropped).

## Done since (17:20)
- First after stills showed a see-through hole on top of the shoulder: bake posed voxels into the
  lowered-arm rest by their main bone only. Fix 73d84a1: Blender-weighted voxels pose by their blend
  (supersampled where a turned bone has weight); side-projection holes 140 -> 2; lattice kaiju
  byte-identical. Recaptured: hole gone.
- PR #19 body/title rewritten for the croc titan (evidence, Not exercised, merge note).
- Evidence in notes kaiju-voxel-skin/croctitan/ (joints_2x.png, full_<f>.png, owner sheets).

## CI captures (Forward+, same seed)
before stills 39007989740, after stills 39008519628 (head 73d84a1); clips 0-20 s game camera 720p:
before 39007991777, after 39008521585. Dispatch with --ref claude/kaiju-skin-weights (main's
capture.yml is older and fails at once). Compose: scratchpad py/compose_ct.py <dl> <out> <ffmpeg>
(dl/{before,after}_{stills,clip}; ffmpeg via imageio_ffmpeg).

## Next
Sent to lead 17:35: stills, clip (notes kaiju-voxel-skin/croctitan/croctitan_game_before_after.mp4,
clip_sheet.png), head SHA. Wait for review. Open findings for others: roar pose (kaiju-motion's
biped head/jaw motion swings the croc's head and jaw down), 204 m body (camera/reach unchecked),
filler 143k vertices, hip leg/tail mixing is in blender-reptile's authored weights.

## Rules learnt the hard way
- Python write_text on Windows writes CRLF; git checks out LF, so a stamped file (rig.json) must be
  written with newline="\n" or CI's smoke sees a stale skin.
- capture.yml falls back to gl_compatibility after a Forward+ timeout: dispatch with
  -f renderer=forward_plus. Compatibility keeps MultiMesh custom/colour data at half precision.
- Never report on a frame you have not looked at: a black or failed grab is not "no defect".
- Never wrap windowed Godot in a script: the focus guard must see the command.
- gh workflow run prints the run URL; use it (other sessions dispatch too).
- A squash-merged base makes the stacked branch conflict: compare blobs to the merged SHA.
- python -I hides user site-packages (numpy, PIL); a scratch inspect.py shadows stdlib.
- Fresh worktrees have LFS fonts as pointers: git lfs pull, or flow times out.

## Running jobs
None (PR #19 CI on push only).
