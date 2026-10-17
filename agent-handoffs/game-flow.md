# Game-flow handoff, 2026-10-17 20:05
## State: running a check (round-3 FIX: final 4K stills + clip on CI)

## Task
Make the loop around the rampage feel finished (brief from lead session local_9fac90d2):
1. end beat + results count-up vs previous best; 2. evolution reveal (skippable);
3. evolution tree polish (affordability, play-terms, branch band, ultimate capstone);
4. main menu, pause, settings (volume, fullscreen F11, controls, UI scale for the 4K TV);
5. save/reload/continue proven + save-migration test.
Done = PR into claude/look-options, CI green, CI-rendered screenshot per screen + a flow clip,
lead reviews first. No windowed Godot (director gaming): headless tests, CI captures only.

## Branch and commit
claude/game-flow-edfba4, pushed at e5c13c7 (look-options 414a290 merged: #16 city growth and
#20 Apex streaming; rampage.gd 398/400, rampage_sim.gd 399/400) (origin/claude/look-options merged in; rampage.gd
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
2. Done: stills + clip in docs/captures/2026-10-17-game-flow/, PR body Evidence filled,
   sent to lead 18:20. Next: lead's verdict / screen-critic round.
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
7. #20 merged in (floor load 6). Round-4 4K stills: tree/band/capstone fit, pause over the city,
   real building in the reveal; BUT reveal size lines fell off screen at 125% -> 3D view now
   takes the spare height; check shown failing first; flow 72. Layout checks moved to
   tests/lib/flow_layout.gd (400-line cap). Clip was 25 s at 1080p -> 1280x720 window + cuts.
Then: send the lead stills + clip + head SHA. Do not merge; Auto-fix off (lead).

## Lead review 3 (FIX, 18:17) -> done in 50a93f4
Tree = scenes/tree_area.gd (fills the space, never scaled; UpgradeNode.place picks 22..18 px
so words and lines fit); "need N" in side panel; side panel two-column stats, no scroll;
arrows drawn (UiKit.arrow, fonts lack U+2192); copy fixed; locked text lighter, no LOCKED;
report "Tallest tower toppled" in floors (Collapse.tallest_topple; save key renamed), every
row shows its best; HUD hides behind pause/report; reveal hint bigger, off the edge. Tower is
14 floors as stated (13 window rows + ground shopfront; crop in the reply). Flow 76.
4K run 39013803405 QA: "Regeneratio/n" broke mid-word and "0 FLOORS" broke the report column
-> 0149cdc: break-a-word check (failed first), real text width, "12k" prices, side 330 wide,
row "Tallest tower toppled (floors)". 4K 39015479637 QA: evolve node text touched its focus
border, side copy orphans -> e5c13c7 (margin = pad + the node's thickest border; NBSP).
Then: QA new captures, add to docs/captures, send lead.

## Findings for the lead (lead decides what gets recorded)
- Pull LFS in every new worktree before a test run (proven: 900 s timeout -> 51 s).
- Every CI capture before capture.yml's `lfs: true` has blank Kaiju Claw text.

## Open decisions
None for the director. Civilians count comes from the view (StreetLife.killed), not the sim.

## Running jobs
- CI on e5c13c7: 4K 39016554227 -> %TEMP%/gf_cap8/4k; clip 39016580665 -> %TEMP%/gf_cap8/clip.
