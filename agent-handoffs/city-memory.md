# city-memory handoff

Branch claude/city-memory (worktree ../Kaiju-Incremental-wt/city-memory). No PR (the lead opens it).

## Part 1: stage-4 memory cap (earlier builder)
- BuildingMesher drops voxels after baking; BuildingView.voxels is a lazy getter; cache keeps only the mesher.
- BuildingStream: chunk budget city.stream_chunks (24000), nearest-first, untouched far buildings freed back to boxes,
  view(n) pins. tools/capture/stage4_memory.gd = 60 s autoplay probe (peak 3810 MB < 6144, step 6 ms).
- Not measured: real RAM/VRAM on a GPU run (needs override.cfg off-screen render; lead's RULES-NOW.md).

## Part 2: stream ranks by the camera view (this session)
- BuildingStream._rank: min(camera distance, kaiju distance + kaiju_extra_m); +side_m in the margin band beside the
  frustum wedge, +outside_m beyond it; ring_m round the camera free. Data: data/tuning.json city.stream_view
  (margin_deg 30 = breath orbit 25 + shake 2.5, ring 12, side 40, outside 100, kaiju_extra 30). Landmarks/pinned
  unchanged (unconditional, counted first). Replan also on camera move/turn (PLAN_TURN 4 deg, PLAN_EVERY 0.25 s).
  No camera (or no stream_view in the city dict) = the old kaiju circle.
- Camera facts (measured, tests/lib/stream_view.gd): camera yaw never exceeds 72 deg/s (the breath orbit 125 deg/s raw,
  eased by CameraFollow), total swing 24.9 deg. The camera is fixed-yaw otherwise; a dash moves the kaiju 36 m
  (stage 2) / 113 m (stage 4) in 0.4 s.
- Test: tests/run_streamview_tests.gd + tests/lib/stream_view.gd (README row added). Real stream, real camera path,
  kaiju at 3 spots, 60 fps real time. Check: no stand-in box in the frustum within 48 m at rest and through the swing.
  Failed first on af250f29 (6 failures, stage 4 nearest box 34-37 m); passes now (16 checks).
- Depth with full buildings (nearest box in frustum, m), old -> new, rest/swing at spots 0/1/2:
  stage 4: 37/37, 34/34, 98/96 -> 60/51, 53/51, 98/93.  stage 2: 64/59, 65/64, 88/83 -> 61/59, 61/57, 88/85
  (stage 2 unchanged within a few m: the budget, not the shape, limits it).
- Findings: landmarks take 13192 of the 24000 chunks (55%) at stages 2 and 4: the biggest lever on depth. A dash cannot
  be held at the same budget (D 10 m stage 4, 24-37 m stage 2, same as before); reported, not asserted.
  Margin band is not what limits the swing in this test (margin 0 gives the same depth); kept as the safety asked for.
- Step ms: worst 20-80 ms on this loaded PC (spikes are scheduler noise: any section, even add_task, spiked);
  mean replan 1-12 ms. Test asserts the median phase worst <= 50 ms.

## Left
1. Full suite (tuning.json touched) run in the background; result goes to the lead.
2. Lead: look call on landmarks (13192 chunks always meshed) and the dash.
3. Optional: real GPU run of stage4_memory.gd.
