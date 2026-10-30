# Per-preset audit at 1080p and 4K (b2-25, roadmap G)

2026-10-30. RTX 4070 SUPER, Godot 4.7.2. Run A (night, clear, stage 3), Phase 0 route
(`C:/kt/rebase/route.json`, md5 42806a67), 3600 frames at `--fixed-fps 60 --disable-vsync`, borderless
window at 0,0, PC otherwise idle. Two passes per cell; the table is their mean. Potato runs
`--rendering-method gl_compatibility`, as the game does after its restart (R 18.6). Every log confirms its
viewport (1920x1080 or 3840x2160).

`tools/capture/baseline_runs.sh presets` (new mode; `RES=` picks the resolutions) reproduces it.

## Results (ms; fps = 1000 / frame p50; over 16.7 = frames out of 3600 that miss 60 fps)

| Preset | Res | Frame p50 | Frame p95 | GPU p50 | GPU p95 | fps | Over 16.7 | VRAM MB |
|---|---|---|---|---|---|---|---|---|
| Potato | 1080p | 18.8 | 31.6 | 9.6 | 17.8 | 53 | 2441 | 1864 |
| Low | 1080p | 18.0 | 30.6 | 10.5 | 19.0 | 56 | 2198 | 2321 |
| Medium | 1080p | 19.5 | 31.1 | 15.2 | 24.8 | 51 | 2510 | 2475 |
| High | 1080p | 21.2 | 33.4 | 17.4 | 28.0 | 47 | 2960 | 2606 |
| Max | 1080p | 22.5 | 35.3 | 19.2 | 29.5 | 44 | 3247 | 2683 |
| Potato | 4K | 19.5 | 32.0 | 10.5 | 19.0 | 51 | 2668 | 1972 |
| Low | 4K | 18.7 | 30.9 | 11.9 | 20.5 | 53 | 2351 | 2586 |
| Medium | 4K | 21.7 | 33.0 | 18.7 | 29.0 | 46 | 3169 | 2975 |
| High | 4K | 25.3 | 37.7 | 23.9 | 34.6 | 40 | 3539 | 3542 |
| Max | 4K | 28.5 | 40.9 | 27.1 | 37.3 | 35 | 3589 | 3687 |

## Findings

1. **No preset holds 60 fps at either resolution.** Medium at 1080p (the D-339 bar) runs 51 fps p50 and misses
   16.7 ms on 70% of frames.
2. **1080p is CPU-bound on every preset.** Frame p50 sits 3-9 ms above GPU p50; Potato and Low land at the same
   18-19 ms frame time with GPU at 10 ms. Lowering graphics cannot reach 60 fps at 1080p: the CPU and sim side
   (proc+phys, building stream, cell promotion; see each summary's BENCH_COSTS) must shrink by ~2-3 ms first.
3. **Potato buys nothing over Low.** Its GPU is 1 ms lighter but its frame time is no better (worse at 4K).
4. **4K Medium and up are GPU-bound** (frame within 1-3 ms of GPU). 4K costs Medium +3.5 ms GPU, Max +8 ms.
5. Frame p95 is 30-41 ms everywhere: the hitches are the same CPU spikes on every preset.

## Bench fix in this PR

`bench_lib.gd` forced every windowed run to 3840x2160 and ignored `--resolution`, so a first "1080p" set was
really 4K (discarded). It now takes `--res=WxH` (default 3840x2160, unchanged for older runners) and still refuses
to measure when the viewport does not match. `baseline_runs.sh` also had a broken line continuation that
disabled its other-bench-window check.

## Recommended next step

A CPU-side profile of the 1080p Medium run (BENCH_COSTS / proc+phys spikes) before any preset retuning: the GPU is
not what stops 60 fps at the baseline resolution.
