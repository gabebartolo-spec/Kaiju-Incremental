# Demo handoff, 2026-10-18 03:57
## State: running a check (PR #21 CI + insectoid/cephalopod pacing); awaiting lead review

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
D-050 in docs/DECISIONS.md, 6b99335 handoff). PR #21 into look-options, Auto-fix on, lead reviews. The main checkout is ON this branch; the lead session commits handoffs in
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

## Pacing (reptilian, done): evolve1 0.59 h (run 28, 94% city, 16/28 young runs defeated), evolve2 1.83 h,
evolve3 3.85 h, tree 4.46 h / 162 runs (table D: 4.43). Director 03:55: KEEP balance D as is; the 35 min scripted
evolve1 is accepted, human time confirmed at P7.

## Next
1. When pacing_insectoid/cephalopod logs land: edit the #21 body "Evidence" (gh pr edit 21 --body-file).
2. Lead reviews #21; merge is the lead's (squash). After merge: tell the lead, then switch the main checkout
   back to look-options and delete claude/balance-d.
3. Briefed 03:40 (director: "get the other chats working"): ability-vfx -> P4; blender-reptile -> P2 then P3 rig;
   kaiju-motion -> P5 demo slice in a new worktree after removing the 3 stale ones; lead -> P3 Tripo meshes + QA
   gates. P6 Windows export is mine after P5.
4. Helper status 03:53: blender-reptile P2 at 4a35fed (clips own tail0..8, captures rerunning one at a time, PR
   next); ability-vfx P4 #8 revived at 2195d54 (flow floor 76->83, clips with audio in side-session-notes/
   local_9fac90d2.../ability-sfx-d050/), sent to the lead for QA before the director listens.

## Open decisions
None. Director gates pending elsewhere: SFX listen (lead presents), croc baby/adolescent board (lead).
