# Rooftops handoff, 2026-10-18 (D-076 density)
## State: running a check (re-baseline pacing on #50 head a0d3f36 -> scratchpad pacing_b2.txt / dump_b2.json)

## Decision (FINAL, LEAD 2026-10-18): option A = D-076a
Tanks unchanged. More squads + shorter interval; scale damage_by_tier down PER TIER so each stage's
total stays within ±5% of baseline. PR table per stage: volleys/s, rifle HP/run, total vs baseline.
Log D-076a in "Board and log". HUD: there is no hit flash for any damage; a ~0.15 HP chip shows no
bar tick. LEAD: NO HUD change (UI session's area, D-061). Gate instead: in the Behemoth CI clip
at 2x the hide spark is visible on most volleys in range; 2x crops of three volleys in the PR.
## Superseded: LEAD first approved the tank_damage offset (option B); replaced by A
LEAD: edge reach, more squads + shorter interval, offset per-stage tank_damage, ±5%; PR needs a
volleys-per-run table per stage + CI clip of Behemoth under rooftop fire. LEAD says when #50 merges.
## Earlier decision note (notes folder rooftops-density/ has all tables)
Same chip + ±5% total + several volleys/s cannot all hold. Behemoth volley ~1.6 hp (0.5 x threat ~3).
40 squads @1.0 s: 2.3 volleys/s in range (47% of run), rifles 120 hp/run, total 294 vs 197.
60 squads @1.0 s: 3.0 volleys/s in range, rifles 178 hp/run.
A (recommended) chip to ~1/10, tanks unchanged; B keep chip, Behemoth tank shells 6 -> ~2;
C keep chip, total +~50% (measure pacing).

## Who
Session "Rooftop density" started by "Kaiju: Lead" (local_106fc100-d2a4-4091-bc9a-4bda31df13ac).
Worktree .claude/worktrees/festive-jemison-3fb73c, branch claude/rooftop-density (off
origin/claude/look-options 0817cf6). PR into claude/look-options; do not merge.

## Task (D-076, director 2026-10-18)
"more squads, more often", same chip damage per volley. Raise army.rooftop max_by_tier / chance,
shorten fire_interval so several volleys a second cross the screen at Behemoth. Hold total damage
per run per stage (tank + heli + rooftop) within ±5% of post-#50, and reptilian pacing within ±5%.
Evidence: before/after tables, 3 s 1080p Behemoth game-camera clip (ask LEAD for the GPU slot;
CI capture.yml one at a time), rooftop_hit_gate (and its known-bad control still failing),
kaiju-sim-review packet. New tuning keys inside army.rooftop only; new checks in tests/lib.

## Baseline (post-#50 sim = 96d804d snapshot; #50 head da48ea0 differs only in a capture doc line)
Reptilian pacing: evolve1 0.59 h, tree 4.52 h; young ended 7/22 time/defeated. Total damage/run
(tank+heli+roof): young 179.8, Behemoth 197.5, Colossus 472.6, Apex 770.1.
Replay (28 states): roof dmg 5.6 / 8.7 / 0 / 0; Behemoth kaiju in range of a live squad 3% of the
run, Colossus/Apex 0%.

## Root cause (sent to LEAD)
Rifle reach was measured from the kaiju's centre (tanks: range + stomp_radius). Squads die to the
grown kaiju's own reach (Behemoth 7-18 u, Colossus 22-43 u) before they get a shot. fire_interval
1.0 alone: Behemoth 5.6 -> 5.7 volleys/run. Doubling squads alone: 15/run (0.2/s).

## Replay2 (edge reach, 28 states)
Shipped tuning: roof dmg 7.0 / 16.4 / 15.4 / 4.4 (total +-1/-1/+1/+0... Behemoth 190.8 vs 183 old
reach). Behemoth 30 squads, chance 0.9, interval 0.8: 0.95 volleys/s overall, 2.43/s while a
squad is in range (39% of the run), roof dmg 102 -> total 276 (+40%): tanks would have to drop
by ~60%. Squads are spread over the whole 146 u city; reach ~23 u covers ~8% of it.
Likely a director trade-off: several volleys/s at same chip => rifles become ~1/3+ of Behemoth
damage and tank shells must hit much softer. Put to LEAD with numbers once replay3 lands.

## Chosen (D-076a), committed 836b519
army.rooftop: chance 0.8, max_by_tier [20,48,48,60], fire_interval 0.8, damage_by_tier
[0.03,0.04,0.08,0.12]. Replay vs 96d804d baseline: totals -1.2/+2.3/+1.1/+0.1%; Behemoth
5.6 -> 107 volleys/run, 3.1/s in range (49% of run). Army.volleys counter + sim check "a Behemoth
rampage draws >= 1.0 volleys/s" (1.98 now; 0.29 on old tuning: fail_first_density_sim.log); sim floor 52.
#50 moved since: young stage army range 10.5, tank_damage 8, fire_interval 0.7 (+ sounds, #46
rifle sound in rooftop_view on look-options -> expect a small merge in rooftop_view.gd).
So re-baseline on a0d3f36 (snap_b2) and re-replay the chosen tuning (snap_b2 + edge reach) before
the PR tables; verify sim/ + data/ unchanged between a0d3f36 and the merged #50.

## Coordination
- "Kaiju: Sound effects" (local_24621710-3f9c-4f67-ae39-8fa4b6192106) adds a rifle sound gap
  (claude/rifle-gap, sfx.min_interval.rifle 0.3). Record the clip's audio after it lands, or merge
  claude/rifle-gap locally for the capture. They will send the PR number + head SHA.
- Capture tool: 7000a1f adds --typical (median busy spot) + edge reach; use --typical for the PR clip.
- Candidate snapshot snap_b2c = #50 head a0d3f36 + my sim/army.gd + tuning (patched).

## Branch changes
- committed 1348478: scenes/rooftop_view.gd draws squads nearest the kaiju first (_nearest_first).
- UNCOMMITTED -> committed with this file: sim/army.gd _step_squads reach = range +
  sim.stomp_radius(); tests/lib/sim_rooftops.gd new check "a squad fires at a Behemoth ... inside
  range + stomp": shown FAILING on the old reach (rooftops-density/fail_first_edge_reach_sim.log),
  passing on the new; sim floor 50 -> 51 (740e385).

## Scratchpad (%TEMP%/claude/C--...festive-jemison-3fb73c/ff78c0a3.../scratchpad)
snap_base/ (96d804d + tools/pacing_dmg.gd, roof_replay.gd, roof_life.gd), snap_c/ (same + edge
reach), dump_base.json, pacing_base.txt, replay1.txt, life1.txt, replay2.txt (pending).
Run: cd snap_x; APPDATA=<appdata_x> DUMP=<dump> CANDS='[{}...]' godot --headless --path . --script tools/roof_replay.gd

## Next
1. Read replay2; pick max_by_tier/chance/fire_interval for >= ~2-3 volleys/s in range at Behemoth;
   offset with growth.stages[n].army.tank_damage (young: base army.tank_damage) to hold ±5%.
2. After #50 merges: merge look-options in; tests + floors; hit gate + known-bad; pacing; packet;
   clip (LEAD GPU slot / CI capture.yml); PR; report LEAD (<= 8 lines).

## Don't touch
scenes/biped_swing.gd, scenes/gait_clip.gd, scenes/city_ground.gd, scenes/ui_kit.gd.
