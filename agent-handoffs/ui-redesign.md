# ui-redesign handoff, 2026-10-21
## State: working
## Task
Lead-10 builder. In-run HUD (b2-10..13, R 15.1-15.8) and menus (title, pause, settings, results, species
select, loading) in UI look A "Emergency Broadcast" with bespoke original drawn assets; fonts Claw/Block;
one shared outlined text style; fixed tooltip width (b2-23); copy rule. UI only, values in data. Push, no PR.
## Branch and commit
claude/ui-redesign (worktree ../Kaiju-Incremental-wt/ui-redesign) from claude/look-options f4fedeec.
fc1391b6: capture_flow shoots the loading screen. Scratch branch claude/ui-redesign-before (delete at end).
## Unfinished changes (uncommitted in the worktree until the suites pass)
Done in code: data/tuning.json "ui" section; UiKit text_style/safe_area/header/panel_box; UiMarks (tape,
ticks, alert tag, scanlines); HazardBox corner brackets + focus chevron; RampageHud rewrite (clock+thin
city meter, boxless biomass roll/pop, HudRing x3, HurtVignette shader, first-run ControlsCard with
PlayerSettings.controls_seen in settings.cfg); Settings CONTROLS page; species select turntable centred;
results/pause/loading headers; results "Tallest tower toppled" in STOREYS; tree details panel fixed width
(role label wraps, BRANCH/CAPSTONE copy gone); new tests/run_ui_tests.gd + tests/lib/ui_hud.gd; flow tests
updated (dash ring, HUD hidden on pause, settings CONTROLS page, demo controls via ControlsCard).
Left: suites green, after captures, title screen polish, report.
Asked lead: dash/ultimate rings (built as rings) and CITY DESTROYED (built as a thin text-less meter).
## Evidence so far
Before captures dispatched (4K, 125% and 100%): NOTES/ui-redesign/before-125, before-100 (log before.log).
## Attempts (fix-loop record)
none
## Open decisions
none
## Running jobs
background ci_capture of the before shots.
## Findings for the lead
none yet
## Rules learnt the hard way (under 10 lines)
gdformat/gdlint live in ~/AppData/Roaming/Python/Python314/Scripts (not on PATH).
