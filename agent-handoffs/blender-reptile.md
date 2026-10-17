# blender-reptile handoff, 2026-10-18 01:00
## State: running a check (AFTER CI captures bh15qd2l1 at cb1726e; Blender board renders b6yosgxdc)
## Task (lead 22:47 + director tail note 00:36): D-047 on croc titan v2, one PR, then send head SHA
Open the D-047 PR into claude/look-options with: BEFORE/AFTER at the game camera, per-frame PNG
diff (seams, blends), 2x crops of feet at contact and jaw at roar peak, a 4K species-select still,
a Blender walk/turn/roar render of v2, and (tail note) top-down walk tip-path render old vs new,
2x crops of the tail root in the turn. One self-check, list nits, no loops. Auto-fix off. Don't
merge. Tail attack (swipe flattening towers): suggestion only, a director gameplay call.
## Branch and commit
claude/croctitan-clips (this worktree). Head cb1726e pushed (tail). e560001 v2 re-fit + data.
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
- clips suite 12 (new: walking curve swings the tail, settles; shown failing with drive off).
  All suites green locally.
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
