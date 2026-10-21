# croc-neck handoff (builder, comments #32 head retracts after dash, #33 head tears off in sharp turn)
Branch claude/croc-neck (worktree ../Kaiju-Incremental-wt/croc-neck) off origin/claude/turn-weight. No PR.
Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe, APPDATA=/tmp/ad1.
## Findings
- The scene paths: the reptilian (all 3 stages) has .kclip clips so it runs ClipGait (scenes/gait_clip.gd), which
  NEVER calls BipedHead.update. Its head is clip pose + _look_ahead (head0 yaw 0.4*look, head1 0.6*look, look<=0.6).
  The lead's BipedHead reading (spring, HEAD_MAX_YAW) applies only to procedural BipedGait (clip-less fallback).
- Bones: spine2 -> head0 (neck, 1.3 long) -> head1 (skull 3.3 long) -> jaw. voxel 1/32.
## State
- tests/lib/smoke_croc_neck.gd written (measure + check; not yet wired into run_smoke_tests.gd). Probe in scratchpad p2.gd.
