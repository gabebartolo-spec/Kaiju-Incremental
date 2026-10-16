# Game-flow handoff, 2026-10-17 02:20
## State: running a check (flow suite, headless, local)

## Task
Make the loop around the rampage feel finished (brief from session local_9fac90d2):
1. end beat + results count-up vs previous best; 2. evolution reveal (skippable);
3. evolution tree polish (affordability, play-terms, branch band, ultimate capstone);
4. main menu, pause, settings (volume, fullscreen F11, controls, UI scale for the 4K TV);
5. save/reload/continue proven + save-migration test.
Done = PR into claude/look-options, CI green, CI-rendered screenshot per screen + a flow clip,
lead reviews first. No windowed Godot (director is gaming): headless tests, CI captures only.

## Branch and commit
claude/game-flow-edfba4 (fast-forwarded to origin/claude/look-options b97af62). WIP commit
on top; not pushed yet, no PR.

## What is built (all code written, first full test run pending)
- sim: `Collapse.toppled`, `Collapse.biggest_fall`; `RampageSim.end(reason)` is public (pause
  menu's End Rampage, reason "ended"); `Growth.body_scale` (sim/growth.gd) shared by sim + reveal.
  rampage_sim.gd is at 399/400 lines: anything new goes elsewhere.
- scenes/rampage_hud.gd: end beat (headline punch, slow-mo 0.3, 150 frames, skippable after 40),
  pause key (Esc/P/Start) opens scenes/pause_menu.gd. Old results panel removed.
- scenes/results_screen.gd: count-up per row vs previous best, NEW BEST tags, verdict line.
- scenes/evolution_reveal.gd: old stage -> flash -> new stage, roar, beside a tower of
  size x tier_height floors (what the body now topples). Holds focus so Enter can't rebuy.
- scenes/upgrade_node.gd + upgrade_screen.gd: BUY n / need n, role = plain/branch/evolve/
  ultimate (capstone = species node nothing requires), now -> next stat lines, ScrollContainer.
- scenes/title_screen.gd, settings_menu.gd; autoload/player_settings.gd (static, settings.cfg),
  autoload/save_file.gd (static, save v2 with "best", v1 migration). Autoloads forward to them.
- tests/lib/gui_input.gd (real clicks/keys), tests/lib/flow_screens.gd (new checks), hooked
  into tests/run_flow_tests.gd. Floor in tests/expected_checks.txt NOT yet raised.
- tools/capture/capture_flow.gd: 11 shots via main scene; `--clip` for the movie.

## Unfinished
- Get flow suite green; raise the flow floor; run all suites.
- Commit .uid files Godot generated for new scripts.
- Push, dispatch CI capture (capture.yml is on main, so ci_capture.sh works):
  `tools/capture/ci_capture.sh --resolution=1920x1080 capture_flow.gd` and `--movie ... -- --clip`.
- PR body (Evidence, Not exercised, Board and log), art-qa/screen-critic check of shots.

## Attempts
- Autoload names (SaveSystem, Settings) don't resolve in class_name scripts compiled under
  `--script` test runs -> moved logic to static classes SaveFile/PlayerSettings.

## Open decisions
None for the director yet. Civilians count comes from the view (StreetLife.killed), not the sim.

## Coordination
city-growth (local_abf1bce5) replied: it edits main.gd _start_rampage (CityGrowth.layout) and
rampage.gd setup() (CityGrowth.tuning_for), raises upgrade costs 2-8x. No overlap with my
edits; my tests/capture read evolve1's cost from data. If tier_height becomes per-stage, the
reveal's tower should read CityGrowth.tuning_for(...)["city"].

## Running jobs
Local flow suite run (background), logs in %TEMP%/gf_logs.
