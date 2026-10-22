# Demo-end handoff, 2026-10-23 02:50
## State: PR #165 FIX round in progress (lead order, before sky and sea life): merge of look-options done (save v4), sim-review fixes coded, suites to run: demoend flow smoke ui sim_play military taskforce_gate; then push once and report the sha.
## Weather pick (queue 1) DONE: claude/weather @ a21dfdec in ../../Kaiju-Incremental-wt/weather
Weather.pick/next/label/clean (sim/weather.gd), data/looks.json "weather", Content.weather_id() (the one current value: clear,
overcast, rain, fog, thunderstorm; set in Main._start_rampage), PlayerSettings.weather, save key last_weather, own options row
(CONTROLS shares the column-title row and sliders are 28 high so the screen fits at 125%), suite tests/run_weather_tests.gd (23 checks;
5 planted bugs each fail it, log /tmp/plant_weather.out), flow settings-row checks extended. VFX line sent via from-demo-end.md.
## Sky and sea life (queue 2) PLAN, waiting for "go sky" (team cap): ROADMAP comment #63-64, #71, D-155.
Sim, events, data only; placeholder boxes in the view. Files: new sim/sky_life.gd (Birds flock: positions, scatter on roar /
tower fall events; Boats: drift along the river band; Whale: one untouchable per run, surfaces/spouts), data/tuning.json "sky_life"
rows, hook in sim/rampage_sim.gd step (+ a field; watch the 400-line cap, rampage_sim is near it: split at a seam), events
bird_scatter / whale_spout, tests/lib/sim_sky_life.gd + tests/run_skylife_tests.gd, scenes placeholder node SkyLifeView.
Question for the director (in interview.md): the map has only a river band (CityRiver), no bay: where does the whale live?
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
- #165 FIX round (comment 6350997254 + to-demo-end.md): (a) merged origin/claude/look-options, SaveFile.VERSION 4 (demo keys under
  version < 4; city_seconds bank line inside `if not _endless`); (b) FireSpread.reset_building + Collapse.forget_topple called from
  Endless.regrow, buildings counted by b.frame.alive_count == 0, Endless escalation = chunks_total x (start_share + share_per_second x
  elapsed) with no cap, regrowth = regrow_share_per_minute (5%) of flattened buildings per regrow_interval pass (rows in
  data/tuning.json demo.endless); (c) "agents" in demo.military_keys, taskforce.gd interval() reads sim.escalation(); (d) gdlint
  clean (gdformat -l 100), flow_demo split into tests/lib/flow_demo_menus.gd. New sim checks in tests/lib/sim_demo_end.gd.
- Green on a8ab1099+: demoend (32 checks), sim_play, military, taskforce_gate, ui. smoke + flow rerunning after a typing fix in tests/lib/flow_demo_menus.gd. Next: planted-defect runs for the new checks (regrow fire reset, building count, escalation scaling), push once, report sha.
- Then: sky and sea life (plan above; rampage_sim.gd ~397 lines, so the hook goes in a new small file), 4K thanks still, Taskforce
  mech/gunship units (queue 3, after taskforce-core: its result keys join demo.military_keys).
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
