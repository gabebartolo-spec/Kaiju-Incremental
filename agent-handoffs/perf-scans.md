# perf-scans handoff

Branch claude/perf-scans (worktree ../Kaiju-Incremental-wt/perf-scans, from origin/claude/look-options 0692ca15). No PR.

State: WIP, code written, NOT yet run green.
- scenes/building_fade.gd: footprint grid (CELL 32 m) + `blocking(eye, sight)`; `update` uses it (same set, ascending building order).
- scenes/light_pool.gd: `nearest` keeps the best pool_size as it scans (PackedFloat32Array bsearch, 32-bit distance, ties by tree index).
- tests/run_scans_tests.gd + tests/lib/scans.gd: recorded stage-4 walk (600 frames) for the fade (set + opacity equality vs a copy of the old scan),
  night-city lamp path + equidistant lattice for the lights; prints SCANS old vs new ms per frame. Last run had a parse error (float() of a Variant), just fixed, not rerun.

Next: run `tests/run_scans_tests.gd` (headless, APPDATA own dir; retry on exit 139 startup segfault), fix, record ms before/after
from the SCANS lines, add a tests/README.md row, run suites load + city (touch fade/lights), commit, push, report.
