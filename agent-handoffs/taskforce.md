# Taskforce handoff (PR 1, sim core, agents only), 2026-10-23
## State: working (PR #161 pushed e125f7f5; fix 4 + frost radius 1.5 coded, uncommitted, final confirm run in flight)
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
Run 03:30 on 225ee403 (own APPDATA, after a re-import for the class cache): taskforce, postfx, sim_play, military,
flow all pass; taskforce_gate had 1 failure (JSON round trip float), fixed in e125f7f5 (approximate compare).
Planted defects shown failing: carried gate (city_seconds 100 -> "180 s" check), frost radius 4 (slow walker check).
## Unfinished (uncommitted in this tree)
- Lead's 03:54 note (lead-board/to-taskforce.md): FIX 4 done: new sim/taskforce_perch.gd (pick, _top = highest
  standing chunk >= perch_min_height-1, _has_top, _perchable); taskforce.gd delegates (347 lines). Frost radius
  4 -> 1.5 in data (walking dodges, standing is caught). New gate checks _check_chewed_top, _check_frost_radius.
  Gate + taskforce suites passed; still owed: planted roof-only perch run showing _check_chewed_top fail, then
  commit + push once and report the head to the lead. FIX 5 (swat) NOT confirmed: leave. Volley stays: director.
- Small leftovers: post_fx.gd event-routing test; Content.section vs the sim's tuning.
## Open risks / questions for the lead
- "Agents first appear a few minutes into the adolescent city": sim has no cross-run clock; kept per-run gates
  (after_chunks 150, first_delay 6 s). Needs a ruling if a rampage-count gate is wanted.
- Dodge margin: from a stand, straight walk covers ~1.9 vs hit_radius 1.5 in the 0.4 s lock.
- Fresh worktree import segfaults on kaiju_block.ttf; fix: copy .godot/imported/kaiju_block.ttf-* from another worktree.
