# Handoff: claw-anim (the claw swipe's arm motion)

Updated 2026-10-25. Session started by the Kaiju lead (local_293f5c32). Worktree `.claude/worktrees/casc-anim-f911ce`,
branch `claude/claw-anim-525a2a` (pushed, 67c1386a); the lead opens the PR.

## The job
Director 2026-10-25: "the arm movement during the claw swipe animation is really bad ... Especially the baby's arm
looks really bad, it moves too fast and stretches the limb beyond anatomic belief"; "dont improvise, plan, research
then implement, then iterate". Rulings: D-190 (swipe straight ahead on the snout line), D-216 (Cascadeur for clips),
the 2026-10-25 animation rule (ONE ~6 s side-on clip a critic has passed; a third failed clip changes the method).
Arm motion is mine; trail, flash and sparks are the VFX lead's (claude/claw-rake-2).

## State
- Director added (2026-10-25): "the young crocs arms are too long ... probably 40% long and dont require the dangle
  from the wrist, short and stumpy arms are the aim"; "his long arms are the reason the claw animation looks bizarre".
  Done, young only: `tools/kaiju_skin/shorten_arms.py reptilian_baby 0.4` (run ONCE; it cuts again if rerun) cut the
  .kvox, rig.json and Blender skin (assets/kaiju/test/croctitan_baby.*), then `bake_all.sh` rebaked the vskin.
  rig.json `lock_wrist` (hands in line, BipedSwing.hold_arms / _aim_arm) and `arm_length` (KaijuClips.fit skips
  the moved elbow/wrist heads; without it the young croc fell back to the procedural gait).
- Lead FIX on clip 2 (arm fused into the chest): rig.json `arm_pose` holds the young croc's arms out and down, clear of
  the chest (KaijuRig.arm_pose, BipedSwing.hold_arms/_held); `capture_claw_side.gd` prints the px bars (hand and
  forearm outside the body silhouette at rest; claw tip ahead of the chest outline at the hit, in hand lengths).
- Swipe = a short chop in front of the chest; poses/times in `data/tuning.json` "claw_fx" (arm_cocked/contact/
  through, aim_max_deg 45, strike_s 0.38 at every size (strike_size_power 0), strike_ease 0.7 (ease-out), hit_at 0.1 = where the hit falls in the strike so the chop is fastest on it, lift_s, strike_s, recover_s, joint_lag_s); `powers.swipe_windup` 0.7. Code:
  `scenes/biped_swing.gd` (_rake_dirs/_rake_dir, _blend/_frame, _contact_yaw, strike_window, hold_arms, _held).
- Bars: `data/motion_gate.json` "claw_arm", checked by `tests/lib/claw_arm_probe.gd` from the croc standing suite
  (green, 5/5, 76 checks). Print numbers: `tools/claw_probe.gd` (`-- --frames` per frame). Plan: docs/claw_swipe_plan.md.
- Clip: `tools/capture/capture_claw_side.gd` (windowed, untracked no_focus override.cfg; `-- --still=<dir>
  --name=<x>` for the rest still). Clip 4 (chop 16-17 frames, lead FIX on clip 3) sent; arms passed on clip 3 (side-notes claw-anim-clip3.*, clip4.mp4; earlier
  claw-anim-clip2.*); clip 1 superseded unreviewed. VFX lead told the new claw_arc reach.

## Next
- Lead check of clip 4 (its FIX on clip 3: chop too fast). FIX: retune, all bars must pass. Another failure = stop, find why,
  change method (a Cascadeur swipe clip per stage).

## Gotchas
- Python: numpy lives in the Roaming user site: keep APPDATA real when running bake.py (bake_all sets its own
  APPDATA for Godot only).
- Godot: `/c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe` (a folder named
  .exe); APPDATA=`$TEMP/claw-appdata`; `--import` segfaults on the missing native lib but scripts still run.
- gdtoolkit only under `python3`/`py`, not `C:\Python314\python`; the formatter writes CRLF on Windows: convert to LF.
- Body scales per stage in a run: 0.5 / 0.9 / 1.3 (Growth.body_scale at size 1, 2, 3); the probe sets them.
- The Behemoth and Colossus clips hold the upper arm outward (+0.13 / +0.21), the young croc's across (-0.43).
- ffmpeg: imageio_ffmpeg's bundled exe (no system ffmpeg).
