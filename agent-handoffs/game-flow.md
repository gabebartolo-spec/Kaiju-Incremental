# Game-flow handoff, 2026-10-17 17:00
## State: running a check (round-4 CI captures for lead review 2)

## Task
Make the loop around the rampage feel finished (brief from lead session local_9fac90d2):
1. end beat + results count-up vs previous best; 2. evolution reveal (skippable);
3. evolution tree polish (affordability, play-terms, branch band, ultimate capstone);
4. main menu, pause, settings (volume, fullscreen F11, controls, UI scale for the 4K TV);
5. save/reload/continue proven + save-migration test.
Done = PR into claude/look-options, CI green, CI-rendered screenshot per screen + a flow clip,
lead reviews first. No windowed Godot (director gaming): headless tests, CI captures only.

## Branch and commit
claude/game-flow-edfba4, pushed at e14a826 (look-options 13870b3 merged: city growth #16;
rampage.gd 398/400, rampage_sim.gd 399/400) (origin/claude/look-options merged in; rampage.gd
trimmed 415 -> 400: slow-mo and time/pause reset moved into rampage_hud.gd). Draft PR #14 into claude/look-options, Auto-fix on.

## What is built
- sim: Collapse.toppled / biggest_fall; RampageSim.end(reason) public ("ended" = pause menu);
  Growth.body_scale (sim/growth.gd). rampage_sim.gd 400/400, rampage.gd 398/400: the HUD builds
  result() (sim + civilians) and emits beat_done(result); sim.end() returns its event.
- rampage_hud.gd: end beat (headline punch, slow-mo 0.3, 150 frames, skip after 40), pause.
- results_screen.gd, evolution_reveal.gd, upgrade_node.gd + upgrade_screen.gd, title_screen.gd,
  pause_menu.gd, settings_menu.gd. autoload/save_file.gd (save v2 + v1 migration) and
  autoload/player_settings.gd (settings.cfg) are static; SaveSystem/Settings forward.
- Tests: tests/lib/gui_input.gd (real clicks/keys), tests/lib/flow_screens.gd; display-font
  check in run_flow_tests.gd; "buttons stay on screen at every UI scale" for tree, settings,
  species select (window set to 3840x2160: headless windows are 64x64). Flow floor 70.
- tools/capture/capture_flow.gd: 11 shots; --clip; --ui-scale=1.25.
- LFS checkout in capture.yml, tests.yml (shards + self-test), build.yml.

## Unfinished (in order)
1. Done: full local run green after the merge (smoke 12, sim 39, powers 24, tentacles 17,
   city 5, flow 67, self-test); pushed.
2. Captures: download, 2x-crop QA every shot (buttons/values readable, 1080p + 4K), copy to
   docs/captures/2026-10-17-game-flow/, fill PR #14 Evidence (CAPTURE_LINKS), send to lead.
3. Mark PR ready only on the lead's OK.

## Attempts / history
- Worktree had LFS pointer fonts -> flow suite timed out (900 s); `git lfs pull` -> 51 s.
- Autoload names don't resolve in class_name scripts under --script runs -> static classes.
- Lead review round 1 (FIX): blank title/buttons/values in CI stills = LFS pointer font on CI
  (not colour/tween). Fixed + font check (FAIL on 129-byte pointer, PASS on 8944-byte font).
- GitHub Actions was blocked by billing 17:07Z-12:45; repo now public, Actions runs.
- PR lint red twice after the base moved (rampage.gd 415, then 411 with the tank merge) ->
  398. Any further base growth in rampage.gd/rampage_sim.gd needs the same trim.
- CI stills round 2 (run 38992440820, 1080p): title/tree/results/reveal read well; pause and
  end-beat shots showed the results because the kaiju had died (8 physics steps per slow
  frame) -> capture pins max_physics_steps_per_frame = 1. 4K run timed out after 3 shots and
  its tree hid RAMPAGE at 125% -> stats scroll; species select CHOOSE off screen at 115/125%
  -> shorter preview. Both shown failing in the new check first. 4K now uses --ui-only.

## Lead review 2 (FIX) -> done in 2ebdfce
1. Tree at 125%: shrinks to fit (Control + scale, never scrolls); check covers every node,
   shown failing first ("ULTIMATE: Brood at 125%").
2/3. Pause and report over the tree were my old --ui-only staging; the game only pauses in a
   rampage. --ui-only now runs a 45-frame live rampage, so both are shot over the city.
4. Reveal tower = BuildingView (city voxels/windows/shader), feet on the same ground line.
5. Cancelled 38999978259; clip now about 20 s at 1280x720.
6. (lead 16:45) #16 merged in; reveal tower cap from CityGrowth.for_stats(after)["city"];
   flow check: Apex Titan tower 28 floors (first city caps 26). Floors growth 24, flow 71.
Then: send the lead stills + clip + head SHA. Do not merge; Auto-fix off (lead).

## Findings for the lead (lead decides what gets recorded)
- Pull LFS in every new worktree before a test run (proven: 900 s timeout -> 51 s).
- Every CI capture before capture.yml's `lfs: true` has blank Kaiju Claw text.

## Open decisions
None for the director. Civilians count comes from the view (StreetLife.killed), not the sim.

## Running jobs
- CI captures round 4 on 2ebdfce: 1080p 39006384659, 4K insectoid --ui-only 39006409260,
  clip 720p 39006434429 -> %TEMP%/gf_cap/{shots,4k,clip}.
