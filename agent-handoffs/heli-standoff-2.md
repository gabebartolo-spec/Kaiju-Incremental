# heli-standoff-2 (branch claude/heli-standoff-2, worktree Kaiju-Incremental-wt/heli-standoff-2)
Task: D-183 stand-off gunships (director 2026-10-25 "Stand-off gunships"). Lead's last word: push the branch, write
pr-body.md in the worktree, do NOT open the PR (lead opens it, max 3 open PRs).

## State
- Ported the parked claude/heli-standoff work (sim/air_flight.gd, air_wing.gd, tuning "air", tests/run_heliflight_tests.gd,
  tentacles test, capture_heli_deaths line) onto origin/main with `git apply --3way` (clean). D-187 turn weight is on main.
- Tuning moved from the parked branch: standoff 24 -> 30, clear_lead_deg 10 -> 40 (camera side), strafe_close 9 -> 7.5 (a pass
  must reach tentacle grab reach 9 x scale as well as the claw band).
- heliflight: new bars twitch <= 90 deg/s (left-then-right flutter), sweep <= 200 deg round him in 10 s. Red run on the old
  orbit (heli-red worktree, old air_wing + new data): closest 1.2-3.1 vs claw 7.3-18.5, speed 31-69 vs 14, turn 180 deg a step.
- tentacles test: several passes at shifted swipe phases; octo gets time_left 1e9 + heal (the sim ended at 60 s: that was the
  "grab fails" cause, not the flight); grab proven with a heli held in reach.
- Not done yet: see the end of this file.

## Local run
bash ../hs2_run.sh <suites> (in Kaiju-Incremental-wt: engine slot, own APPDATA, tools/run_tests.sh --quick); the first import
needs `godot --headless --path . --import` (the --editor import segfaults on a font).
