# croc-neck / audit-ci handoff (builder)
## Neck (#32/#33): done, no more neck changes (lead: NECK_SHARE 0.75 stands; director: the "hole" is jaw-to-forearm space)
Branch claude/croc-neck pushed (turn-weight merged). Clip: scratchpad croc_neck_dash_turns.mp4.
## Audit package 1: branch claude/audit-ci (worktree ../Kaiju-Incremental-wt/audit-ci), off origin/claude/look-options
- (a) tools/lint/tuning_keys.py (0 real misses; planted misspelt key caught, removed), wired in tests.yml preflight.
- (b) tools/lint/complexity_ratchet.py + complexity_baseline.txt (80 offenders; planted 48-line function caught, removed), wired too.
- (c) shape_count, flame_cone (+ _flame_voxel, 2 vars), brick_count, count_below deleted (single mentions repo-wide).
- (d) no change: BipedGait is also built directly (ClipGait.or_biped fallback, ClipGait.off); BuildingVoxels is built directly
  by BuildingView and extended by LandmarkVoxels. Both bases earn their place.
- Full suite local run (tools/run_tests.sh --quick): only visible FAILs are the Native suite (gdextension not built locally, as before); smoke etc. not
  individually confirmed from the truncated log. Left: re-run smoke+city+cell_mesh if desired, then report / open PR (lead decides).
