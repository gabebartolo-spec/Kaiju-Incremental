# ci-shards handoff (builder, 2026-10-20)

State: branch claude/ci-shards pushed (from origin/claude/look-options); no PR (3-PR cap; lead opens after #89 merges).

Findings
- The tests dir has 9 suites on look-options (10 with military-ai), not 18 ("18" counted the .uid files). Every
  suite was already listed, bar `military`; the real fault was stale numbers and only 2 shards.
- Setup is small: import ~5 s, checkout+godot ~10 s per shard. Run 39271829662 shard 1 (4:08) vs 2 (2:39) was
  runner variance (flow 132 s, growth 56 s there vs 98 s / 12 s in 39277655772) plus flow sitting in one shard.
- Older run logs mostly 502/expired; means taken from the 6 readable runs (flow n=3, others n=2, military n=1).

Change: tools/ci_timings.txt refreshed (all 9 + military, mean seconds), shards 2 -> 3.
Predicted (plan_ci_shards.sh): 2 shards (old plan, new numbers) 109 s / 134 s; 3 shards 109 s / 69 s / 65 s.
Floor is flow (109 s, one suite), so a 4th shard gains nothing. Slowest suite step 134 -> 109 s (-25 s) for
about +15 s runner setup on a parallel job; suites sum 243 s. Wall clock is then flow + ~20 s setup + preflight.

PR body draft
  Title: CI: refresh suite timings, 3 shards
  Body: tools/ci_timings.txt now lists every suite with mean times from green PR logs (run ids in the file header),
  shards 2 -> 3. Plan: flow | load city tentacles powers | growth sim clips smoke = 109/65/69 s predicted vs
  109/134 s on 2. Proof: first PR run after merge shows per-shard suite times; re-measure weekly.
  Not exercised: a live CI run (no PR open).
