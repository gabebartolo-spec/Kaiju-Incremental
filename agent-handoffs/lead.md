# Lead handoff, 2026-10-21 (lead 9, session local_df2c2989, CLI 07ae5487; registered in context-guard-leads)
## Next lead: register (empty file named by your CLI session id in ~/.claude/context-guard-leads/), read this, then
## GitHub (open PRs), then list_sessions. Director's /goal: playable build with building carving first draft.
## Plan = docs/ROADMAP.md "Post-demo plan" phases A-H; every comment in docs/roadmap/2026-10-20-build2-playtest.md
## (30 notes) and docs/roadmap/2026-10-20-director-comments.md (rows 1-19; 18-19 added in #115).

## Team (director 2026-10-20/21)
- Builders: the lead only ("No, I'll do Phase A"). Helpers: TWO Sonnet-high read-only reviewers/critics ("i afforded
  you two sonnet high helpers, use them wisely", "keep your devs working", 2026-10-21 "both your devs are idle get them
  working"). Keep both busy every turn; they write no code. Restart each at 300k as a fresh session (same title);
  the app only lets you start sessions on a turn the director drove.
- SENIOR DEV (local_66da64f8, fresh 2026-10-21): on kerb-fixes.md (cars on plaza edges, bunched trees, city-wide scan).
- Senior2 reader/critic: predecessor local_87436601 at 300k, idle, could not be archived (background job): archive it
  and start "Senior2 reader/critic" fresh with the b2-30 re-review brief (b2-30/b2-30-review.md items).
- Notes: C:\Users\DANTE\AppData\Local\Claude-Data\claude_pzs8sxrjxfjjc\side-session-notes\local_cf0b00c9-bc39-4198-aaf9-942340291b1a\
  (freeze-trace.md, stadium-review.md, landmark-box/, b2-22-review.md, phase-a-audit.md, b2-30/). Phase maps (FINAL):
  ...\local_962460da-...\phase-maps.md, phase-maps-copy.md. Senior dev's stadium-pr-review.md is in ...\local_df2c2989-...\.

## Merged today: #113 river rise (6b119f7), #114 edge bollards (6494ba2). Earlier: #109-#112.
## Open PRs / branches (into claude/look-options)
- #115 stadium past the baby's edge + landmarks stream first (b2-21), head dc3c05b4c6ac656ed8f552bbb2dc8d8160f10321,
  mog.sh watcher armed. Senior reviews SHIP (code + 8 captures). Polish for Phase C: parked cars straddle the plaza
  edge (no sidewalk now), street + plaza-ring trees bunch.
- claude/b2-30-run-start-freeze 4d7c869 (pushed, no PR): senior dev 1's staged run start (loading screen, stream stop
  flag, hide-then-quit) + lead fixes for senior2's review (meter 7 stages pinned, consts, initial worker honours _stop).
  Merged look-options in. Flow/smoke/load suites rerunning. Will conflict with #115 in BuildingStream._ready: keep
  `_landmarks_first(_rest)` after the _rest loop, before `_now = now`; add `_landmarks_first` and `queued()`.
  Open gaps from the review: QuitGame/WM_CLOSE test, staged-vs-plain same-seed equality, tests/lib/flow_demo.gd:97.
- claude/b2-22-party-facades b06451a (pushed, no PR, Phase C): facade on touching sides + behaviour check (red on
  base). Needs a capture of a demolished neighbour (proud awnings) before its PR.

## NEXT
1. #115 merges -> PR b2-30 (resolve the conflict above) if its suites are green; then build 3 = Phase A gate:
   `gh workflow run build.yml --ref claude/look-options`. Smoke the exe, put it in
   C:/Users/DANTE/Documents/GitHub/Kaiju-Builds/, tell him with the 5-line note (draft in notes/phase-a-audit.md).
2. Director question at Phase C start (phase-maps.md): b2-4 "effortless carving even for a baby" vs D-091. Options
   A effortless + size shows in bite size (rec), B floor the slowdown (<=2x), C keep D-091, fix feel with VFX. Also drop
   VISION.md:26-27 tier-gate sentence (stale since D-091).
3. Phase D turning: sim.facing is instant, only body.heading lags (turn_rate 10): move along body.heading, turn_rate
   ~3-4, head yaw leads (biped_head.gd).

## Findings this session
- Local runs without native/bin/*.dll take the GDScript carving path: sim ("a swiped tower topples sooner") and military
  ("tanks hold standoff") each fail one check that passes on CI. Copy carve-play/native/bin/*.dll in first.
- Far landmarks drew as office boxes until streamed in (BuildingStream stand-ins); captures shot them at 4 frames.
- Swapping files in a worktree while its suites run poisons the run: never do it; use another worktree.
- Two long-running Godot prof.gd processes (tools/tmp_wp7, PIDs 925029/929069) are not ours: carve-wp7 worktree kept.

## Tools
- mog.sh in lead 9 scratchpad (07ae5487.../scratchpad/mog.sh <pr> <full sha>); copy it to yours.
- Captures: tools/capture/capture_landmarks.gd (--tier=), capture_shaders.gd; override.cfg in the worktree first.
- Worktrees removed today: river-rise, b2-26, camera-opts, carve-wp1..6, board-d096, board-d098 (39 left).

Lead = "Kaiju: LEAD 9". Owns QA gates, merges, DECISIONS/STATUS, director questions, this file. playbook: nothing new.
