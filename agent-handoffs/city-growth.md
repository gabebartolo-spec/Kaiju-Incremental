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

## Evidence so far
- Pacing a (costs x2.2/2.5/6/6/8/8/8, districts 42/66/105/166): reptile 2.39 h, insect 1.19 h,
  ceph 1.82 h; insect flattens Colossus+Apex cities every run (flat grind).
- Pacing b (districts 42/70/125/210, +6 Apex-ring cores, outer_half 360; same costs): reptile
  2.29 h (Colossus 43->85%, Apex 13/14 defeated), insect 1.17 h (Colossus/Apex 100% every run),
  ceph 1.68 h. Insect = species-balance issue, flagged to lead (not fixable by city size).
- city_stats now: buildings 140/313/925/2428, chunks 11.9k/25k/103k/355k (perf risk at Apex).
- Uncommitted tuning.json: districts 42/70/125/210, new cores, outer_half 360, Apex army
  tank_damage 11 / heli damage 7. Scratch results: pace_a.txt, pace_b.txt.

## Attempts
- heredoc python through Bash failed once on quotes: write scripts to scratchpad with Write.
- `git show origin/x:path` in Git Bash needs MSYS_NO_PATHCONV=1.

## Open decisions
- None for the director yet. Tier-1 city changed slightly (alleys/lots re-rolled because the plan
  now spans all districts); same rules, flag in PR.

## Running jobs
Pacing "d" (factors 2.9 4 8.5 9 15 15 15) -> scratchpad pace_d.txt. CI stills run
38923419011 (OLD sizes 42/66/105/166): recapture after final sizes are committed.

## Findings for the lead
- Pacing c (factors 2.9 4 11.4 11.4 15 15 15): reptile 4.07 h, insect 1.97 h, ceph 2.93 h
  (median OK); Behemoth stage flat for reptile (50 runs, 4.0->4.5k) -> d shortens it.
- Ablation (tools/ablate_scratch.gd, uncommitted scratch; Colossus kit in Colossus city):
  insect 96% -> 60% without Leap Slam (climb/glide ~0 for the bot); reptile 43% (tail ~2 pts);
  ceph 63% (limbs within noise). Lead asked for a concrete +-20% balance proposal in the PR.
- Destroyed area per run scales with the kaiju's crater (body scale x9 young->Apex), so the
  city's area must grow ~x2.5-3 per evolution or runs end "city_fallen" and rubble goes flat.

## Rules learnt the hard way
- One Godot at a time while the director games; headless + --audio-driver Dummy.
