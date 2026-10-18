# City-calm handoff, 2026-10-18 14:00
## State: running a check (PR up for lead QA; final 2.5 trample clip waits on the demo capture queue)

## Task
Role city-calm (helper). Lead: "Kaiju: Lead" (local_106fc100). Director asleep: no questions
to him; anything sim goes to the lead.
- DONE: #26 calm streets (D-054), #28 export-windows, #30 ci-export, #37 no empty ground
  (D-062), D-065(b) green-lot table (lead), Landmarks city_gen review.
- NOW: D-065(a) greenery PR into claude/look-options (presentation only, all crushable),
  plus the lead's contact trample (CityDecor._process, city.trample_body 2.5 x body scale).
- NEXT: D-075 = D-065(b) at 8% green lots, its own PR after this merges: city.green_lot_share
  0.08 in CityGen/CityLots (data); parks/gardens/playgrounds/plazas spread so no building is
  more than ~2 blocks from one; crushable; pacing table near evolve1 0.64 h / tree 4.88 h;
  kaiju-sim-review packet (changes generation); city checks failing first.

## Branch and commit
claude/greenery, worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/greenery,
synced with look-options 89403b4. A stray local branch claude/greenery-before exists; delete
when allowed.

## What changed
- scenes/city_greenery.gd (new, CityGreenery): street trees on avenues, park garden (hedge
  border, path hedges, flower beds, playground on playground_pad), front-yard hedges.
- scenes/city_decor.gd: runs CityGreenery last; green counts; park trees skip the playground
  pad; _process trample (body only: rampage.gd and city_view.gd are at the 400-line cap).
- data/tuning.json city: street_tree_gap, street_tree_clear, garden_bush_gap,
  park_flower_beds, flower_bloom, playground_size, yard_depth, trample_body.
- tests/lib/city_green.gd (measure + check_city), called from the D-062 loop; city 12 -> 18.
- tools/capture/capture_green.gd: close-ups, --trample clip, --park-stills (from the east:
  straight down, a flattened tree looks the same as a standing one).

## Evidence (notes side-session-notes/local_9fac90d2-.../greenery/)
- city_red_before.log 6 FAILs; suites green after the sync (run_tests_merged.log).
- side_by_side_s{1,2}.png, crop_{park,playground,avenue}_s1_2x.png (CI).
- park_view_local/crop_park_{before,after}_2x.png: 9 of 56 park props flattened (local GPU).
- trample2 clip (run 39082162565, body 1.5). Final 2.5 clip + CI park stills: pending.

## Next
1. When the lead's queue clears (shell-hit, military-ai 720p, croc P3; nothing in progress or
   queued): CI park stills, then the 1080p trample clip; add them to the PR body.
2. Lead merges after a fresh critic; then remove this worktree and start D-075.

## Findings for the lead
- Trample evidence needs an oblique view: PropField flattens by squashing Y and widening XZ,
  so from straight above nothing seems to change.

## Rules learnt the hard way (under 10 lines)
- Branch off origin/claude/look-options; confirm the worktree exists before git commands.
- `git lfs pull` before suites/exports in a fresh worktree; never mid-run.
- Template builds start fullscreen: seed settings.cfg fullscreen=false for smoke runs.
- gdlint: 400-line file cap, <=4 function args, public vars before private.
- Test a Godot --check-only's output before committing.
- Local windowed Godot: the focus-guard hook needs the no_focus override.cfg in place first.
- CI captures follow the lead's queue; a gated loop must be stopped when the queue changes.
