# City-calm handoff, 2026-10-18 04:10
## State: running a check (all suites local; AFTER captures on CI)

## Task
Director 2026-10-18 03:53: "remove the level crossing hellscape, i get that tokyo is a
reference but this is too much". Make the streets calm and readable from the game camera.
Lead: "Game demo planning" (local_106fc100), took over from local_56c0390b at 03:56.

## What the director saw
BEFORE stage 1 game camera: zebra crossings on every arm of every junction along every avenue
(ring avenues at +-42/+-70 and the inner avenue), plus a mid-block zebra on every avenue
segment longer than 18. No railway code exists; "level crossing" = these zebras.
Labelled 2x crop: notes/city-calm/before_s1_labelled_2x.png (J junction, M mid-block, D dashes).

## Branch and commit
claude/city-calm-streets off claude/look-options (ed1d2d9). 54e9f16: scenes/city_ground.gd
(MID_BLOCK and mid-block zebras gone; zebras only at city.zebra_junctions avenue x avenue
junctions nearest the centre), data/tuning.json city.zebra_junctions = 1, tests/run_city_tests.gd
_check_calm_streets (shown red at 99: "zebras at 63 junctions"), floor city 5 -> 6.

## Callers
traffic.gd / police.gd / street_life.gd / city_decor.gd "crossings" are road-graph junction
nodes (CityGen nodes), never the painted zebras: nothing pathfinds to or spawns at paint.
Unchanged, none removed.

## Evidence so far
notes = C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2-...\city-calm
- before_s1/ (run 39051748926), before_s2/ pending, after_* pending
- run_tests_54e9f16.log pending

## Attempts (fix-loop record)
none

## Open decisions
1 junction vs none: went with 1 (the downtown avenue crossing); key can go to 0.

## Running jobs
CI capture runs (capture.yml) for before/after; local tools/run_tests.sh.

## Findings for the lead
- ci_capture.sh picks the newest workflow_dispatch run, not filtered by branch: with two
  agents dispatching within seconds it can download the other agent's run. Check the run id.

## Rules learnt the hard way (under 10 lines)
- The worktree was cut from local main (lead commits); branch off origin/claude/look-options.
