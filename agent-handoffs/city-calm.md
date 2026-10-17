# City-calm handoff, 2026-10-18 05:58
## State: running a check (D-062 BEFORE/AFTER captures on CI); D-065 greenery queued next

## Task
Role city-calm (helper). Lead: "Kaiju: Lead" (local_106fc100). Director asleep from 06:4x:
no questions to him; sim changes (destructible props) go to the lead.
- DONE: #26 calm streets (D-054), #28 export-windows, #30 ci-export (artifact smoke PASS).
- NOW: D-062, director 05:27 "there should never be vast empty spaces with nothing to smash or
  kill". Arena cells need smashables, band cells (past the edge, as far as the camera sees)
  need dressing; both floors 0; 3 map_seed cities; stills, crops, frame cost; PR to the lead.
- NEXT: D-065 (director 06:2x): believable trees, bushes, floral areas, parks, gardens,
  playgrounds; targets in tuning; everything crushable; separate PR. Brief in the lead's
  message: street trees every 8-15 m on avenues/main streets, 8-15% green lots, none more than
  ~2 blocks from one, yards where lots have yard_chance; parks count as filled cells.

## Branch and commit
claude/no-empty-space off origin/claude/look-options 3df0f6b, worktree
C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/no-empty-space.

## What changed (D-062)
- tests/lib/city_coverage.gd: 10 m cells over arena + city.view_beyond (30).
- tests/run_city_tests.gd _check_no_empty_ground: stage 1 + 2 x map_seed 7301/1234/98765,
  floor city 6 -> 12.
- scenes/city_decor.gd: parked cars run past the edge to arena + view_beyond (no lamps there);
  short blocks past the edge get a mid-kerb car; cars may stand where a street runs into the
  diagonal past the edge; the diagonal's kerb trees run on past the edge.
- data/tuning.json: city.coverage_cell 10, city.view_beyond 30; street.parked_chance 0.7,
  parked_chance_beyond 0.9, parked_gap [1.9, 3.2], lane_stop_chance 0.12.
- tools/coverage_probe.gd prints the maps.

## Evidence so far
notes = C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2-...\no-empty-space
- Red on the original decor (city_red_original_decor.log): empty past the edge, stage 1
  17/17/12, Behemoth 19/13/12; arena 0 everywhere. Green: all 0 (city_green.log).
- All suites green (run_tests_all.log): smoke 27, sim 39, powers 24, tentacles 18, city 12,
  growth 24, load 6, flow 100, self-test ok.
- Camera past the arena edge: stage 1 south 14, sides 22-50, north 37 m; Behemoth 16.5,
  27-67, 51 m. The kaiju is clamped to half + 2.5.

## Next
1. CI captures (capture_growth --stage=1/2 --quick, 1920x1080): BEFORE on look-options,
   AFTER on this branch; labelled stills; 2x crops of the ring and the south band.
2. Frame cost: local timed capture_growth run after the lead's GPU go (~06:35).
3. PR with D-062 in Board and log; report to Kaiju: Lead (<=8 lines). Then D-065.

## Attempts (fix-loop record)
- Coverage measure: 30 m cells found nothing; 10 m used. Rect sampling first skipped far edges
  (inflated empties to 26); fixed by sampling edges too.

## Open decisions
none (the lead decided: dress the band).

## Running jobs
CI capture runs (see notes).

## Findings for the lead
- A worktree removed under a live session sends its next git command into the main checkout
  (05:28, restored at once). Check `git rev-parse --show-toplevel` first.
- Seeds.make("city", n) does not change the street plan; city.map_seed does.

## Rules learnt the hard way (under 10 lines)
- Before any git command in a worktree, confirm it still exists (show-toplevel).
- `git lfs pull` before suites/exports in a fresh worktree; never mid-run.
- Template builds start fullscreen: seed settings.cfg fullscreen=false for smoke runs.
