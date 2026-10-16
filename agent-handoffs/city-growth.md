# City-growth handoff, 2026-10-17 03:00
## State: running a check (cost-tuning pacing run in background)

## Task
D-039: the city grows with each evolution + economy re-tuned for 3-5 h active play (scripted
player ~3 h), first species power by run 3, no flat grind. Done = PR into claude/look-options,
CI green, pacing tables per species/stage in the PR body, CI stills per stage, this handoff,
results to the lead (local_9fac90d2-fae7-4940-b4ac-144a87f28e6e).

## Branch and commit
claude/city-growth-e79d28 (worktree .claude/worktrees/city-growth-e79d28), fast-forwarded to
merged origin/claude/look-options 55ce218 (capture.yml live). Pushed.

## What is built (WIP commit)
- sim/city_gen.gd: cfg.districts [42,66,105,166] = nested districts; the plan always spans all
  of them (ring avenue per district, grow lines from map_seed+2), cfg.half = playable one.
  Blocks carry "district"; generate() fills innermost district first (lots keep their place
  across stages); one park per district.
- sim/city_lots.gd: district_lot_grow [0,1,2,3] = bigger lots in later districts.
- sim/city_growth.gd: CityGrowth.tuning_for(tuning, tier) deep copy + growth.stages overrides;
  layout(tuning, tier, rng); stage_count.
- data/tuning.json: districts, lot grow, 9 cores, army.spawn_radius 50, growth.stages (city
  half/coast_z/max_height/tower_chance; army and air per stage; stage 1 air.max 0).
- sim/army.gd: tanks spawn spawn_radius round the kaiju.
- scenes/main.gd + rampage.gd use the stage tuning/layout (game-flow told by message).
- tools/pacing.gd: uses stages, per-stage table, --flat. tools/capture/city_stats.gd per stage.
- tools/capture/capture_growth.gd (aerial + kaiju still per stage, perf print).
- Temp capture workflow removed; stills via tools/capture/ci_capture.sh capture_growth.gd.
- tests/run_growth_tests.gd (floor 23), registered in run_tests.sh, ci_shards, expected_checks.
  NOT RUN YET. Cost band check (1.5M-4M total) is a placeholder: set from final costs.

## Unfinished changes
- data/upgrades.json is being rewritten by the scratch tuner (uncommitted, in flux):
  scratchpad scale_costs.py <orig> <out> f1 fe1 f2 fe2 f3 fe3 f4 (stage multipliers; first
  levels of young nodes kept), pace_all.sh <tag> factors. Original copy: scratchpad
  upgrades_orig.json (= git HEAD version).
- Next: iterate factors to ~3 h scripted, commit costs; run tools/run_tests.sh (all suites);
  PR with tables + stills.

## Evidence so far (pacing, reptilian, ORIGINAL costs)
- Districts x2 area (58/78/104): Behemoth/Colossus cities flattened in one run (city_fallen) -> too small.
- 42/66/105/166 + lot grow: runs end on time; young 7->80%, Behemoth 67->95%, Colossus 59->99%,
  Apex 72-79%; rubble/run young 0.1-1.3k, Beh 3.3-5.6k, Col 13-22k, Apex 30-34k; tree 0.52 h.
- city_stats: stage 1..4 buildings 147/367/776/1577, chunks 9.5k/28k/89k/178k (perf risk at Apex,
  D-032 says looks first; record capture timings in PR).

## Attempts
- heredoc python through Bash failed once on quotes: write scripts to scratchpad with Write.
- `git show origin/x:path` in Git Bash needs MSYS_NO_PATHCONV=1.

## Open decisions
- None for the director yet. Tier-1 city changed slightly (alleys/lots re-rolled because the plan
  now spans all districts); same rules, flag in PR.

## Running jobs
CI capture dispatch (ci_capture.sh capture_growth.gd, all 4 stages) -> $TEMP/cg_stills.
Background pacing run "a" (factors 2.2 2.5 6 6 8 8 8), output scratchpad pace_a.txt. Godot:
console exe on Desktop, APPDATA=$TEMP/cg_appdata, headless only (director gaming).

## Findings for the lead
- Destroyed area per run scales with the kaiju's crater (body scale x9 young->Apex), so the
  city's area must grow ~x2.5-3 per evolution or runs end "city_fallen" and rubble goes flat.

## Rules learnt the hard way
- One Godot at a time while the director games; headless + --audio-driver Dummy.
