# Taskforce handoff (PR 1, sim core, agents only), 2026-10-23
## State: working (fixes done and green on the taskforce suite; other suites + PR pending)
## Task
Anti Kaiju Taskforce PR 1 (sim core, agents only). Serves ROADMAP "Your adversaries", M2, D-137/139/141/143/145/152.
Lead: session "Status check". Next after this: PR 3 kills (swat, perch-collapse fall), PR 4 frost grenades.
## Branch and commit
Local `claude/taskforce-core-ee770a` (worktree taskforce-core-ee770a) = origin/claude/taskforce-core (73858aac) +
merge of origin/claude/look-options. Push target: origin `claude/taskforce-core` (the old wt/taskforce-core holds
that branch name locally). Uncommitted: sim/taskforce.gd, sim/taskforce_frost.gd, data/tuning.json,
tests/run_taskforce_tests.gd, tests/lib/taskforce_suite.gd, this file.
## What changed this session
- The 4 failures were: tests walking sideways into walls / needing a turn (fixed with `_face_free_way`, a body-clear
  way the kaiju already faces); the dash into a wall ends the same step so frost never saw it (fix: TaskforceFrost
  counts `dash.dashes`); effect fixture: the kaiju stood at the map edge where no roof is within railgun range, and
  agents hovered forever (fix: perch fallback to the nearest roofs, `perch_fallback` 4; fixture now walks in 20 s,
  then stands, difference == railgun hits x 8%).
- D-152 data: railgun cooldown 12, frost 4 s x0.5, kill pay = tank_rubble x `rubble_share` 1.0 (`kill_pay()`).
- `railgun_hit` event carries `share`; PostFxState does not exist yet (PR #155 unmerged), so the fringe call is NOT
  wired: the post-fx side must call `PostFxState.hurt(event.share)` on railgun_hit.
## Test state
Taskforce suite: 10 of 10 functions, 55 checks, 0 failures (own APPDATA, ~7 min). Planted defects shown failing:
lock 0, perch_fallback 0, rubble_share 0.5, share 0, old dash rule. Background run: military + flow via run_tests.sh.
## Unfinished
Check military/flow/sim, run lint, full suite once, commit, push to origin claude/taskforce-core, PR against
claude/look-options (sim-review packet + Evidence + Not exercised), report to lead.
## Open risks / questions for the lead
- "Agents first appear a few minutes into the adolescent city": sim has no cross-run clock; kept per-run gates
  (after_chunks 150, first_delay 6 s). Needs a ruling if a rampage-count gate is wanted.
- Dodge margin: from a stand, straight walk covers ~1.9 vs hit_radius 1.5 in the 0.4 s lock.
- Fresh worktree import segfaults on kaiju_block.ttf; fix: copy .godot/imported/kaiju_block.ttf-* from another worktree.
