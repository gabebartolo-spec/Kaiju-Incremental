# Camera-growth handoff, 2026-10-22
## State: full suite running, then the 4K clip
## Task
Camera A (D-121) + falling towers fade: critic FIX on cameraA_topple_fade.mp4 (head too high 1.9-3.6 s; zoom bob
0-2 s; dither opacity cap 0.35 over the kaiju; fade ramp 12-15 frames), head-bone framing check, full local suite,
ONE ~6 s 4K clip on the local GPU for lead QC. Push only, no PR (lead opens PRs).
Earlier history: side-session-notes/local_df2c2989-.../camera-growth/handoff.md.
## Branch
claude/camera-growth-v2 (worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/camera-growth): own commits
cherry-picked onto origin/claude/look-options d834f58b (9 commits, no merges). Backup refs claude/camera-growth-pre-rebase
(fefd8679 old history). Remote claude/camera-growth (38c76538) is not an ancestor of the rebuilt branch -> push -v2.
## What is in
- Fade: tuning camera fade_opacity 0.35, fade_seconds 0.25 (15 frames, smoothstep), fade_width 1.0, 2 px dither (38c76538).
- Zoom bob: CameraFollow.step follows the body at once along the view's ground direction (lag only across); BreathCamera
  lift keeps the rest length; lead_depth_share 0. Cause: FOCUS_FOLLOW lag toward the camera, not the lead.
- Head room: scenes/head_frame.gd (HeadFrame) tilts the aim up (head_rise 60/s, head_settle 1.5/s) when the highest drawn
  point (bone-box corners) would enter safe_top 0.12; counts the camera shake's pitch (Rampage passes Vector2(fov, nod)).
- Suite tests/run_camera_frame_tests.gd (2 fns, 7 checks); README row added.
## Evidence (A stage 4 rampage 5.5 s headless, tools/capture/capture_camera_growth.gd --trace, scratch kcg/)
- Before (zoom bob): sim share 31-45% (camera distance 60-80). Now sim share 39.8-41.8% steady, dist 62-64.6.
- Highest drawn point: min 12.0% from the top (safe 12) vs 6.3% before the shake-aware tilt; head in top margin 14 frames
  are float-equal 12.0; centre outside middle 60%: 0. Tilt peaks 7.7 deg.
- Still seen: feet hidden behind a solid building 20 of 330 frames, head behind solid 15, body behind a falling section
  216 (solid 0: all faded). Not touched.
- Lints (gdlint, tuning_keys, complexity_ratchet, check_scripts 346 ok) green; suites camera 5/5 9 checks, camera_frame 2/2 7.
## Left
1) Full suite (SUITES_ONLY=1) log kcg/full.log. 2) One 6 s 3840x2160 clip (override.cfg off-screen, local GPU), view at 2x.
3) Push -v2, report. Remove override.cfg afterwards.
## Rules learnt
- Stage-4 runs peak ~14 GB: one at a time. godot_quiet.sh named in the brief does not exist; used RULES-NOW.md override.cfg.
