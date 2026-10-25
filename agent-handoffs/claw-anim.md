# Handoff: claw-anim (the claw swipe's arm motion)

Updated 2026-10-25. Session started by the Kaiju lead (local_293f5c32). Worktree `.claude/worktrees/casc-anim-f911ce`,
branch `claude/claw-anim-525a2a` (pushed, 9d202887); the lead opens the PR.

## The job
Director 2026-10-25: "the arm movement during the claw swipe animation is really bad ... Especially the baby's arm
looks really bad, it moves too fast and stretches the limb beyond anatomic belief"; "dont improvise, plan, research
then implement, then iterate". Rulings: D-190 (swipe straight ahead on the snout line), D-216 (Cascadeur for clips),
the 2026-10-25 animation rule (ONE ~6 s side-on clip a critic has passed; a third failed clip changes the method).
Arm motion is mine; trail, flash and sparks are the VFX lead's (claude/claw-rake-2).

## State
- Plan, research, bars: `docs/claw_swipe_plan.md`. Bars as data: `data/motion_gate.json` "claw_arm".
- Code: `scenes/biped_swing.gd` (strike, _rake_dirs/_rake_dir, _blend/_frame local-frame interpolation,
  _contact_yaw, strike_window, size); `swing.size` set in `gait_clip.gd` / `gait_biped.gd`; poses and times in
  `data/tuning.json` "claw_fx" (lift_s, strike_s, recover_s, joint_lag_s, arm_cocked/contact/through);
  `powers.swipe_windup` 0.7.
- Measure: `tools/claw_probe.gd` (headless, prints per stage; `-- --frames` per frame), shared with the suite via
  `tests/lib/claw_arm_probe.gd` (run from the croc standing suite through `_h`).
- Clip: `tools/capture/capture_claw_side.gd` (windowed, needs the untracked no_focus override.cfg in the worktree,
  excluded via info/exclude). Clip 1 sent to the lead for the critic: side-notes folder `claw-anim-clip1.mp4` + `.md`
  (what to judge, numbers, the afk calls list for the director's interview).
- Croc standing suite green locally (5/5 functions, 73 checks); gdlint/gdformat (`python3 -m gdtoolkit...`),
  tuning_keys and complexity lint clean. CI runs the rest.

## Next
- Wait for the critic verdict via the lead. FIX: change poses/timing in claw_fx, rerun the probe (all bars must pass),
  render clip 2. Clip 3 failing = stop, find why, change the method (a Cascadeur swipe clip per stage is the fallback).
- SHIP: the lead takes it to the director.

## Gotchas
- Godot: `/c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe` (a folder named
  .exe); APPDATA=`$TEMP/claw-appdata`; `--import` segfaults on the missing native lib but scripts still run.
- gdtoolkit only under `python3`/`py`, not `C:\Python314\python`; the formatter writes CRLF on Windows: convert to LF.
- Body scales per stage in a run: 0.5 / 0.9 / 1.3 (Growth.body_scale at size 1, 2, 3); the probe sets them.
- The Behemoth and Colossus clips hold the upper arm outward (+0.13 / +0.21), the young croc's across (-0.43).
- ffmpeg: imageio_ffmpeg's bundled exe (no system ffmpeg).
