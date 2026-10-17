# Game-flow handoff, 2026-10-17 12:45
## State: blocked (GitHub Actions refuses jobs: billing / spending limit)

## Task
Make the loop around the rampage feel finished (brief from session local_9fac90d2):
1. end beat + results count-up vs previous best; 2. evolution reveal (skippable);
3. evolution tree polish (affordability, play-terms, branch band, ultimate capstone);
4. main menu, pause, settings (volume, fullscreen F11, controls, UI scale for the 4K TV);
5. save/reload/continue proven + save-migration test.
Done = PR into claude/look-options, CI green, CI-rendered screenshot per screen + a flow clip,
lead reviews first. No windowed Godot (director is gaming): headless tests, CI captures only.

## Branch and commit
claude/game-flow-edfba4, pushed at 904a312 (origin/claude/look-options 55ce218 merged in for
the working capture.yml). Draft PR #14 into claude/look-options (body draft in the PR; CAPTURE_LINKS placeholder
to fill). Auto-fix is on.

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
- This worktree had Git LFS pointers instead of fonts/models (font errors flooded the log);
  `git lfs install --local && git lfs pull` fixed it. Do this in every new worktree.
- First flow run: one real failure (UI scale float compare) -> is_equal_approx.
- Rerun with real fonts: flow 66 checks, 0 failures, 51 s (was a 900 s timeout). Floor 26 -> 66
  in tests/expected_checks.txt.
- Full run 1: smoke/sim red: tests/run_sim_tests.gd preloaded save_system.gd for migrate();
  now preloads save_file.gd. Full run 2: ALL GREEN (smoke 11, sim 39, powers 24, tentacles
  17, city 5, flow 66, self-test).

## Findings for the lead (worker -> lead; lead decides what is recorded)
- Proven 2026-10-17: a worktree without `git lfs pull` has 129-byte LFS pointers for fonts and
  .glb; every UiKit label logs a FreeType error with a backtrace (22k errors, 8 MB log) and the
  flow suite timed out at 900 s. After `git lfs install --local && git lfs pull`: 51 s, 18 errors.
  Candidate for kaiju-godot-tests learnings ("pull LFS in every new worktree before a run").
- Same on CI: capture.yml checked out without LFS, so every Kaiju Claw heading/button rendered
  BLANK (run 38923674895, 01_title.png) and the render hit the 50 min limit after 5 shots.
  Fixed on this branch (`lfs: true`, 3 font files ~26 KB). Every agent's CI captures since
  capture.yml landed have blank headings until this reaches look-options/main.
- Autoload names (SaveSystem, Settings) don't resolve in class_name scripts compiled under
  `--script` test runs -> moved logic to static classes SaveFile/PlayerSettings.

## Lead review round 1 (FIX): blank buttons/title/results values in CI shots
Cause: display font was an LFS pointer on CI (not colour, not tween timing). Fixed: lfs: true in
capture.yml, tests.yml (shards + self-test) and build.yml (the exported game shipped without
it too). New flow check "the Kaiju Claw display font loads with glyphs": FAIL on the 129-byte
pointer, PASS on the real 8944-byte font (probe run, 2026-10-17). Flow 67/67, floor 66 -> 67.
capture_flow.gd takes --ui-scale=1.25 for the 4K still. Still owed: new 1080p + 4K stills.

## Blocker
Since ~2026-10-16 17:07Z every Actions job (tests, lint, capture; also blender-tank) fails in
3 s with "The job was not started because recent account payments have failed or your spending
limit needs to be increased". Director is making the repo public to fix it (lead, 12:38); then dispatch:
  ci_capture.sh --resolution=1920x1080 capture_flow.gd -- --species=reptilian
  ci_capture.sh --resolution=3840x2160 capture_flow.gd -- --species=reptilian --ui-scale=1.25
  ci_capture.sh --movie --fps=30 --resolution=1920x1080 capture_flow.gd -- --clip Nothing to fix in code.
When Actions works: re-dispatch both captures (commands under Unfinished), re-run PR #14 checks.

## Open decisions
None for the director yet. Civilians count comes from the view (StreetLife.killed), not the sim.

## Coordination
city-growth (local_abf1bce5) replied: it edits main.gd _start_rampage (CityGrowth.layout) and
rampage.gd setup() (CityGrowth.tuning_for), raises upgrade costs 2-8x. No overlap with my
edits; my tests/capture read evolve1's cost from data. If tier_height becomes per-stage, the
reveal's tower should read CityGrowth.tuning_for(...)["city"].

## Running jobs
- CI capture re-dispatched after the LFS fix (shots + clip); results download to
  %TEMP%/gf_cap/shots and %TEMP%/gf_cap/clip. Then: 2x crop QA, put shots in
  docs/captures/2026-10-17-game-flow/, fill the PR Evidence, mark ready, report to the lead.
- Local full run (all suites + self-test), logs in %TEMP%/gf_all.
- CI capture dispatches: shots -> %TEMP%/gf_cap/shots, clip (--movie --clip) -> %TEMP%/gf_cap/clip.
- Follow-up after city-growth merges: reveal reads CityGrowth.tuning_for(tuning, size)["city"]
  for max_height and adds "a city of half x half" (42/66/105/166).
