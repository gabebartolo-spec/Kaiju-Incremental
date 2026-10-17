# Game-flow handoff, 2026-10-17 13:05
## State: running a check (3 CI captures; PR #14 CI re-running)

## Task
Make the loop around the rampage feel finished (brief from lead session local_9fac90d2):
1. end beat + results count-up vs previous best; 2. evolution reveal (skippable);
3. evolution tree polish (affordability, play-terms, branch band, ultimate capstone);
4. main menu, pause, settings (volume, fullscreen F11, controls, UI scale for the 4K TV);
5. save/reload/continue proven + save-migration test.
Done = PR into claude/look-options, CI green, CI-rendered screenshot per screen + a flow clip,
lead reviews first. No windowed Godot (director gaming): headless tests, CI captures only.

## Branch and commit
claude/game-flow-edfba4, pushed at 0396604 (origin/claude/look-options merged in; rampage.gd
trimmed 415 -> 400: slow-mo and time/pause reset moved into rampage_hud.gd). Draft PR #14 into claude/look-options, Auto-fix on.

## What is built
- sim: Collapse.toppled / biggest_fall; RampageSim.end(reason) public ("ended" = pause menu);
  Growth.body_scale (sim/growth.gd). rampage_sim.gd 399/400 and rampage.gd 400/400 lines.
- rampage_hud.gd: end beat (headline punch, slow-mo 0.3, 150 frames, skip after 40), pause.
- results_screen.gd, evolution_reveal.gd, upgrade_node.gd + upgrade_screen.gd, title_screen.gd,
  pause_menu.gd, settings_menu.gd. autoload/save_file.gd (save v2 + v1 migration) and
  autoload/player_settings.gd (settings.cfg) are static; SaveSystem/Settings forward.
- Tests: tests/lib/gui_input.gd (real clicks/keys), tests/lib/flow_screens.gd; display-font
  check in run_flow_tests.gd. Flow floor 67.
- tools/capture/capture_flow.gd: 11 shots; --clip; --ui-scale=1.25.
- LFS checkout in capture.yml, tests.yml (shards + self-test), build.yml.

## Unfinished (in order)
1. Done: full local run green after the merge (smoke 12, sim 39, powers 24, tentacles 17,
   city 5, flow 67, self-test); pushed.
2. Captures: download, 2x-crop QA every shot (buttons/values readable, 1080p + 4K), copy to
   docs/captures/2026-10-17-game-flow/, fill PR #14 Evidence (CAPTURE_LINKS), send to lead.
3. Mark PR ready after lead's OK. Follow-up when city-growth #16 merges: reveal reads
   CityGrowth.tuning_for(tuning, size)["city"] (max_height 26/32/40/48; half 42/66/105/166).

## Attempts / history
- Worktree had LFS pointer fonts -> flow suite timed out (900 s); `git lfs pull` -> 51 s.
- Autoload names don't resolve in class_name scripts under --script runs -> static classes.
- Lead review round 1 (FIX): blank title/buttons/values in CI stills = LFS pointer font on CI
  (not colour/tween). Fixed + font check (FAIL on 129-byte pointer, PASS on 8944-byte font).
- GitHub Actions was blocked by billing 17:07Z-12:45; repo now public, Actions runs.
- PR lint red after base moved: rampage.gd 415 lines -> trimmed to 400.

## Findings for the lead (lead decides what gets recorded)
- Pull LFS in every new worktree before a test run (proven: 900 s timeout -> 51 s).
- Every CI capture before capture.yml's `lfs: true` has blank Kaiju Claw text.

## Open decisions
None for the director. Civilians count comes from the view (StreetLife.killed), not the sim.

## Running jobs
- CI captures: shots 38992440820 -> %TEMP%/gf_cap/shots, 4K 38992469000 -> %TEMP%/gf_cap/4k,
  clip 38992495568 -> %TEMP%/gf_cap/clip (watcher waits for all three logs).
