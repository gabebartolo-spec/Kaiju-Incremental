# Demo-end handoff, 2026-10-23 02:50
## State: running flow after fixes (pause over 03:28); then push claude/demo-end, report sha to lead; NO PR until lead's helper opens it
## Next: weather pick plan (queue 1; plan only, wait for 'go weather' in lead-board/to-demo-end.md)
Mirror TimeOfDay (on look-options since #156): new sim/weather.gd `Weather` (RANDOM="", pick(run,last,setting) seeded by
Seeds.make("weather", run), settings/next/label/clean), data in data/looks.json "weather" {order: clear, overcast, rain, fog,
thunderstorm; labels; random_label "Random each rampage"}, Content.weather()/weather_table(), save key last_weather (+migrate
default), PlayerSettings.weather + cfg display/weather, options row "Weather" in settings_menu, main._start_rampage picks and
sets `Content.set_weather(id)` -> VFX reads `Content.current_weather` (one value, string id). Suite `weather` mirrors timeofday.
Branch claude/weather from origin/claude/look-options after demo-end is pushed. No visuals.
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
- Suites 03:29: demoend 25 checks pass; sim_play, military, smoke, sim pass. flow had 7 fails; fixed: thanks screen text reserve
  (DemoEnd.TEXT_RESERVE, EvolutionReveal.frame_view(owner, reserve)), pad ui_* bindings added in autoload/settings.gd (engine
  default had no pad on ui_accept), flow_save v1 assertion now SaveFile.VERSION. flow after the fixes: 1 check left (saved totals are floats from the file; now compared via Demo.add(saved, {})); final flow rerun running. Earlier note: the
  "normal rampage adds the sim's counters" check (saved totals were {}). Fixes are uncommitted until flow is green.
- Still to do: planted-failure runs for the Endless checks, lint (complexity_ratchet, tuning_keys, 400-line cap), 4K still.
- native/bin DLL removed; .uid files untracked noise, stage by name.
- PR needs: Evidence, sim-review packet, "Not exercised" (still), PLACEHOLDER URL note.
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
