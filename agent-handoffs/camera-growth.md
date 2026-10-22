# Camera-growth handoff, 2026-10-22
## State: done, awaiting lead QC of the v3 clip
## Task
Camera A (D-121) + falling towers fade: critic FIX on cameraA_topple_fade.mp4 (head too high 1.9-3.6 s; zoom bob
0-2 s; dither opacity cap 0.35 over the kaiju; fade ramp 12-15 frames), head-bone framing check, full local suite,
ONE ~6 s 4K clip on the local GPU for lead QC. Push only, no PR (lead opens PRs).
Earlier history: side-session-notes/local_df2c2989-.../camera-growth/handoff.md.
## Branch
claude/camera-growth-v2 (worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/camera-growth): own commits
cherry-picked onto origin/claude/look-options d834f58b (9 commits, no merges). Backup refs claude/camera-growth-pre-rebase
(fefd8679 old history). Remote claude/camera-growth (38c76538) is not an ancestor of the rebuilt branch -> push -v2.
## What is in (PR #150, branch claude/camera-growth-v2, merged with origin/claude/look-options after #148)
- Fade: camera fade_opacity 0.35, 15-frame smoothstep, fade_width, 2 px dither. Sight = sim points + HeadFrame.sight()
  (every bone centre + head/jaw/spine box corners, CityView.drawn_sight): feet/head hidden behind a solid tower 20/15 -> 0/1.
- Zoom bob: follow rigid along the view; camera-to-body distance over the clip run 62.31-65.10 (mean 63.82), 360 frames.
- Pan pops (critic round 2): scenes/damped.gd (critically damped). Aim follow_s 0.3, follow_accel 400/scale, lead 1/lead_ease,
  tilt head_rise_s 0.06 / head_settle_s 0.6. Shake-removed aim: max accel yaw 4.2, pitch 8.0 px/frame^2 at 4K (7-10 frames above 4).
- Head room: highest drawn point min 6.7% from the top (safe 12) at one roar-rise, 32 frames under 12%; damping trades this.
- Suites: camera_frame 4 fns 13 checks, camera 5/9, scans green (reference easing updated), full SUITES_ONLY 24 suites pass.
## Done
- Pushed 7b42cab3 (+ this handoff). Clip: side-session-notes/local_df2c2989-.../camera-growth/cameraA_v3_topple_fade.mp4
  (3840x2160, 6 s 60 fps, A stage 4 rampage, local RTX 4070 SUPER, borderless window, peak 14.9 GB). override.cfg removed.
- Tool: --trace prints CAM yaw/pitch/shake per frame; --no-frames renders at game timing without saving. To read pans, subtract the
  shake of the PREVIOUS frame (shake updates after placement) and use pitch + shake.y (metric asin(back.y) is minus the elevation).
- In a 2x-stretch window CAMCHECK top/sim shares are of the 1080 canvas over the 2160 image: double them.
## Rules learnt
- Stage-4 runs peak ~14 GB: one at a time. godot_quiet.sh named in the brief does not exist; used RULES-NOW.md override.cfg.
