# city-memory handoff

Branch claude/city-memory (worktree ../Kaiju-Incremental-wt/city-memory). No PR (the lead opens it).

## Part 1: stage-4 memory cap (earlier builder)
- BuildingMesher drops voxels after baking; BuildingView.voxels is a lazy getter; cache keeps only the mesher.
- BuildingStream: chunk budget city.stream_chunks (24000), nearest-first, untouched far buildings freed back to boxes,
  view(n) pins. tools/capture/stage4_memory.gd = 60 s autoplay probe.

## Part 2: stream ranks by the camera view
- scenes/stream_rank.gd (StreamRank): rank = min(camera distance, kaiju distance + kaiju_extra_m); +side_m in the margin
  band beside the frustum wedge, +outside_m beyond it; ring_m round the camera free; look() reads the camera.
  Data: data/tuning.json city.stream_view (margin_deg 30, ring 12, side 40, outside 100, kaiju_extra 30).
  scenes/stream_stand_ins.gd (StreamStandIns) holds the facade boxes. building_stream.gd is at the 400-line cap.
- Test: tests/run_streamview_tests.gd + tests/lib/stream_view.gd + tests/lib/stream_frustum.gd.

## Part 3: out-of-view landmarks unload (director 2026-10-22: "Yes, if no pop-in")
- StreamRank.keeps_landmark(n, kaiju): a landmark stays meshed (counted first, as before) when there is no camera, or its
  zone is the frustum wedge/ring or the margin band (zone < 2), or it is within city.stream_view.landmark_keep_m (150:
  a stage-4 dash is 113 m) of the camera or the kaiju (minus its radius). Else it ranks and evicts like any building.
- Test proof (suite streamview, 41 checks, 0 failures): per frame, a landmark that is a box AND meets the frustum
  (any distance) is a pop; 0 frames in rest, swing x3 spots, walk east/north-east out and back (camera turning),
  dash x2, both stages. The check is live: stage 4 north-east walk has the landmarks unloaded 862 + 986 frames.
  Planted defect (keeps_landmark always false): 23 checks fail (pops in rest/swing/walks/dash). landmark_keep_m 0 still
  passes: wedge + band alone are enough here; 150 is a dash-length safety margin (lead's call to shrink).
- Memory stage4_memory.gd (60 s autoplay, loaded PC): before static 3810 MB, private 4445 MB, resident 86583 chunks;
  after the same (3810 / 4473 MB): the autoplay kaiju stays within 150 m of the landmarks, so nothing unloads. The
  saving (up to 13192 of the chunks) only happens when the kaiju roams > 150 m + radius away, facing away.
- Found and fixed: a pre-existing thread race. Content.look() builds its merged dictionary on first use; the first
  parallel BuildingView builds raced it and segfaulted (exit 139, streamview suite, silent). BuildingStream._ready now
  calls Content.look() on the main thread first (5/5 serial ok before, 6/6 after).
- Reported, not asserted: stage-4 walks north-east / south leave boxes inside 48 m for hundreds of frames (the stream
  does not keep up with a 5 m/s walk across the whole arena, as before); a dash cannot be held at this budget.

## State (PR #153, branch claude/city-memory-v2)
- Merged origin/claude/look-options; capture scripts use Kit.STAGE_LEVELS; gdlint/ratchet/check_scripts green.
- CI flow failure (staged build stalled at 5 of 7): the headless dummy renderer hands out resource ids unsafely when
  worker threads and the main-thread build create them at once (RID errors, a null material aborts CityView._ready).
  BuildingStream._mesh_initial now meshes the nearest buildings on the main thread when DisplayServer is headless;
  the real renderer keeps the worker group. flow suite: 206 checks pass. (Later streaming workers still log RID errors
  in headless, as on the base; not changed.)
- CI streamview failure (47 m, 4 frames short, timing): the test now owns the stream's clock (set_process(false),
  BuildingStream.step(DT) per camera frame, workers drained each frame), so it judges the plan, not machine speed;
  result is identical run to run. Stages are 2 and 3 (stage 4 is cut, D-135). Worker speed is no longer tested:
  a turn cannot reveal an unloaded landmark because the 30 deg band (>= swing + shake, checked) keeps it built.
- landmark_keep_m is now 80 (was 150): stage 3's arena is small, 150 never let a landmark unload (0 frames). With 80 the
  north-east corner walk has the landmarks unloaded 1492 + 477 frames and 0 pop frames; planted always-unload still fails.
- tools/capture/stage4_memory.gd still targets the 4435-building city (cut by D-135); needs retargeting by the lead.
- Not done: real GPU run of stage4_memory.gd; CI result of the push.
