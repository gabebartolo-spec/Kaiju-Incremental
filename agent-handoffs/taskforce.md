# Taskforce handoff (PR 1, sim core, agents only), 2026-10-23
## State: working (PR #161: D-160/D-161 + review fixes pushed 225ee403, UNTESTED: no Godot until 03:28)
## Task
Anti Kaiju Taskforce PR 1 (sim core, agents only). Serves ROADMAP "Your adversaries", M2, D-137/139/141/143/145/152.
Lead: session "Status check". Next after this: PR 3 kills (swat, perch-collapse fall), PR 4 frost grenades.
## Branch and commit
PR https://github.com/gabebartolo-spec/Kaiju-Incremental/pull/161, head 225ee403 (gdlint: rampage.setup stays 4 args, city_seconds is a Rampage field set before setup; gate-suite Variant checks typed), base claude/look-options. Local
branch claude/taskforce-core-ee770a pushed to origin claude/taskforce-core. Tree clean.
## What changed this session
- The 4 failures were: tests walking sideways into walls / needing a turn (fixed with `_face_free_way`, a body-clear
  way the kaiju already faces); the dash into a wall ends the same step so frost never saw it (fix: TaskforceFrost
  counts `dash.dashes`); effect fixture: the kaiju stood at the map edge where no roof is within railgun range, and
  agents hovered forever (fix: perch fallback to the nearest roofs, `perch_fallback` 4; fixture now walks in 20 s,
  then stands, difference == railgun hits x 8%).
- D-152 data: railgun cooldown 12, frost 4 s x0.5, kill pay = tank_rubble x `rubble_share` 1.0 (`kill_pay()`).
- `railgun_hit` event carries `share`; PostFxState does not exist yet (PR #155 unmerged), so the fringe call is NOT
  wired here yet.
- Since #155 merged: `PostFxState.railgun()` (hurt with tuning post_fx.fringe.railgun_share 1.0) is called from
  scenes/post_fx.gd on `railgun_hit`; check `_check_railgun` in tests/run_postfx_tests.gd. First-arrival gate is one
  key `first_arrival` {chunks 150, seconds 6} (lead is asking the director). gdlint line lengths fixed.
## Test state
Taskforce suite: 10 of 10 functions, 55 checks, 0 failures (own APPDATA, ~7 min). Planted defects shown failing:
lock 0, perch_fallback 0, rubble_share 0.5, share 0, old dash rule. military 15 checks and flow 206 checks also pass.
## Unfinished
- After 03:28 run ONLY: taskforce, taskforce_gate (new), military, flow, postfx, sim_play (save) via
  tools/run_tests.sh --quick; fix failures (all new code is unrun); push; reply head to lead.
- D-160 done in code: `first_arrival` {city_seconds 180, run_delay 6}; save key `city_seconds` (default 0, in
  SaveFile.migrate/new_save, no version bump); Rampage.setup(..., city_seconds) sets taskforce.carried; result()
  has "city_seconds" and "agents"; main.gd saves it. D-161: armour subtracts like tank shells (min_damage floor).
- Review items 1,3,6,7 done (fringe restarts on every hit, magic numbers in data, tests in run_taskforce_gate_tests.gd,
  postfx 2-hit check). NOT done: review 4 (perch on the highest standing chunk) and 5 (swat reach): wait for the
  reviewer's probe numbers from the lead; post_fx.gd event-routing test; Content.section vs tuning (small).
- Planted-defect demos still owed for the new gate checks (e.g. carried = need - 1 must fail the "joins" check).
## Open risks / questions for the lead
- "Agents first appear a few minutes into the adolescent city": sim has no cross-run clock; kept per-run gates
  (after_chunks 150, first_delay 6 s). Needs a ruling if a rampage-count gate is wanted.
- Dodge margin: from a stand, straight walk covers ~1.9 vs hit_radius 1.5 in the 0.4 s lock.
- Fresh worktree import segfaults on kaiju_block.ttf; fix: copy .godot/imported/kaiju_block.ttf-* from another worktree.
