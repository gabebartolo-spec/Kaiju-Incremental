# City-growth handoff, 2026-10-17 17:30
## State: awaiting lead (Apex playability PR open; do not merge; head SHA sent to the lead)

## Task
Lead 16:45, after #16 (D-039 city growth) merged at 13870b3: APEX PLAYABILITY, one PR into
claude/look-options. (1) Profile the Apex city build, fix the top cost, Apex rampage load under
15 s on the local GPU, no stage slower, a test that party-wall pairs grow ~linearly. (2) The
kaiju hidden behind towers at the game camera: screen-door buildings between the camera and the
kaiju (D-025 rule, the vehicles' 35% look from #18); never move the camera. Evidence: load
times before/after per stage, game-camera stills stages 3-4 before/after, a ~20 s clip. Keep
balance proposal D and the Apex height question out (tabled for the director).

## Branch and commit
claude/apex-playability (cut from origin/claude/look-options 13870b3), checked out in the
worktree folder .claude/worktrees/city-growth-e79d28 (the app's EnterWorktree isolation blocked
Godot runs and cross-worktree writes, so the fresh worktree was removed and the branch moved
here). Old branch claude/city-growth-e79d28 is merged (#16). Pushed; PR open.

## What is built
- tools/capture/profile_city.gd: per-phase load profile (headless), --full = old load.
- BuildingView.party_walls: spatial grid (PARTY_CELL 8), pair_checks counter. 5.9M -> 11k
  pairs at Apex, 1733 -> 17 ms. The suspect was NOT the top cost.
- Top cost was meshing (BuildingVoxels + BuildingMesher, ~0.37 ms per chunk on threads, 129 s
  headless at Apex). Fix: scenes/building_stream.gd (BuildingStream) meshes the nearest
  buildings up to city.load_chunks (20000, data) before the rampage, draws the rest as facade
  stand-ins (CitySkyline.facade_material), streams them in on worker threads nearest first;
  view(n) builds on demand so a hit never lands on a stand-in. CityView uses _stream.view(i).
- scenes/building_fade.gd (BuildingFade) + building_baked.gdshader opacity/Bayer screen door +
  BuildingView.set_opacity: towers cutting sight lines from the camera to 9 points over the
  kaiju (3 heights x 0/1/2 body radii along its facing) ease to vehicles.fade_opacity.
  Run from CityView._process (rampage.gd untouched: it sits at the 400-line cap).
- tests/run_load_tests.gd (new suite "load", floor 6; ALL_SUITES + shard 1): grid == all pairs,
  pairs ~linear, sight test, stream budget / on-demand / completes.
- tools/capture/capture_occlusion.gd: Apex walk-up-the-street clip from the game camera.

## Evidence
- GPU (RTX 4070 SUPER) city view build: young 5.9 -> 5.1 s; Behemoth 9.9 -> 8.0 s (before =
  load_chunks unlimited); Colossus 40-42 -> 8.9-9.2 s; Apex 167-184 -> 12.8-13.4 s.
- Headless rest-streamed-in times: Behemoth 0.9 s, Colossus 24 s, Apex 107 s.
- Stills: docs/captures/2026-10-17-apex-playability/ (board_game_camera_before_after.png,
  growth_4_game_crop2x.png, growth_N_game.png, apex_walk_frames.png). Clip: shared notes
  folder apex-playability/apex_occlusion.mp4 (20 s, 720p, GPU, not in the repo).
- Full local run green: smoke 27, sim 39, powers 24, tentacles 18, city 5, growth 24, load 6,
  flow 26, harness self-test; gdlint/gdformat clean (100 files).

## Attempts
- First sight test aimed straight above the feet: missed the torso (the model's body runs
  forward along its facing); aiming 0/1/2 body radii ahead fixed it (crop proves it).
- EnterWorktree isolation refused Godot runs (paths containing "GitHub" read as git); exited.

## Open decisions
- Balance proposal D and the Apex height question: director (via the lead), not in this PR.
- The worktree folder name no longer matches its branch; the lead may want it re-homed later.

## Running jobs
None. override.cfg deleted after every GPU run; no Godot left running.

## Findings for the lead
- Profile before fixing: the obvious O(n^2) suspect cost 1.7 s; meshing cost 129 s. A per-phase
  profiler (tools/capture/profile_city.gd) settled it in one headless run.
- A screen-door sight test must aim at the model's real mass (torso/head ahead of the feet),
  not its origin; check with a 2x crop.

## Rules learnt the hard way
- One Godot at a time while the director games; GPU windowed runs only off-screen with
  override.cfg written by the file tool first (the focus guard checks before the command runs).
- Godot movie AVI -> mp4 here: pip imageio-ffmpeg's bundled ffmpeg (no system ffmpeg).
