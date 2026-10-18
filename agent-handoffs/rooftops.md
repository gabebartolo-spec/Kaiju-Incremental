# Rooftops handoff, 2026-10-18 (D-076 density)
## State: running a check (baseline pacing on the #50 head; waiting for PR #50 to merge)

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

## Done so far
- PR #50 (military AI) still OPEN at da48ea0; its sim equals 96d804d (only a capture doc line
  differs). Background watcher waits for it to leave OPEN.
- Baseline: snapshot of 96d804d in scratchpad snap_base/ with tools/pacing_dmg.gd (copy of
  military-ai's, plus heli + rooftop totals); running reptilian pacing with DUMP=dump_base.json
  -> pacing_base.txt. Scratchpad: %TEMP%/claude/C--...festive-jemison-3fb73c/ff78c0a3.../scratchpad
- roof_replay.gd (scratchpad): replays dumped states with CANDS (JSON overrides) and prints
  damage by source, squads placed, volleys/s, volleys/s in range, busy-second share.
- Uncommitted -> committed with this file: scenes/rooftop_view.gd draws the squads nearest the
  kaiju first (_nearest_first), so with more squads than max_drawn the firing ones are drawn.

## Findings
- #50 table: rooftop damage/run young 5.6, Behemoth 10.6, Colossus 0, Apex 0 (squads spread
  over the whole huge city rarely meet the kaiju). Behemoth ~0.3 volleys/s average now.
- Per-stage tank_damage lives in growth.stages (Behemoth 6, Colossus 10, Apex 11; young uses
  base army.tank_damage 4): the obvious compensation lever (existing keys).

## Next
1. Read pacing_base.txt + dump_base.json; replay candidates (max_by_tier, chance,
   fire_interval, maybe range) and pick the tank_damage compensation per stage.
2. After #50 merges: merge look-options into this branch, re-verify baseline unchanged.
3. Tests (floors), hit gate + known-bad control, pacing, sim packet, clip, PR, report LEAD.

## Don't touch
scenes/biped_swing.gd, scenes/gait_clip.gd, scenes/city_ground.gd, scenes/ui_kit.gd.
