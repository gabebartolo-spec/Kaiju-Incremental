# City-growth handoff, 2026-10-17 12:45
## State: awaiting lead (PR #16 fog fix pushed; director questions tabled)

## Task
D-039: the city grows with each evolution + economy re-tuned for 3-5 h active play (scripted
player ~3 h on the median species), first species power by run 3, no flat grind. Done = PR into
claude/look-options, CI green, pacing tables per species/stage in the PR body, CI stills per
stage, insectoid balance note (lead asked: which nodes drive it, a +-20% proposal), this
handoff, then tell the lead (local_9fac90d2-fae7-4940-b4ac-144a87f28e6e).

## Branch and commit
claude/city-growth-e79d28, merged origin/claude/look-options 6535330, pushed. PR #16 into
claude/look-options (bound, Auto-fix on).

## What is built
- sim/city_gen.gd: cfg.districts [42,70,125,210]; the plan always spans every district (ring
  avenue each), cfg.half = the playable one; blocks carry "district"; generate() fills
  innermost first; one park per district.
- sim/city_lots.gd: district_lot_grow [0,1,2,3]; tower and pencil heights always drawn (a
  stage's tower_chance/max_height no longer shifts later lots: the growth test caught it).
- sim/city_growth.gd: CityGrowth.tuning_for / layout / stage_count.
- data/tuning.json: districts, lot grow, 15 cores, outer_half 360, army.spawn_radius 60,
  growth.stages (half, coast_z, max_height 26/32/40/48, tower_chance; army + air per stage;
  stage 1 no helicopters, 2/4/6 after).
- sim/army.gd: tanks from the edge in a small city, round the kaiju once the edge is > 60 away.
- data/upgrades.json: costs = pacing "d" factors (young x2.9 except first levels, evolve1
  x4 = 1200, Behemoth x8.5, evolve2 22000, Colossus x15, evolve3 300000, ultimates x15).
- scenes/main.gd + rampage.gd run on the stage tuning/layout (game-flow knows; PR #14).
- tools/pacing.gd per-stage tables, --flat; city_stats.gd per stage; capture_growth.gd.
- tests/run_growth_tests.gd (23 checks, floor 23). Fixed old fixtures: sim "longer rampage"
  now hide 5 (both runs reach the clock); flow heli check gives the run the base air wing.
- Local full run: smoke 12, sim 39, powers 24, tentacles 17, city 5, growth 23, flow 26,
  harness self-test: all green.

## Unfinished changes
None. Costs = pacing "e" (median ceph 2.94 h, reptile 3.94 h, insect 1.93 h). gdlint/gdformat
clean locally (pip gdtoolkit 4). Stills for stages 1-2 committed in
docs/captures/2026-10-17-city-growth/.
- Pending: stages 3-4 stills (`tools/capture/ci_capture.sh capture_growth.gd -- --stage=3
  --quick`, then 4) and CI checks: GitHub Actions refuses to start jobs ("recent account
  payments have failed or your spending limit needs to be increased"). Director's to fix.

## Evidence so far
- Pacing d (before the lots fix): reptile 3.77 h, insect 1.78 h, ceph 2.70 h; first power
  after run 2 for all. Final numbers re-run in pace_final.txt (layouts changed slightly).
- Ablation (Colossus kit, Colossus city): insect 96% -> 60% without Leap Slam; climb/glide ~0
  for the scripted player; reptile 43%; ceph 63%.
- city_stats (before the lots fix): chunks 11.9k / 25k / 103k / 355k (perf risk at Apex).

## Attempts
- Districts x2 area: cities flattened every run -> x3 area per stage.
- Old single CI stills run (all stages in one job) ran >1 h and was cancelled: one run per stage.

## Open decisions
- Species balance (insect ~2x) is for the lead/director after this PR; not fixed here.

## Running jobs
None. Lead review fix done: stage-scaled fog (growth.stages city.fog_scale 1/0.6/0.34/0.2 and
far_haze; CityView fog_density x fog_scale; growth check -> floor 24). All 12 stills (aerial,
kaiju, game camera) + board_fog_before_after.png committed; stages 1-2 CI (39006401376,
39006406352), 3-4 GPU (override.cfg deleted, no Godot left). Load note for the lead's
follow-up: views already threaded; prime suspect BuildingView.party_walls O(n^2) on the main
thread (5.9M pairs at Apex). Balance D and the Apex height wait for the director.

## Findings for the lead
- A seeded generator that draws a number only on some branches shifts every later draw when a
  tuning changes the branch; draw unconditionally (growth test "lots kept" caught it, fixed).
- Destroyed area per run scales with the kaiju's crater, so city area must grow ~x3 per
  evolution or runs end city_fallen and rubble per run goes flat.

## Rules learnt the hard way
- One Godot at a time while the director games; headless + --audio-driver Dummy.
- `git show origin/x:path` in Git Bash needs MSYS_NO_PATHCONV=1.
