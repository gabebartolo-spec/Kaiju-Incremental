# blender-reptile handoff, 2026-10-18 04:00
## State: awaiting lead (PR #22 open, head a88a4d4, sent to the new lead "Game demo planning"
## local_106fc100-d2a4-4091-bc9a-4bda31df13ac, which owns QA since 03:56; old lead = Tripo only).
## Running: b2vwtf0yr chain -> ci5/after_side (39050777699), then ci5/before_game. When they land:
## cut 3 s side clips walk/turn/roar to notes d047/, update PR #22 body (gh pr edit 22 --body-file
## scratch ev/pr_body.md; replace 'pending'/'running' lines). Auto-fix shows ON (set in the app).
## Open lead decision: cards full spin (as pushed, small) vs sway +-40 deg (recommended).
## Next phase P3 (Game demo planning 03:41): croc baby + adolescent from lead's Tripo meshes;
## plan C:/Users/DANTE/.claude/plans/pasted-content-id-a4a2-i-want-glistening-bubble.md
## Task (lead 22:47 + director tail note 00:36): D-047 on croc titan v2, one PR, then send head SHA
Open the D-047 PR into claude/look-options with: BEFORE/AFTER at the game camera, per-frame PNG
diff (seams, blends), 2x crops of feet at contact and jaw at roar peak, a 4K species-select still,
a Blender walk/turn/roar render of v2, and (tail note) top-down walk tip-path render old vs new,
2x crops of the tail root in the turn. One self-check, list nits, no loops. Auto-fix off. Don't
merge. Tail attack (swipe flattening towers): suggestion only, a director gameplay call.
## Branch and commit
claude/croctitan-clips (this worktree). Pushed a168942: tail cb1726e, clips-own-tail test 5400a96,
species card fix a168942 (lead 01:38: fix it in this PR).
## Tail (cb1726e)
- motion_test.py: TAIL_WALK (4.0, 1.5) deg/joint wave, TAIL_LAG 0.5 rad/joint; TAIL_IDLE (1.2, 0.6)
  72-frame sway (0.6 in roar); turn whip tail_whip(): spring TAIL_SPRING (12 rad/s, 0.35) driven by
  body yaw accel, TAIL_WHIP (5.0, 6.4), 0.5 frame delay per joint; roar lift (1.0/joint, f10-33),
  slam TAIL_SLAM 0.85 x (0.5+k) wave f33-46, rebound, rests low until recovery.
- New tasks: `tail` (sweep/bends/clearance JSON), `tailtop` (top-down still with tip paths),
  crops adds tail_root_drag/whip/over (turn f39/f108/f117).
- Measured (old -> new): walk tip sweep 15.5 -> 33.8 m, root third 4.8 -> 9.4 m (x3.6); idle
  0 -> 10.4 m; worst bend 7.9 deg/joint (limit 25); turn tip: drag 32 deg, through 26 deg at
  the stop, overshoot 6 deg, settled to 10% in 0.46 s; roar skin 26.6 m lift -> 0.5 m slam.
- gait_clip.gd: TURN_SETTLE 12 frames (turn clip plays its tail settle); tail lag spring for
  walking curves (drive = body yaw accel in walk/idle), soft limit TAIL_MAX 0.008 (tanh).
- clips suite 13: walking curve swings the tail and settles (shown failing with drive off); the
  clips own the tail (lead part 2): ClipGait.update never calls BipedSwing.update (0.12 rad clamp)
  or simulate_chains; straight walk matches clip within 0.01 rad; standing turn bends 0.189 rad.
- Lead part 2 still owed: in-game 2x crop of tail root at the turn extreme (voxel parting) from
  ci3/after_game; in-game BEFORE/AFTER must show the tail; state the tail owner in the PR body.
  All suites green locally.
## Lead QA round (02:31, one pass): bolder tail - committed and pushed 2dbc983 (suites all green)
- Walk: TAIL_WALK (4, 10), TAIL_LAG 0.42 (0.6 wave; a full wave cancels the tip to 23-28 m at 18
  deg, so say so): tip 62.9 m, worst 14.0 deg. Idle tip 13.7 m. Turn kept (worst 15.8 deg).
- Roar: TAIL_LIFT (5, -18) arc (mid 50 m, tip trails 36 m at f27); TAIL_TRAIL 12 tip curls up to
  79 m at f35 as root drives down; slam TAIL_SLAM (1.15 land, 0.85 rest) x (0.2 + 1.6k), fall
  5 - 3k frames; mid bottoms f44-45, tip lands f47 at 2.6 m/frame (skin 0.4 m), bounces +2.7 m.
- tail task records joint_z; crops adds roar f47 tail_mid_slam.
- Done: tail/tailtop_old_vs_new.png, roar_sheet.png, crops2/ (clean), board mp4s re-encoded,
  ci3/before_game forward_plus (run 39042141622, 595 frames).
- Next: when ci4 lands: in-game 2x root crop at turn + mid-tail at slam, compose BEFORE/AFTER
  (ev/compose_ba.py ci3/before_game vs ci4/after_game) + PNG diff, commit evidence, open PR,
  send lead head SHA. Nits: f51 bounce only +2.7 m (barely reads); mantis card head cut (old).
## P2 asks (Game demo planning): green capture runs; in-game 3 s clips walk/turn/roar at game cam
## (DONE, notes d047/ingame_game_cam_*.mp4) + side (from ci5/after_side); report SHA to lead AND
## "Game demo planning" (local_106fc100-d2a4-4091-bc9a-4bda31df13ac). 39047808973 cancelled.
## Evidence done (docs/captures/2026-10-18-croctitan-clips, uncommitted until the cards land)
before_after_game_sheet, png_diff_game, feet_contact_2x, jaw_roar_peak_2x, tail_in_game_2x,
tail_walk_topdown_old_vs_new, tail_roar_side_sheet, tail_blender_crops. MP4s in notes/blender-reptile/
d047/. PR body: scratch ev/pr_body.md (only CARDS_PLACEHOLDER left). AFTER run 39046293165 green.
Last steps: cards_before_after (ci2 vs ci4 select4k crop box 440,470,3400,1070) + species_select_4k
.png into the folder, fill CARDS_PLACEHOLDER, commit, push, gh pr create --base claude/look-options
--title "art: ...", ccd_pr bind, auto-fix OFF, send lead the head SHA.
## Species card height fit (5bd22c4, lead 03:00)
_frame aims at the kaiju's middle, fits width (0.92) and height (6% margin) of the swept profile,
PREVIEW_FOV 30 (fill: croc 0.42, mantis 0.62, octopus 0.48 of card height; mantis was 0.93 and cut).
Red capture runs: Capture step exit 124 = the workflow's hard 3000 s Godot timeout on lavapipe
(capture.yml line 115); PNGs written before the kill; BEFORE game has 595/600 frames. Say so in PR;
follow-up: make the timeout a dispatch input.
## Species card (a168942, superseded by 5bd22c4)
species_select._frame: old fixed camera, backed off along the same view only when the turning kaiju
(skin reach per height band, every angle) is wider than the card. Distances: croc 12.8 -> 23.7,
octopus -> 16.1 (its tentacles clipped before), mantis unchanged. +0.4 s card build. Lead wanted a
fixed 3/4 yaw, but the card spins (0.35 rad/s), so I fit the swept volume; say so in the PR. Owed:
before/after card stills: DONE tail/cards_before_after.png (ci3/select4k run 39042109877);
mantis head cut at top in both (pre-existing nit).
## Done evidence
ci3/after_game (forward_plus, cb1726e; turn ends 12.25 s, drift 0.0 cm); tail/game_tailroot_2x.png
(no parting at 10.2 s drag / 11.0 s swing-through); tail/ Blender board mp4s (croctitan_v2_tail_*).
ci2/before_game was gl_compatibility (fallback): not comparable, rerun on forward_plus.
## Evidence pipeline (scratch)
tail/ (old/new JSON, tailtop_old_vs_new.png, crops_row.png, r/ renders), ci2/ (before_* valid:
procedural path unchanged; after_* stale pre-tail), ci3/ (new after_game, after_jaw_side).
select4k 39031717171 and before_game 39031609516 still running on CI (pre-tail head; species
select still shows the idle tail - note it). ev/compose_ba.py, ev/pngdiff_game.py,
ev/encode_intra30.py, r6/encode_intra.py, v2b/compose_v2.py. PR body draft ev/pr_body.md.
## Nits (list in PR)
- Blender render: inner lip shards at roar peak; foot slide walk 12 cm, turn 87 cm (sole sinks).
- In-game side capture: head leaves frame top at roar peak.
- Turn clips only for standing turns; walking curves use walk + IK + tail lag spring.
## Findings for the lead (theirs to record)
- Windows CRLF writes break byte-hashed stamps: write LF explicitly.
- The focus guard flags `set -e` as Godot's editor flag.
