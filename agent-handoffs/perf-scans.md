# perf-scans handoff

Branch claude/perf-scans (worktree ../Kaiju-Incremental-wt/perf-scans), rebuilt on origin/claude/look-options 56d92a1b
(backup ref claude/perf-scans-pre-rebase). Old remote claude/perf-scans (010285eb) is not an ancestor: push to
claude/perf-scans-v2. No PR (the lead opens it).

State: code green, full suite running/recorded below.
- scenes/building_fade.gd: footprint grid (CELL 32 m) + `blocking(eye, sight)`; `update` uses it (same set, ascending building order).
- scenes/light_pool.gd: `nearest` keeps the best pool_size as it scans (PackedFloat32Array bsearch, 32-bit distance, ties by tree index).
- tests/run_scans_tests.gd + tests/lib/scans.gd: recorded stage-4 walk (600 frames) vs a copy of the old scan (set, order, opacity);
  night-city lamp path (57 spots, 395 lamps) + equidistant lattice for the lights. README row added.
- tools/lint/complexity_baseline.txt: BuildingFade.update row removed (now within limits).

Pixel identity: the fade sets/order/opacities and the light picks are equal to the old scans on every frame/spot, so the
same set_opacity / set_wanted calls happen (nothing else changed). Proven by the scans suite (6 checks, 0 failures);
checks shown failing on planted defects (bsearch left side, footprint indexed by one cell only: 4 failures).

Measured (SCANS lines, headless, stage 4): fade 4,435 buildings, 600 frames: old 0.914 ms/frame, indexed 0.159 ms/frame;
lights 395 lamps, 57 spots: old 1.054 ms/call, new 0.270 ms/call.

Not exercised: in-game render stills (equal inputs to set_opacity/set_wanted, so none taken); buildings changing
footprint at runtime (walls never move; sim has no resize).
