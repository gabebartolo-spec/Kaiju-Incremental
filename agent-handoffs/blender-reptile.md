# blender-reptile handoff, 2026-10-17 17:25
## State: available (idle by the lead's order: no new work until the director judges the croc titan)
## Task
Blender modelling/rigging/motion for the reptile kaiju. Lead (local_9fac90d2) 17:21: croc titan r7
ACCEPTED. The director board goes to the director together with kaiju-look-test's in-game before/after
(#19: croc titan on Blender weights vs the old rig, same camera and seed). The baby and adolescent wait
on the director's verdict. Do nothing until the lead messages.
## History (one line per round)
1 hand-modelled reptile A vs Tripo B (docs/captures/2026-10-17-blender-reptile). 2 motion test, one hand
rig on A and B (docs/captures/2026-10-17-motion-test). 3 rig + welded-weights export, format agreed
with kaiju-voxel-skin. 4 D-046 croc titan fit + critic fixes + sealed-mouth rip
(docs/captures/2026-10-17-croctitan). 5 timing fixes (-r5). 6 roar buzz/coil/rear + PNG seams (-r6).
7 peak pulse, deeper head dip, director board (-r7). Clips per round in notes blender-reptile/croctitan*/.
## Croc titan state (r7, accepted)
- Source: Tripo 351ad916 v1, ~/Downloads/kaiju_tripo/rep_croctitan_adult.glb (scratch copy; NEVER commit).
- Fit: KNOWN["C"] in tools/blender/motion_test.py (hand-measured; auto fit fails on horizontal bodies),
  incl. a "mouth" tooth line (tip (1.5,82.5) -> gape (34,87)), jaw hinge (35,84).
- Skin export (voxel-skin builds on it; must stay byte-identical): assets/kaiju/test/croctitan.skin.json
  + .skinw (3ea955d). 33 bones, 5,507 welded positions. Checked with cmp after every round since.
- Motion: walk T=48 (3 cycles in 144 frames), stride 140/3 m (= 7 ground-checker periods, loops on PNGs);
  eased contact (sin^2 lift, 10-frame pelvis dip); roar coil (head first, pelvis loads 22-38, drop 8.3 m),
  rear ramp(31,47), pulse f55-73, eased drift from f47, recovery 104-140, breathe period 72; turn tail
  damps over f110-140. No shake/tremor layers (a 7 Hz one buzzed in r4-r5).
- Numbers: foot slide walk 3.6 / turn 11.4 / roar 4.0 cm; girth >= 90% except elbow 84.5% at the roar
  peak; PNG seams walk 0.92/1.35 (medians 1.21/1.49), roar 0.16/0.13; tail tip >= 20 m in the roar.
- Director board: notes blender-reptile/director/ (25.5 s 1080p all-intra mp4, still sheet, README).
  Left = Blender render (view "high"); right = old reptile on Tripo auto-rig weights, real in-game frames
  (kaiju-look-test round 2, panel B), looped. Captions state only what the look-test note documents.
## Tools (tools/blender/motion_test.py)
`-- <A|B|C|auto|landmarks.json> <in.glb> <out_dir> <task> [clips|height]`; tasks: render, measure,
volume, crops, diff (per-frame pose change in rig space + seam + tail tip + snout-tip track), still,
blend, fit, export. Env MT_VIEWS (side,threeq,high) and MT_RES (WxH) for board renders.
tools/blender/verify_skin.py <skin.json> <kvox>. Scratch helpers (not in repo): r6/encode_intra.py
(gopsize 1, no B-frames, PERC_LOSSLESS), r6/pngdiff.py, ct/compose1.py, ct/board.py, dir/board.py,
dir/extract.py (movie -> cropped JPEG frames via the VSE). No ffmpeg on this PC; Blender encodes.
## Format agreement (kaiju-voxel-skin, 15:04)
.skin.json bones parents-first, GAME axes (-x, z, y), metres, origin ground under pelvis, 100 m tall,
per-bone "game" name (pelvis->spine0, spine->spine1, chest/clav->spine2, neck0/1->head0, head->head1,
jaw, arm/leg _x0/1/2, tail9 folds into tail8), kvox_cell_to_skin 4x4. .skinw "KSKW" u32 ver 1, u32 N,
u16 bones, N x 32 B {f32 xyz, u8 bone[4], f32 w[4]}. Re-export = their rebake (stale stamp).
## Branch and commit
claude/blender-reptile-f5388e (pushed, clean). Latest: d924b29 (r7 evidence), 6051284 (r7 script).
## Unfinished changes
None.
## Attempts worth remembering (fix-loop record)
- Rig origin at the snout put planted feet 60 m ahead: re-origin on the pelvis.
- Stale rig.matrix_world gave a one-frame foot offset: build the matrix per frame.
- Blender IK is history-dependent: one clip per process, settle() = frame_set twice.
- UV-seam splits crack per-vertex weights: weld by position before weighting.
- Sealed Tripo mouth: deleting spanning faces showed holes, tinting caught cheeks; a rip along a measured
  tooth line + hard head/jaw weights in the mouth zone worked (render only; export untouched).
- Mean-vertex pose diff exposes buzz, holds and seams that eyes miss; an 18-frame codec GOP faked
  "contact snaps" and seam pops in mp4s: judge seams on PNGs, encode all-intra.
- A camera that follows the root breaks a loop unless the travel per clip is a whole number of ground
  texture PERIODS (Blender checker period = 2 squares).
## Open decisions (lead/director)
Director: judge the croc titan (board + #19 in-game before/after). Then the lead assigns baby/adolescent.
## Running jobs
None. No Blender open (MCP or headless).
## Findings for the lead (theirs to record)
- Seams and snaps judged on mp4s can be codec artefacts (GOP keyframes): use PNG frames.
- Follow-cam loops need travel = whole ground-texture periods.
- Auto skeleton fit (upright-biped slicing rules) fails on horizontal croc-theropod bodies.
