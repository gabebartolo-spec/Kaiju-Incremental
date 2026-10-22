# Demo-end handoff, 2026-10-23 02:50
## State: demo-end resynced with look-options (merge 4be897bc), suites running (demoend, sim_play, flow, smoke); then push + report sha. Weather branch waits on a settings-height fix.
## Weather pick (queue 1, lead's go 05:37), branch claude/weather in ../../Kaiju-Incremental-wt/weather
Done at 79c0e792: sim/weather.gd (Weather.pick/next/label/clean, Seeds "weather"), data/looks.json "weather" table, Content.weathers()/
weather_table()/weather_id()/set_weather(), PlayerSettings.weather (+cfg), save key last_weather (default via .get, no version bump),
Main._start_rampage picks and sets Content.weather_id(), options row, suite tests/run_weather_tests.gd (23 checks green; 5 planted
bugs each fail it, log in /tmp/plant_weather.out). timeofday + sim + ratchet + tuning keys green.
OPEN: flow fails one check, "BACK at 125% off screen": the Weather row needs its own full-width row (two long labels cannot share
a row) and the settings screen then no longer fits. Question logged in lead-board/interview.md (tighten spacing vs "Random" on both).
Next: pick the fix (tighten row/block gaps, mind the critic's 10/20 px rules), run flow, push, report sha, write the VFX interface
line to lead-board/from-demo-end.md: Content.weather_id() (String id: clear, overcast, rain, fog, thunderstorm), set in
Main._start_rampage before the rampage scene is built; also the save key last_weather and PlayerSettings.weather.
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
- demo-end: resync merge done (post-merge fixes: Endless test clicks the new End Rampage YES step; DemoEnd.setup totals optional for run_ui_tests); demoend + sim_play green, ui/smoke/flow rerunning (lead line 4 of to-demo-end.md); then push claude/demo-end and
  report the sha. The thanks screen no longer has upstream's MAIN MENU / QUIT buttons (ruling replaced them): tell the lead.
- Seams made to stay at 400 lines: TankYard.on_event handles all four tank events; scenes/hud_counts.gd (HudCounts.of/clock).
- Later: 4K thanks still when the focus guard allows; Taskforce kills into demo.military_keys after #161; queue 2 (sky and sea
  life, tell the lead the files first) and queue 3 (Taskforce adult units).
## Attempts
Silent "exit 127" in headless runs (flow, smoke, demoend) is most likely my Godot being killed from outside during the director's
Godot pauses (~/.claude/focus-pause says until when), not a code bug: check that file before debugging, and rerun after it.
Endless no longer holds a `sim` field (methods take `sim` as a parameter) to avoid a RampageSim<->Endless typed cycle.
Trigger changed three times (survived adult rampage -> adult city fully ruined -> final upgrade, D-156 amended); only the
last is in the code. The 127 crash: tried copying the native DLL, --audio-driver Dummy, no --fixed-fps: no change.
## Open decisions
Entry point for Endless (tree button now vs title/city select); real wrecked-city persistence is gone with free play;
feedback URL; the base still has 4 city rows and evolve3 (three-steps trims them).
## Findings for the lead
People eaten/fled are view counts (StreetLife), not sim counters. Buttons use UiKit.button (the plate look is the title PR's).
Lesson for the lead (to file): a 'rows changed, result identical' check must include zero and an extreme row; x7 alone saturated the army and let two planted bugs pass (caught by the planted-bug run).
