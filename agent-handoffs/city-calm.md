# City-calm handoff, 2026-10-18 09:35
## State: running a check (gated CI: close-ups s1/s2 + 1080p trample clip, after UI #27 4K run)

## Task
Role city-calm (helper). Lead: "Kaiju: Lead" (local_106fc100). Director asleep: no questions
to him; anything sim (destructible props, green lots) goes to the lead.
- DONE: #26 calm streets (D-054), #28 export-windows, #30 ci-export, #37 no empty ground
  (D-062, squash 2b241df).
- DONE: D-065(b) green-lot table sent to the lead (notes no-empty-space/D-065b_green_lot_table.md):
  0/8/12/15% green lots: tree end 4.46/4.88/5.08/5.18 h, evolve1 0.59/0.64/0.67/0.64 h.
- NOW: D-065(a), director 06:2x "make sure there are a believable amount of trees, bushes,
  floral areas, parks, gardens, playgrounds throughout the city". Presentation only, all
  crushable; separate PR off look-options; evidence = BEFORE/AFTER game-cam stills s1 + s2,
  2x crops of a park, an avenue of trees, a playground, a 3 s trample clip, frame cost.

## Branch and commit
claude/greenery off look-options b8fb42f; worktree
C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/greenery. Head c07b4f0 (pushed).
(A stray local branch claude/greenery-before exists; harmless, delete when allowed.)

## What changed
- scenes/city_greenery.gd (new, CityGreenery): plant() runs last in CityDecor._ready (decor
  RNG drawn after everything else): avenue street trees (city.street_tree_gap [8, 15],
  street_tree_clear 3, clear of lamps/diagonal/buildings); park garden (border hedge, path
  hedges, flower beds city.park_flower_beds per 100 m2, playground on
  playground_pad = south-west corner, city.playground_size 4); front-yard hedges
  (city.yard_depth [0.6, 1.6]); PALETTE merged into the decor palette.
- scenes/city_decor.gd: green counts, lamp spots, park trees kept off the playground pad.
- tests/lib/city_green.gd + run_city_tests.gd _check_greenery (inside the D-062 loop);
  floor city 12 -> 18. tools/coverage_probe.gd prints the green numbers.
- tools/capture/capture_green.gd: close-ups (park, playground, avenue) + --trample clip.

## Evidence so far
notes = C:\Users\DANTE\.claude-desktop-work\side-session-notes\local_9fac90d2-...\greenery
- city_red_before.log: 6 FAILs on the old decor; city_after.log green; run_tests_all.log all
  green (smoke 27, sim 39, powers 24, tentacles 18, city 18, growth 24, load 6, flow 113).
- green_numbers_after.txt (stage 1 / Behemoth, 3 map_seeds): trees 123-139 / 131-137 per km
  of avenue; parks 1 / 2, all with playgrounds; park bushes 21-28 / 44-52; green blocks
  4-8% / 4-6% and furthest building 55-71 / 83-105 m from a park (both need D-065(b)).
- CI chain running (captures.log): before_s1/2, after_s1/2, close_s1/2, trample (720p, 5 s).

## Next
1. Labelled BEFORE/AFTER side-by-sides; 2x crops of park, playground, avenue (AFTER;
   BEFORE close-ups not possible: a temp branch push was declined); check the trample clip.
2. Frame cost on the lead's GPU slot (timed capture_growth, as for #37).
3. PR into look-options with D-065 (Board and log), report to the lead.

## Attempts (fix-loop record)
- Playground first went in the corner with fewest trees, but those trees were already planted
  (they would poke through): fixed by a fixed pad the park's trees skip.
- `git --work-tree=<tmp> checkout <branch> -- .` rewrote my index (not files): reset -q fixed.

## Open decisions
D-065(b) green lots: director's morning call (lead holds the table).

## Since 07:55
- Frame cost done (GPU within noise, CPU +0.1-0.3 ms, tris +0.2-0.7%; notes greenery/timed/).
- Self-QA art pass 4471398: bushes bigger, blooms scattered (city.flower_bloom), swing chains,
  trample walks through the trees (OFF_PATH 0.25). Lead: contact trample -> 618d3ab
  CityDecor._process flattens props within city.trample_body x body_scale (body only: rampage.gd
  and city_view.gd are at the 400-line cap). Avenue close-up on a row of street trees c30a92d.
- CI captures: one at a time overall; wait for UI #27's 4K run (lead 09:21).
- after2_s1 (4471398) and close2_s1 (4471398) downloaded; after2_s2 downloading.

## Running jobs
bkwthdxxy: gated CI chain -> notes greenery/close3_s1, close3_s2, trample2.

## Findings for the lead
- Never use `git --work-tree=X checkout <ref> -- .` to export a tree: it rewrites the current
  index. Use `git archive <ref> | tar -x -C X`.
- A worktree removed under a live session sends its next git command into the main checkout;
  check `git rev-parse --show-toplevel` first.

## Rules learnt the hard way (under 10 lines)
- Branch off origin/claude/look-options; confirm the worktree exists before git commands.
- `git lfs pull` before suites/exports in a fresh worktree; never mid-run.
- Template builds start fullscreen: seed settings.cfg fullscreen=false for smoke runs.
- gdlint: 400-line file cap, <=4 function args, public vars before private.
- Never chain commit/push after a Godot --check-only through grep: test its output first.
