# croc-neck handoff (builder; comments #32 head retracts after dash, #33 head tears off in sharp turn)
Branch claude/croc-neck (worktree ../Kaiju-Incremental-wt/croc-neck) off origin/claude/turn-weight. No PR.
Local Godot: console exe on Desktop (Godot_v4.7.2), headless only, APPDATA=/tmp/ad1.
## Findings
- The reptilian (all stages) has .kclip so it runs ClipGait (scenes/gait_clip.gd), which never calls BipedHead.update.
  Head = clip pose + _look_ahead (head0 yaw 0.4*look, head1 0.6*look, look<=0.6). BipedHead only for clip-less fallback.
- Measured headless (tests/lib/smoke_croc_neck.gd, 3 stages): head1-to-head0 distance constant (bone hierarchy), so
  done-bar 1 as phrased cannot fail on bones; skull rig-local pos steady through dash. The tear/retract is probably in
  the SKIN (scenes/voxel_skin.gd, shaders blend bones) or in relative yaw 0.36 rad neck-vs-skull. Min-distance gap metric
  is useless (pivot touches); worst-cell metric has a big rest baseline (~27 cells, neck wider than skull base).
## State
- Pushed capture script tools/capture/capture_croc_neck.gd + test lib (not wired into run_smoke_tests.gd).
- CI capture run 39567696790 (adult, --movie) via ci_capture.sh, log /tmp/cap1.log, download /tmp/cap1. If dead, rerun:
  tools/capture/ci_capture.sh --movie --resolution=1280x720 capture_croc_neck.gd -- --stage=3 --out=/tmp/cap1
- Next: view neck crops at 2x, find the real defect, fix, then real test, merge origin/claude/turn-weight, push.
