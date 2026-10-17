# Demo handoff, 2026-10-18 03:42
## State: running a check (suites + pacing for balance D on claude/balance-d)

## Task
Minimal playable demo. Plan approved by the director 03:35:
C:\Users\DANTE\.claude\plans\pasted-content-id-a4a2-i-want-glistening-bubble.md (copy its phases into
docs/ROADMAP.md in the P1 PR if the lead agrees). Director decisions (log as D-050 in the P1 PR body):
1. Croc titan (reptilian) is the only playable species.
2. Demo ends after the first evolution (Behemoth, ~20-30 min) on a "demo complete" card.
3. Croc baby + adolescent get NEW models from the croc titan design before the demo ships.
4. SFX unpaused for the demo (PR #8, ability-vfx).
5. Croc titan adult is teased on the end card (roar), never played (stage_for: tier 3 = adult).
Phases: P1 balance D data (me) · P2 D-047 adult clips (blender-reptile) · P3 Tripo baby/adolescent
(lead + blender-reptile) · P4 revive #8 SFX · P5 demo slice (tuning `demo` section: species allow-list,
end node evolve1; species_select filter; main.gd -> new scenes/demo_end.gd) · P6 local Windows export
from look-options · P7 director playtest.

## Branch and commit
claude/balance-d from claude/look-options ed1d2d9 (local; origin/look-options is at dbff208, 7 handoff
commits behind local: the lead session owns that push). Not pushed, no PR yet.

## Unfinished changes (committed with this handoff)
- data/upgrades.json: all 31 cost arrays x1.27, r_beam x0.6 (0.762 total), i_brood x1.8 (2.286 total),
  rounded to int.
- data/species.json: reptilian speed 5.5, ability_damage 36, ability_range 11; insectoid ability_damage 18,
  ability_cooldown 6.5.
- data/tuning.json: cone_half_angle_deg 36.
Expected pacing (PR #16 table D): ceph 3.70 h / rep 4.43 h / insect 3.26 h.

## Running jobs
Background bash in session "Game demo planning": GODOT=C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/
Godot_v4.7.2-stable_win64_console.exe tools/run_tests.sh, then pacing.gd per species. Logs in the scratchpad
(C:/Users/DANTE/AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental/
a71b8659-f570-46fa-a36b-eb259807c651/scratchpad/{tests,pacing_*}.log). First attempt failed: `godot` not on
PATH; rerun with the full path. No override.cfg, no windowed Godot.

## Next
1. Read logs: all 8 suites at floors (smoke 27, sim 39, powers 24, tentacles 18, city 5, growth 24, load 6,
   flow 76); pacing hours-to-evolve1 for reptilian (demo target 20-30 min) and totals vs table D.
2. Push, open PR into claude/look-options with the template: evidence = suite counts + pacing table;
   Board and log = D-050 in full; [MERGE NOTE] floors unchanged, director gate approved (D-049/D-050).
3. Lead session "Kaiju Incremental game" was told the plan and asked to brief P2-P4 helpers (message
   e159e529, 03:40); confirm it did before briefing anyone yourself.
4. Worktrees: 7 live (cap 4); city-growth, game-flow, kaiju-look-test are clean/detached/merged -> remove.

## Open decisions
None for the director right now. If reptilian evolve1 lands outside 20-30 min, propose one lever (evolve1
cost) with the measured number, ask-the-director style.
