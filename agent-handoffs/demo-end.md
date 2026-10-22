# Demo-end handoff, 2026-10-23 02:50
## State: waiting (Godot frozen by the director until 02:57; then run the suites, commit, push; no PR until the lead says)
## Task
The demo ending: ROADMAP M3 "demo end screen and feedback button"; D-145, D-148, D-152, D-153, D-156 (amended). Lead:
"Status check" (the Kaiju lead, local_a16cd984-128a-4b5f-8bdf-05556e046cd4). Queue after this (lead's message): weather
pick (after PR #156 merges), sky and sea life (sim side; tell the lead which files first), Taskforce adult-city units
(after claude/taskforce-core merges). The VFX lead wants the weather/sky names, events and my branch name when those land.
## Branch and commit
claude/demo-end from origin/claude/look-options. Committed locally, NOT pushed. Director rule: no new PR until the lead
says (3 open max); no full suite on this PC, only suites the change touches.
## What it does now (the amended ruling, D-156)
- Final upgrade = the demo's end: `Demo.complete(tree)` (every tree node owned, from data). Main._on_bought shows the thanks
  screen (after the reveal if the node evolves) and sets save.demo_done. Buttons: LEAVE FEEDBACK (`demo.feedback_url`,
  PLACEHOLDER, `DemoEnd.opener` swappable in tests), TRY ENDLESS MODE, KEEP PLAYING (back to the tree). Continue goes to the tree.
- Endless mode: sim/endless.gd (`sim.endless`, null in normal mode), own data rows `demo.endless`; no clock, no fall;
  escalation from `start_chunks` + `chunks_per_second` (cap `max_chunks`); `max_tanks`; regrowth of far destroyed plain
  buildings every `regrow_interval` (event `building_regrown` -> CityView.regrow -> BuildingStream.regrow). Banks nothing.
  Started from the thanks screen and an ENDLESS MODE button on the tree (scenes/upgrade_screen.gd) once demo_done. The title
  file is untouched (ui-title-menu PR owns it); the lead may want a title/city-select entry instead.
- Normal demo rampages add to `save.totals` (Demo.add: biomass, buildings, eaten, fled, military, seconds). Save v3 keys
  demo, demo_done, totals; `Demo.continues(save)`: a demo save never continues in the full game.
- Tests: suite `demoend` (tests/run_demoend_tests.gd + tests/lib/sim_demo_end.gd, incl. normal-untouched check), flow_demo.gd
  rewritten (mouse, key, pad via new GuiInput.pad), demo_smoke.gd and capture_demo.gd rewritten. README row added.
## Unfinished changes
- NOTHING from the final-upgrade/Endless rework has been run yet (Godot frozen). Run: `tools/run_tests.sh --quick demoend
  sim_play military sim` (GODOT=C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe;
  sim alone is ~500 s, run in the background). Show the new demoend checks failing first on planted bad input (earlier
  planted runs were for the superseded design).
- flow and smoke suites exit 127 silently on this PC as soon as a 3D view builds (title/species select), also in the
  three-steps worktree; asked the lead, no answer. CI is the gate for flow/smoke unless a fix is found.
- 4K still of the thanks screen: `capture_demo.gd -- --only=thanks`, windowed with the untracked override.cfg (already in
  the worktree, git-ignored); the focus guard blocks windowed runs while the director has a fullscreen game.
- native/bin DLL copied from another worktree (untracked, never stage it); complexity baseline shrunk by one row
  (RampageSim.step); .uid files are untracked noise, stage by name.
- PR needs: Evidence, the sim-review packet (save v3 keys with defaults + v2 migration test, Endless/escalation shared sim
  paths), "Not exercised" (flow, smoke, still), the PLACEHOLDER URL note.
## Attempts
Trigger changed three times (survived adult rampage -> adult city fully ruined -> final upgrade, D-156 amended); only the
last is in the code. The 127 crash: tried copying the native DLL, --audio-driver Dummy, no --fixed-fps: no change.
## Open decisions
Entry point for Endless (tree button now vs title/city select); real wrecked-city persistence is gone with free play;
feedback URL; the base still has 4 city rows and evolve3 (three-steps trims them).
## Findings for the lead
People eaten/fled are view counts (StreetLife), not sim counters. Buttons use UiKit.button (the plate look is the title PR's).
