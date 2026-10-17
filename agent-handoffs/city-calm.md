# City-calm handoff, 2026-10-18 04:27
## State: awaiting lead (PR open into claude/look-options; lead QA + fresh critic next)

## Task
Director 2026-10-18 03:53: "remove the level crossing hellscape, i get that tokyo is a
reference but this is too much". Make the streets calm and readable from the game camera.
Lead: "Game demo planning" (local_106fc100, 03:56 on), not local_56c0390b.

## What the director saw
Zebra crossings on every arm of every junction along every avenue (rings +-42/+-70 and the
inner avenue), plus a mid-block zebra on every avenue segment longer than 18. No railway
code exists. Labelled 2x crop: notes/city-calm/before_s1_labelled_2x.png.

## Branch and commit
claude/city-calm-streets off claude/look-options (ed1d2d9). 54e9f16 is the fix:
scenes/city_ground.gd zebra_junctions() (MID_BLOCK gone), data/tuning.json
city.zebra_junctions = 1, tests/run_city_tests.gd _check_calm_streets, floor city 5 -> 6.

## Callers
The "crossings" in traffic/police/street_life/city_decor are road-graph nodes, not paint.
Unchanged.

## Evidence
notes = C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2-...\city-calm
- CI runs: before s1 39051748926, before s2 39051918842 (look-options ed1d2d9); after s1
  39052207839, after s2 39052370448 (54e9f16). 1080p game camera, seed city 0.
- side_by_side_s{1,2}.png, junction_2x_before_after_s{1,2}.png, {before,after}_s{1,2}_game.png
- Suites: smoke 27, sim 39, powers 24, tentacles 18, city 6, growth 24, load 6, flow 76,
  self-test ok (logs run_tests_*.log in notes). The new check was red at key 99.

## Attempts (fix-loop record)
none on the feature. The first flow run timed out because of LFS font pointers (see rules).

## Open decisions
1 zebra junction vs 0: taste call for the lead's critic and the director.

## Running jobs
none for city-calm. Next in queue: export-windows (lead task, same worktree, new branch).

## Findings for the lead
- ci_capture.sh picks the newest workflow_dispatch run without filtering by branch, so with
  agents dispatching seconds apart it can download another agent's run. Verify with
  `gh run view <id> --json headBranch,headSha` (this time all four were mine).

## Rules learnt the hard way (under 10 lines)
- The app's worktree was cut from local main (lead commits); branch off origin/claude/look-options.
- `git lfs pull` BEFORE any suite run in a fresh worktree; pulling during a run makes the
  re-import segfault (exit 139).
