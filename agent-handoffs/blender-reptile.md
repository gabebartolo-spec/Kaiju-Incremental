# blender-reptile handoff, 2026-10-17 13:15
## State: running a check (full A|B renders of walk, turn, roar; then compose, encode, crops)
## Task
Round 1 (done, D-pending): hand-modelled reptile adult A vs Tripo adult B; board sent; director:
Tripo looks better, Blender "promising". Round 2 (lead, 2026-10-17 12:39): MOTION TEST, not sculpting.
One hand-built armature fitted to BOTH meshes, hand-set weights with clean falloff; key a walk (D-031),
a 90 deg turn and a roar with the jaw; render A|B side and three-quarter ~6 s, foot slide in cm per
plant, 2x crops of shoulders/hips/jaw at their most bent frames. Question: bad motion = Tripo mesh or
our auto rig/weights? CI is billing-blocked: render locally (blender -b), commit, no CI dispatch.
## Branch and commit
claude/blender-reptile-f5388e; round 1 at 4a1b1f8/edf5b60; round 2 rig script at cb56749 (pushed). Clips not committed yet.
## Unfinished changes
- tools/blender/motion_test.py (new): `blender -b --python tools/blender/motion_test.py -- <A|B> <glb>
  <out> <render|measure|crops|blend|still> [clip]` - ONE clip per process (see Attempts).
  Normalises to 100 m, re-origins on the pelvis ground point, builds the rig from LANDMARKS (pivots
  measured on each mesh: gridded ortho renders + vertex slices), IK legs (thigh-shin-meta to a foot
  ctrl at the ball, knee pole, toe copies ctrl) and IK arms (hand target on the chest low in front of
  the belly, elbow pole), weights = nearest bone in region (side, jaw mask) + linear 50/50 falloff over
  40% of the shorter bone at each joint + 6 surface smoothing passes + loose islands rigid to the hide.
  Keys are baked per frame: root path (walk straight / smooth 90 deg turn), pelvis bob/sway/yaw,
  spine/neck counter, tail wave, feet world-planted through stance, roar crouch-rear-hold-recover.
- Scratch (not committed): scratchpad/mt/{r,meas,crops,compose.py,encode.py}; B.glb copy.
## Evidence so far
- Foot slide on deformed toe pads, max per clip: A walk 8.0 / turn 10.8 / roar 1.1 cm;
  B walk 5.5 / turn 19.1 / roar 4.3 cm (100 m kaiju). B's right foot rests 69 cm off the ground in
  the Tripo sculpt itself (left at 0) - mesh, not rig.
## Attempts (fix-loop record)
- Rig origin at the snout put planted feet 60 m ahead: re-origin on the pelvis.
- Foot targets used rig.matrix_world (last frame): one-frame (84 cm) offset; build the matrix per frame.
- Keying a 2nd clip in one process left frame 0 posed from the old one: one clip per process + settle().
- FK arm angles gave different hands on A and B (different rest forearms): IK hand targets instead.
- Roar tail pitch sign pushed B's tail into the ground (looked detached): + pitch lifts a tail bone.
- B jaw mask reached the throat: floor line under the mouth, only in front of the hinge.
## Open decisions
Lead/director read of the clips: does B move well on the hand rig?
## Running jobs
Background render chain (bash task b1y3qhaxe): render walk/turn/roar x A/B, then crops walk/roar.
## Findings for the lead
- Same rig and keys on both meshes: plants hold to <20 cm on both, so foot sliding is not a mesh issue.
## Rules learnt the hard way
- Blender IK is history-dependent: evaluate a frame twice after any jump.
