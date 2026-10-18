# Landmarks handoff, 2026-10-19 07:20
## State: running a check (stadium stall: CI probe at head/base/fix; GitHub API rate-limited until ~10:57 UTC)

## Task
Landmarks role, reporting to LEAD ("Kaiju: LEAD (demo build, merges, QA)", local_106fc100...).
PR bodies <= 8 lines, never merge. NO LOCAL GODOT (director's movie): CI only.
- #57 landmark sites and #59 stadium matches (D-078): both MERGED into claude/look-options.
  The landmarks worktree is removed; one live worktree: ../Kaiju-Incremental-wt/stadium-stall.
- Now: LEAD's stall job. Windowed dry-run at 329e708 showed 80-110 ms stalls every ~0.7 s while
  the stadium falls, the same with the crowd off. Asked: find the cause, a CI timing probe at
  look-options 8c24654 and the pre-#59 base 5bc6b44, the smallest fix with before/after ms,
  report in <= 8 lines.

## Branches
- claude/stadium-stall (from look-options 2d2b54a; no scene/sim/data diff vs 8c24654):
  9ee5fe0 probe tools/capture/probe_stadium_stall.gd; 7f61740 the fix (sim/structure.gd).
- claude/stadium-stall-base = 5bc6b44 + the probe (6f9d862), throwaway: delete after the report.

## Cause (from the code; CI to confirm)
Structure._topple_check() (sim, runs in every settle(), i.e. after every chunk the stadium
loses): for each level 1..h-1 it rescanned every floor above with alive() calls. The stadium is
28 x 28 x 13 and, being a balanced ring, never topples, so the loop never exits early: ~66k
alive() calls plus ~19k for the support rectangles, ~70-100 ms of GDScript per hit. Predates
#59 (it is #57's stadium meeting an old O(h^2 w d) check). Smaller: settle()'s loose scan and
Arcs._count/shed (~10k alive() each).
Fix 7f61740: one pass sums each floor's mass and centre, loads are running totals from the top;
direct _hp reads. Same result exactly (half-integer sums < 2^23 are exact in float). Sim change:
needs a kaiju-sim-review packet in the PR (transition: settle; invariant: same falls, same
order; evidence: the sim and flow suites' collapse checks unchanged).

## CI runs (capture.yml, gl_compatibility, --frames=1500 --slow=40)
- head (claude/stadium-stall @ 9ee5fe0): 39117043089
- base (claude/stadium-stall-base): 39117044976
- fix (7f61740): 39117126259
- tests.yml on claude/stadium-stall (fix): 39117124338
Read the logs: gh run download <id>, grep settle/lift_piece/slow f/worst. Probe prints the
settle() time of the whole stadium, lift_piece of one north rim arc, every frame over 40 ms
with Rampage.cost_usec per event kind, and worst/total per kind.

## Next
1. Fill in before/after ms; if sim.step dominates the slow frames, the fix stands; if
   fall_start/chunks_broken do, look at LandmarkBurst (_throw over parts, 40 debris) next.
2. Open the PR (base claude/look-options) with the sim-review packet; report to LEAD (<= 8 lines).
3. Delete claude/stadium-stall-base.

## Findings for the lead
- A per-settle check that loops over every floor above every floor is O(h^2 w d): fine for a
  3x3 tower, ~100 ms on a 28x28x13 landmark. Profile the sim with the biggest building in it.
- gh shares one 5,000/h API budget across all agents: wait for the reset, never poll in a loop.
- voxelize.py shells surfaces only: a solid disc bakes as a cap; build open parts as rings.
- A check bounded by the constant it tests passes when sabotaged: bound it by the bar.
- The dummy renderer keeps no MultiMesh transforms: test a builder's cells instead.
- After a squash merge, resyncing a stacked branch can silently take old copies of files it
  never touched: diff the result against the base before pushing.

## Rules learnt the hard way
- gdlint: 400 lines per file, 4 arguments; gdformat writes CRLF on Windows (sed it off) and
  must run after the last edit (CI runs gdformat --check).
- A failing check must run (not fail to parse): land the classes first, wire them second.
- Post-demo queue from LEAD: rubble polish (broken wheel, ragged stadium stumps, heaps),
  landmarks E (spire) / F (megatower, needs a Performance look at ~816k voxels).
