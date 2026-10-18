# Landmarks handoff, 2026-10-19 10:10
## State: running a check (CI probe run 39123908001: 1500 frames, --no3d, at c8d999b)

## Task
Landmarks role, reporting to LEAD ("Kaiju: LEAD (demo build, merges, QA)", local_106fc100...).
PR bodies <= 8 lines, never merge. Godot allowed again (LEAD): headless first; windowed only
off-screen with the no_focus override.cfg, removed after.
- #57 landmark sites and #59 stadium matches (D-078): both MERGED into claude/look-options.
- #75 stadium stall fix MERGED, in the demo exe (44f56fd, D-089).
- One live worktree: ../Kaiju-Incremental-wt/stall-probe, branch claude/stall-probe (c8d999b).
- Now: LEAD's stall job. Windowed dry-run at 329e708 showed 80-110 ms stalls every ~0.7 s while
  the stadium falls, the same with the crowd off. Asked: find the cause, a CI timing probe at
  look-options 8c24654 and the pre-#59 base 5bc6b44, the smallest fix with before/after ms,
  report in <= 8 lines.

## Branches
- claude/stadium-stall (from look-options 2d2b54a; no scene/sim/data diff vs 8c24654):
  9ee5fe0 probe tools/capture/probe_stadium_stall.gd; 7f61740 the fix (sim/structure.gd).
  5d3f4b0 second fix (ground flood + Arcs counts over Structure.standing()). PR #75.
- claude/stadium-stall-base (5bc6b44 + probe): deleted after its run.

## Result (CI probe, sim.step on each stadium hit, every 21 physics frames)
head 8c24654 70-80 ms; pre-#59 5bc6b44 70-81 ms (#59 not the cause); topple fix 25-34 ms;
5d3f4b0 10.6-12.9 ms. Whole-stadium settle(): 70.0 -> 28.1 -> 5.9 ms. View side per hit:
fall_start <= 2.5, chunks_broken <= 1.2 ms (not the stall). tests.yml 39121385726 green.
Local headless (director PC): sim.step worst 57.0 -> 10.0 ms, settle() 40.7 -> 3.6 ms.
Probe at 1500 frames times out on CI's software renderer: use --frames=250.

## Cause
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
- fix (7f61740): 39117126259; tests 39117124338 green
- fix2 (5d3f4b0): 39121405300; tests 39121385726 green
Read the logs: gh run download <id>, grep settle/lift_piece/slow f/worst. Probe prints the
settle() time of the whole stadium, lift_piece of one north rim arc, every frame over 40 ms
with Rampage.cost_usec per event kind, and worst/total per kind.

## Next (LEAD 2026-10-19, after #75)
LEAD's dry-run probe at 44f56fd: settle() 5.4 ms, but sim.step worst 43.9, rooftop_fired
worst 62 ms, 205x "on_event on Nil" at powers_view.gd:160. Asked: probe as the game builds it,
CI at 1500 frames, report sim.step and per-event worst/total (<= 6 lines), new PR if code changes.
- The on_event error does NOT reproduce headless at 5574366 (0 in 300 frames); Rampage is set
  up exactly as main.gd does (setup, then into the tree), so PowersView gets its rooftops.
- This PC is too noisy to time (sim.step worst 35-140 ms run to run; first stadium shed
  showed fall_start 18-63 ms, likely first-use cost: check on CI).
- Probe now has --no3d (root.disable_3d) so 1500 frames fit CI; prints frames over 16.7 ms
  per kind. Then: report to LEAD; open a probe-only PR if LEAD wants it kept.

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
