# city-memory handoff

Task: stage-4 city (4,435 buildings) swaps to 10+ GB; cap it. Branch claude/city-memory (worktree ../Kaiju-Incremental-wt/city-memory). No PR.

Findings (headless, static MB): baseline load 4.4 GB (CityDecor props ~1.9 GB, StreetLife ~1 GB, 44 initial buildings ~0.3 GB);
streaming adds ~6 MB per building (~59 KB per structural chunk, mesh data; headless dummy renderer keeps it) = 25 GB full.
Per-building cost: voxel Dictionary kept in BuildingView._baked cache + mesher.

Changes so far:
- BuildingMesher drops its voxels after baking; BuildingView.voxels is a lazy getter (rebuilt deterministically on demand); cache keeps only the mesher.
- BuildingStream rewritten: chunk budget city.stream_chunks (data/tuning.json), nearest-first streaming around the moving kaiju,
  untouched far buildings freed back to stand-in boxes (BuildingView.forget drops cache); any view(n) call pins the building.
- tools/capture/stage4_memory.gd: the 60 s autoplay probe (PASS/FAIL on 6144 MB peak, 50 ms hitch).

Results (headless, static MB; tools/capture/stage4_memory.gd, 60 s autoplay):
- before: load 4463, risen 6034, +8 s standing 10.3 GB and climbing (25 GB full).
- after:  load 750, 10 s 1785, 30 s 2911, 60 s 3810 (peak 3810 < 6144); worst stream step 6 ms; 155/282/472 meshed.
  Pinned (touched) buildings grow to ~470 by 60 s and are never freed: they are the remaining growth.
- Load suite passes (31 checks) incl. new _check_stream_budget (budget, touched never freed, freed building re-meshes
  with identical digest). The _check_stream test sets stream_chunks huge (stage 2 = 79k chunks > budget).
- Headless dummy renderer keeps vertex arrays (~11 MB for a 4x3x27 tower); real RAM/VRAM NOT measured.

Left (no Godot runs now, director needs the PC):
1. Real off-screen GPU run of the probe: needs untracked override.cfg (focus-guard hook wants window/size/mode=0, no_focus=true,
   initial_position_type=0, initial_position=Vector2i(-20000,-20000)), then
   godot --path . --windowed --resolution 1280x720 --script res://tools/capture/stage4_memory.gd  (prints private MB + video MB).
2. Full suite locally (data/tuning.json touched), then PR. stream_chunks 24000 also caps stages 2-3 (far buildings stay boxes): lead to confirm look.
3. Optional: ARRAY_FLAG_COMPRESS_ATTRIBUTES (untested), lower load-suite time (new test ~150 s; could use tier 2, budget 17000).
