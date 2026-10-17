# blender-reptile handoff, 2026-10-17 17:05
## State: awaiting lead (croc titan r6 sent)
## Task
History: round 1 hand-modelled reptile A vs Tripo B (board docs/captures/2026-10-17-blender-reptile);
round 2 motion test (one hand rig on both; deformation + feet PASSED by motion-critic; clips in the notes
folder, crops + numbers in docs/captures/2026-10-17-motion-test). Director D-045: a NEW original Tripo
reptile (not A, not B) rigged with this hand rig; its Tripo design waits on the director's Chrome.
Round 3 (lead 14:54): add an export of the rig + welded weights to motion_test.py, agree the format with
kaiju-voxel-skin (local_c9f2ad5f-c2d8-444e-be1e-bc4d838f23cc), test on B, commit; a new mesh must fit in
ONE command. NOT in scope: animation polish (critic notes below), A's design.
## Round 4 (lead 15:47, D-046): the "Croc titan" (Tripo 351ad916 v1, ~/Downloads/kaiju_tripo/
rep_croctitan_adult.glb -> scratch ct/croctitan.glb, never commit). Fit C (KNOWN["C"], measured by
vertex slices: horizontal croc-theropod, pelvis 92 m behind the snout, 42 m skull, feet at +-28 m,
level 112 m tail); auto fit FAILS on this body plan (upright-biped rules) -> hand pivots; fit sheet
checked. Welded 13,097 -> 5,507 positions. Critic fixes in pose_frame: roar wind-up 16-34 with an
8-frame weight drop 26-34, fast rear 34-48, 10-frame peak, slow drift to 60% 58-112, recover 112-140,
tail down and out, claws to the chest with bent elbows; walk weight shift 4.5% hip height, chest drift
+ counter-turn, tail counter-sway in step with the shift; jaw shut at rest. Crops at roar f52.
Lead wants: renders side + 3q, foot slide, girth, 2x crops -> lead runs a fresh critic.
## Round 4 progress (16:30)
- First chain: foot slide walk 4.1 / turn 12.3 / roar 2.3 cm; girth >=90% except elbow 84.5% (roar).
- DEFECT (jaw crop f52): the Tripo mouth is SEALED (lips one skin), so opening the jaw stretched a
  curtain across the gape. Fixes in motion_test.py (KNOWN["C"] only, via a "mouth" landmark):
  mouth line tip (1.5,82.5) -> gape (34,87) read off an ortho head render; jaw_mask uses it; hinge
  (35,84); tooth islands rigid with the jaw their centre sits on; rip_mouth() tears the render mesh
  along the line (faces by centroid, boundary verts duplicated in front of the gape), hard head/jaw
  weights in the mouth zone, backfaces dark. Export keeps welded untorn positions. Head check
  (scratch ct/jc/pair.png): rest clean, f52 jaws part with their own teeth.
- DELIVERED 16:25: clips (walk/turn/roar, side + 3q) + sheets + jaw rest-vs-f52 in notes
  blender-reptile/croctitan/; board + measurements docs/captures/2026-10-17-croctitan/; skin export
  assets/kaiju/test/croctitan.skin.json/.skinw (verify_skin: sums 1, kvox median 1.07 m, p95 2.28).
  Final: foot slide walk 4.1 / turn 12.3 / roar 2.3 cm; girth >=90% except elbow 84.5% (roar peak,
  claws to chest). Roar framing raised (ROAR_FOCUS z60, x1.15) so the reared snout stays in frame.
- Known weak spot: walk shoulder crop on this horizontal body is mostly neck skin.
## Round 5 (lead 16:32, critic FIX; ONE round, say if a fix fights; skin export must stay unchanged)
1 walk seam: T 52->48 (3 cycles in 144) -> seam 4.31 -> 0.45 m (median 0.47). 2 plant snap: swing lift
and toe pitch sin^2, pelvis dip sin^2 over 10 frames after each contact. 3 roar f108-112 hold: linear
drift 56-118 overlapping recovery 104-140, head/tail "look" sweep, breathe x3 at period 72. 4 wind-up
x1.5 (bob + pelvis pitch). 5 tail base lifts in the roar: tip min z 8.8 -> 20.2 m. 6 roar seam 0.22 ->
0.08. 7 turn: tail wave damped 65% over f110-140. New task `diff` (per-frame mean vertex move in rig
space + seam + tail tip z); plot script scratch r5/plot.py (r4 vs r5, r4 diffs from mt_r4.py patched).
DELIVERED 16:42: export byte-identical to 3ea955d (cmp). Foot slide walk 3.4 / turn 11.4 / roar 3.4 cm;
girth unchanged. docs/captures/2026-10-17-croctitan-r5/ (crops, measurements, per_frame_diff.png +
diff/*.json); clips + sheets in notes blender-reptile/croctitan_r5/.
## Round 6 (lead 16:46: roar only; walk/turn pass pending a clean re-encode; skin byte-identical)
1 buzz = the 7 Hz `shake` term on neck0/head/jaw (3.4-frame beat): removed. Snout-tip z acceleration
  has 0 sign flips f48-74. 2 coil: head coil ramp(12,28)/(27,40), pelvis load ramp(22,38)/(37,45),
  drop 0.18 hip_h (8.3 m), pelvis pitch 9, neck0 16 / neck1 10 / head 10 deg. Pose change f28-31 dips
  to 0.80 vs 1.17 (the head's turnaround), then builds smoothly. 3 rear ramp(31,47), fastest f39-41.
  Walk stride D = 140/3: 3 cycles = 140 m = 7 checker PERIODS (Blender checker Scale 600 on 6 km = 10 m
  squares but a 20 m period; 130 m flipped the colours at the seam). Drift eased in from f47 (6-frame
  ease then linear, no cap). DELIVERED: PNG pixel seams walk side 0.92 / 3q 1.35 (medians 1.21 / 1.49),
  roar 0.16 / 0.13; export byte-identical (cmp); docs/captures/2026-10-17-croctitan-r6/; notes croctitan_r6/.
  Encoder: scratch r6/encode_intra.py (gopsize 1, no B-frames, PERC_LOSSLESS; Blender has no -g CLI).
  PNG pixel diff per view: scratch r6/pngdiff.py. diff JSON now carries head_tip + head_accel.
## Branch and commit
claude/blender-reptile-f5388e (pushed). Round 3 at 86adf96; game-name map 2aa4b6c; round 4 script fdcea1a.
## Delivered (round 3)
- motion_test.py fit modes: A | B (hand pivots) | auto (sliced from the mesh) | landmarks.json.
  auto vs hand on B: every pivot within 1-4 m (hand tip 5.3, belly 5.8) on a 100 m body; on A the low
  neck is 7-10 m off (fine for Tripo-like meshes). Rules: torso mid = halfway between 2nd/98th pct of
  a core slice (vertex density is uneven), knee = most forward leg slice, ankle = most backward below
  it, skull base 76% from snout to neck base, arms traced outward, tail bands behind the hips.
- task fit: auto vs hand table + <stem>_fit_side/_front.png (bones over see-through mesh). Look first.
- task export [height_vox]: <stem>.skin.json (33 deform bones, parents first; head/tail/basis rows
  x,y,z + roll_blender in GAME axes: -x, z, y; metres; origin ground under pelvis; 100 m tall;
  physics/jaw flags; kvox_cell_to_skin 4x4 for rig_voxel cells of the SAME glb) + <stem>.skinw
  ("KSKW", u32 ver 1, u32 N, u16 bones, N x 32-byte {f32 xyz, u8 bone[4], f32 w[4]}, welded, sorted,
  sum 1, unused 255/0).
- tools/blender/verify_skin.py <skin.json> <kvox>: sums, parents, size, kvox cells -> skin distance.
- Test export: assets/kaiju/test/reptilian_adult.skin.json/.skinw (B, hand fit; 11,246 positions).
  Verified: sums 1.0, kvox cells of assets/kaiju/reptilian_adult.kvox land median 0.69 m / max 2.4 m
  from the skin (voxel 0.629 m). auto export gives the same counts and distances.
- One command for the new mesh (copy the GLB to scratch, never commit Tripo sources):
  blender -b --python tools/blender/motion_test.py -- auto <new.glb> <out> fit      (check the sheet)
  blender -b --python tools/blender/motion_test.py -- auto <new.glb> <out> export 160
  (then rig_voxel.py on the same GLB at 160 for the kvox). Override bad pivots with a landmarks.json.
## Format agreement
AGREED with kaiju-voxel-skin (15:04): space, welding, .skinw layout OK; added per-bone "game" (today's
KaijuRig name: pelvis->spine0, spine->spine1, chest/clav->spine2, neck0/1->head0, head->head1, jaw,
upperarm/forearm/hand->arm_x0/1/2, thigh/shin->leg_x0/1, meta/toe->leg_x2, tail9 folds into tail8;
_L = blender +x = rig_voxel _l, checked). Their sampler: k-nearest welded positions, IDW, sums per game
bone; jaw never blends with the skull; both files feed their .vskin stale stamp (re-export = rebake).
## Motion-critic notes (lead 13:26; NOT to fix until asked)
Roar: no visible crouch/wind-up, 2 s frozen hold (f60-108), arms go out at the peak. Tail does not
counterbalance (walk, roar); walk upper body static. B mouth open at rest. A: dark armour-scute
patches read as black squares.
## Attempts (fix-loop record)
- Rig origin at the snout put planted feet 60 m ahead: re-origin on the pelvis.
- Foot targets from a stale rig.matrix_world: one-frame (84 cm) offset; build the matrix per frame.
- 2nd clip in one process kept frame 0 of the old one: one clip per process + settle() twice.
- UV-seam splits cracked joints: weld by position before weighting (B 28,691 verts = 11,246 positions).
- Auto spine: centroids sat on the belly (dense folds), then a back cut-off removed the rump surface:
  2/98 pct of the full slice, cut only far tail (foot_y + 40).
- Fit report compared frames wrongly: KNOWN was mutated in place by the re-origin; copy it.
- C jaw: B's gap-search mask split the jaw; mouth line fixed the mask but a sealed mouth still made a
  curtain. Deleting spanning faces showed holes (open shell); tinting them caught cheek faces. Rip +
  hard weights worked.
## Open decisions (lead/director)
None for me; the new Tripo mesh (D-045) is the next input.
## Running jobs
None. No Blender open.
## Findings for the lead
- glTF UV-seam splits crack per-vertex weights unless welded (applies to the game skin path too).
- Blender IK is history-dependent: evaluate a frame twice after any jump.
## Rules learnt the hard way
- Measure on deformed mesh vertices, not bones. Check a skeleton fit on an overlay sheet before use.
