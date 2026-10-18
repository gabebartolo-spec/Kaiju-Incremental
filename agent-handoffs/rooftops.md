# Rooftops handoff, 2026-10-18 (D-076 density)
## State: running a check (replay3: dense candidates, tiers 1-2 -> scratchpad replay3.txt; #50 still open)

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

## Branch changes
- committed 1348478: scenes/rooftop_view.gd draws squads nearest the kaiju first (_nearest_first).
- UNCOMMITTED -> committed with this file: sim/army.gd _step_squads reach = range +
  sim.stomp_radius(); tests/lib/sim_rooftops.gd new check "a squad fires at a Behemoth ... inside
  range + stomp" (must be shown failing on the old reach before trusting it). Floor sim +1 later.

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
