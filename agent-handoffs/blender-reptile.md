# blender-reptile handoff, 2026-10-17 13:24
## State: awaiting lead (motion test clips + crops + numbers sent; verdict is the lead's/director's)
## Task
Round 1 (done): hand-modelled reptile adult A vs Tripo adult B (board in docs/captures/2026-10-17-
blender-reptile). Round 2 (lead 12:39): MOTION TEST - one hand-built armature fitted to both meshes,
hand-set weights, walk (D-031) + 90 deg turn + roar with jaw; A|B side and three-quarter; foot slide per
plant; 2x crops of shoulder/hip/jaw at most-bent frames. Question: bad in-game motion = Tripo mesh or
our auto rig/weights? CI billing-blocked: local blender -b renders, commit, no CI.
## Direction (lead 13:01)
Director prefers A's look ("more original, less a blatant Godzilla copy"): A is the design direction,
B only the motion-test control. Keep A's croc snout, pale dorsal plates, long low tail; never drift
toward Godzilla.
## Branch and commit
claude/blender-reptile-f5388e (pushed). Round 1 4a1b1f8; round 2 script c283dd3; evidence 4ab6781.
## Delivered (round 2)
- tools/blender/motion_test.py: `blender -b --python tools/blender/motion_test.py -- <A|B> <glb> <out>
  <render|measure|volume|crops|blend|still> [clip]`, ONE clip per process. Normalises to 100 m,
  re-origins on the pelvis, rig from per-mesh LANDMARKS (measured pivots), IK legs (thigh-shin-meta to
  a ball ctrl + knee pole, toe copies ctrl), IK arms (hand target low at the belly, elbow pole), weights
  = nearest bone in region + 50/50 linear falloff over 40% of the shorter bone + 6 smoothing passes,
  computed on POSITION-WELDED vertices, loose islands rigid to the hide, palate rides the skull.
- Committed: docs/captures/2026-10-17-motion-test/joint_crops.png + measurements.json.
- Clips (mp4 is gitignored repo-wide, so NOT committed): notes folder
  blender-reptile/motion-test/{walk,turn,roar}_{side,threeq}_AB.mp4 (1284x480, 6 s, 24 fps) with
  compose.py/encode.py; frames re-render from motion_test.py in ~10 min (render task, per clip).
- Numbers (100 m kaiju): foot slide max per plant A walk 8.0 / turn 10.9 / roar 1.1 cm;
  B 6.1 / 22.0 / 4.8 cm. Girth kept at worst frame: A shoulder 95.7, elbow 94.8, neck 95.9, skull 96.3,
  rest >= 99%; B shoulder 91.0, elbow 96.0, rest >= 98%. No tearing/candy-wrap in the crops.
- Verdict offered: B moves cleanly on a hand rig, so the in-game problem is our auto rig/weights
  (rig_voxel: nearest-bone ownership, no joint blend), not the Tripo mesh. B's sculpt has its right
  foot 69 cm off the ground at rest. Shoulders are the weakest joint on both (arms drop ~70 deg).
## Attempts (fix-loop record)
- Rig origin at the snout put planted feet 60 m ahead: re-origin on the pelvis.
- Foot targets used rig.matrix_world (last frame): one-frame (84 cm) offset; build the matrix per frame.
- Keying a 2nd clip in one process left frame 0 posed from the old one: one clip per process + settle().
- FK arm angles gave different hands on A and B: IK hand targets.
- Roar tail pitch sign pushed B's tail into the ground: + pitch lifts a tail bone.
- B jaw mask reached the throat: floor line under the mouth, only in front of the hinge.
- Crack slivers on both at the roar peak: glTF splits UV seams (B 28,691 verts = 11,246 positions);
  weld by position before weighting fixed it. Same fix found A's 540 loose spines/scutes.
- Volume shell radius: base on the nearest surface distance (deep pivots found no vertices).
## Open decisions (lead/director)
1. Port the hand rig + welded falloff weights into the game pipeline (D-041 skinned lattice) for A?
2. Next A refinement round (keep its identity) or straight to in-game motion?
## Running jobs
None. No Blender open.
## Findings for the lead
- UV-seam vertex splits crack any per-vertex weighting unless welded first: check the game's skin
  path (D-041) for the same.
- Blender IK is history-dependent: evaluate a frame twice after any jump.
## Rules learnt the hard way
- Measure on deformed mesh vertices (toe pads, joint shells), not bones: bones hid the seam cracks.
