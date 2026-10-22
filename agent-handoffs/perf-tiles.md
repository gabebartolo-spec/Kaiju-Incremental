# perf-tiles handoff, 2026-10-22
## State: PARKED (director 2026-10-22: "Park it"). Not merged, no PR. Revive only if he reopens it.
## Task
Task 015: cull off-screen props and skyline by tiling their MultiMeshes; pixel-identical (diff 0 at 4K on
all presets), headless instance-set test, GPU frame time before/after. Do not touch building_stream.gd.
## Branch and commit
claude/perf-tiles (local only), cherry-picked on origin/claude/look-options 95f01083. Backup of the old
history: claude/perf-tiles-pre-rebase (581e258c). Commits: WIP MeshTiles split, capture tools.
## Done
- scenes/mesh_tiles.gd (MeshTiles), PropField/CityDecor/CitySkyline/VoxelBuilder.build_tiled, tuning
  city.prop_tile 32 / skyline_tile 96, tests/lib/city_mesh_tiles.gd (in the city suite: 7 of 7
  functions, 177 checks, passes; shown failing with a tampered slot).
- Tools: tools/capture/capture_graphics.gd gained --levels, --play, --stage, --hide-kaiju and waits for
  the BuildingStream and aligns the shot to a frame number (the renderer's dither follows it);
  tools/capture/image_diff.gd (pixel diff, --mask, --noise=<runs of one build>).
- Instance counts: stage 1 props 81,791 in 54 tiles, skyline sets 7,703/201/1,755/211/1,377 in
  40/21/36/3/26 tiles; stage 4 props 781,077 in 264 tiles, skyline 6,209/203/1,184/211/42.
## Evidence: pixel diff (4K, seed city 0, kaiju and particles hidden, 4 baseline runs as noise mask)
Pixels differing outside run-to-run noise (committed state, two runs agree exactly): potato 37 (max 2
levels), low 55 (3), medium 168 (4), high 38 (30), max 38 (30), of 8.05M. Noise itself: stadium
crowd, lit windows, one water speck (a few hundred px, differs run to run on the UNTILED base too).
Residual spots are fixed: far-skyline window edge (504,240), a thin prop edge (2112,1128), (1896,1176),
and the right-edge column of high/max. Tile size changes them (skyline tile 24: hundreds of px, 178).
## Attempts (fix-loop record)
1. Anchor every tile at the old MultiMesh's centre with sorting_use_aabb_center=false so the draw-sort
   key matches the one big MultiMesh: residual unchanged (potato 11, medium 146, high 152). Reverted.
2. Not run: cause is equal-depth ties on contact edges whose winner follows draw order; original order
   (instance index, y-sorted) cannot be reproduced across tiles. Lead said stop after two.
## GPU frame time (RTX 4070 SUPER, shared GPU, noisy)
Stage 1 medium before 8.7/9.8, after 9.7/9.4 ms; high 11.6/13.4 vs 14.7/15.7: no gain.
Stage 4 CAVEAT: the same scene swung 184 to 1477 ms between identical runs (shared GPU), so only the low-preset drop is even suggestive. (781k props): low before 774/656, after 174/131; medium before 1477/184, after 250/183; high
564 vs 539/609: too noisy to claim a gain (other agents on the GPU).
## Open decisions
Director: accept a sub-0.001% edge difference (and a tile-size dependent one), or drop the change.
## Findings for the lead
A before/after pixel diff needs: wait for BuildingStream.complete(), start the shots on a frame-number
multiple (SSAO dither), hide the kaiju/particles, and a noise mask from several baseline runs.
