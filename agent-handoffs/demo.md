# Demo handoff, 2026-10-18 03:48
## State: running a check (pacing x3 species; suites green; PR not yet opened)

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
claude/balance-d from look-options ed1d2d9, pushed at c782362 (7b07459 data + handoff, c782362 test fixes +
D-050 in docs/DECISIONS.md). No PR yet. The main checkout is ON this branch; the lead session commits handoffs in
the same checkout: tell the lead before switching back to look-options.

## Changes (all committed)
- data/upgrades.json: all 31 cost arrays x1.27, r_beam x0.6 (0.762 total), i_brood x1.8 (2.286 total),
  rounded to int.
- data/species.json: reptilian speed 5.5, ability_damage 36, ability_range 11; insectoid ability_damage 18,
  ability_cooldown 6.5.
- data/tuning.json: cone_half_angle_deg 36.
- tests: claws 12 -> 15 (sim, flow); growth tree-total band upper 3.0M -> 4.5M (insectoid 4.12M, Brood x1.8
  stacks on x1.27). All 8 suites green at floors locally (tests2.log).
Expected pacing (PR #16 table D): ceph 3.70 h / rep 4.43 h / insect 3.26 h.

## Running jobs
Background bash in session "Game demo planning": GODOT=C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/
Godot_v4.7.2-stable_win64_console.exe tools/run_tests.sh, then pacing.gd per species. Logs in the scratchpad
(C:/Users/DANTE/AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental/
a71b8659-f570-46fa-a36b-eb259807c651/scratchpad/{tests,pacing_*}.log). First attempt failed: `godot` not on
PATH; rerun with the full path. No override.cfg, no windowed Godot.

## Next
1. Read pacing logs: reptilian hours-to-evolve1 (demo target 20-30 min) and totals vs table D.
2. Open PR into claude/look-options with the template: evidence = suite counts + pacing table;
   Board and log = D-050 in full; [MERGE NOTE] floors unchanged, director gate approved (D-049/D-050).
3. Briefed 03:40 (director: "get the other chats working"): ability-vfx -> P4; blender-reptile -> P2 then P3 rig;
   kaiju-motion -> P5 demo slice in a new worktree after removing the 3 stale ones; lead -> P3 Tripo meshes + QA
   gates. P6 Windows export is mine after P5. Lead reviews the P1 PR.

## Open decisions
None for the director right now. If reptilian evolve1 lands outside 20-30 min, propose one lever (evolve1
cost) with the measured number, ask-the-director style.
