# Unity port: handoff

Cap: 160 lines. Where the Godot to Unity port stands on 2026-11-27, written so that a fresh Claude, on another account
with only this repo, can carry on. Read it with `CLAUDE.md`, the "Unity port" section of `docs/ROADMAP.md`,
`docs/U6_SWITCH.md` and `unity/README.md`. Replace this file's contents when you hand the work on again.

## Where the port stands (main at da4e609)
- **U0 to U3: done.** The slice runs on HDRP. Unity's flames won (D-473). The sim is plain C#, bit for bit with Godot
  (`tools/unity/gd2cs.py`; after any `sim/` or `data/` change, run `bash tools/unity/regen_sim.sh`). Settle and water
  run on the plain DLL in `unity/native/`.
- **U4 (the rampage on screen): open, and only look polish is left (D-476).** The numbered list ran from item 3 to
  item 18 and is all merged (#623 to #640). Item 16, night lighting that follows the time, was skipped on purpose:
  players only get dusk (D-359), so it shows only in captures. Look polish (voxel AO, crease pass, soft smoke) waits
  for the director.
- **U5 (game flow): open.** Unity plays the whole loop with saves:
  - title (3 slots), settings, the creation lab, globe, loading, rampage (HUD, pause, photo mode, report), results,
    mission stub, tree, then demo end;
  - the old `save.json` is adopted into a slot (#643);
  - a rampage loads in about 12 s (#641), behind Godot's 7-stage meter and first-load note (#650, #651).

  Merged on 2026-11-26/27:
  - title smoke noise exactly as Godot's (#652, `Sim/GodotNoise.cs`, checked in `SimTests/NoiseCheck.cs`);
  - lab liquids and injector (#653);
  - lab pour stills (#654);
  - the genome helix and lightning in the dish (#655: `GameLogic/CreationGenome.cs`, `Game/Ui/CreationGenomeView.cs`).
- **U6 (parity and switch): open.** The CI part is done (#615). The plan is `docs/U6_SWITCH.md`. The director's
  playtest of both engines waits until U4 and U5 are done (D-485).

## Open items, in order
1. **Build-check #655 in Unity on the PC.** CI compiles only `GameLogic/` and `Sim/` (the `sim-csharp` job). The
   `Game/Ui` view (`CreationGenomeView.cs`) and the wiring in `CreationSteps.cs` and `CreationScreen.cs` have never
   been compiled. Build once, then look at the dish at the strike and at the overload beside Godot's
   `capture_creation.gd` stills. The lamp is matched with `lab_bolt_match_m` (0.45 in `StreamingAssets/tuning.json`,
   read in `SliceData.cs`), because HDRP's falloff is 1/d² where Godot's is 1/d. Tune that value; don't change the
   code.
2. **#575, the adult croc's head-down charge (Godot side, an open PR, so allowed under D-472).** It is green but
   conflicts with main in one file only: the binary `assets/kaiju/reptilian_adult.kclip`, which #576 (the tail
   replaces the claws) rebaked after #575 opened. The director chose to rebake it on the PC (2026-11-27). Steps:
   - merge origin/main into `claude/croc-charge` (no rebase or force-push);
   - rerun `tools/blender/croc_adult3_clips.py` in Blender so that one bake holds both the tail and the charge;
   - commit the new `.kclip` (it is LFS);
   - check the charge and the tail in game (`tools/capture/capture_walks.gd`);
   - merge when CI is green.

   The PR body's captures are in `C:/kt/drafts/croc-charge/`.
3. **Title screen against Godot** (findings made, nothing fixed). WIP branch `claude/title-smog-wip` holds debug
   toggles only and has no PR.
   - The colossus glow is larger and brighter than Godot's.
   - The bay fire streaks burn white where Godot's stay orange, and Godot's thin orange waterline is missing.
   - The middle smog is about 2x too bright. The cause is smog layer 0, the low orange bank, which probably draws in
     front of layers 1 and 2 in Unity. Without it the reading is 43,16,7 against Godot's 46,20,6. Bloom is not
     involved.
   - The exit button is lighter (Unity 110,109,109 at alpha 136, Godot 97,97,99 at 121). Unity blends UI in linear,
     Godot in sRGB. **Changing UI blending needs the director's OK:** ask with a decision card.
4. **Croc colours and ground shading** against Godot.
5. **The rest of the U5 screen-by-screen stills** (one per engine per screen), and the lab's agar burn at the
   overload, which `creation_genome.gd` does and Unity does not port yet.
6. **U5 known gaps that are not bugs.**
   - Godot streams buildings (`building_stream.gd`). Unity bakes every site up front, and a faithful port was sized
     at about 800 lines, so it is deferred.
   - Unity saves to `Application.persistentDataPath`, not Godot's `user://`. U6 must move or find Godot players'
     saves.
   - The far blur (DOF) ships at 0 (D-360).
7. **After the port: the look pass.** Apply dream-loop (https://github.com/achimala/dream-loop) to the game. The
   director has Gemini and Tripo for image generation. Any generated asset still goes through
   `docs/LICENSING_REGISTER.md` before it enters `assets/`. There is no runtime AI (hard rule 1).
8. Stale doc line: `unity/README.md` says the approved croc's export is on PR #579 "until it merges". #579 was
   closed without merging, so ask the director where the approved croc export lives before you rely on that line.

## How the work runs
- **The cloud session has no dotnet, Unity or Godot.** Write the code there and let CI check it:
  - `sim-csharp` runs `unity/SimTests` against Godot's logs (GameLogic and Sim only);
  - `project-lints`, `licence-register` and `doc-caps` run the lints;
  - the engine suites run on main only.
- **Before you push, run the lints you can:**
  - `bash tools/lint/check_cs.sh`, which covers:
    - complexity: methods ≤40 lines, cyclomatic complexity ≤12, new files ≤400 lines, baselined items may not grow
      (shrink the baseline with `--shrink` after a move);
    - magic numbers: `Sim/` is excluded and consts are exempt (`--update` shrinks the baseline);
    - `.meta` files: `fileFormatVersion: 2`, then `guid: <hex>`, with no trailing newline;
  - `python tools/lint/licence_register.py`;
  - `python tools/run_touched.py`.
- **For exactness ports, reuse the Godot copies, and cite the `.gd` file you port in the header:**
  - Godot's RNG: `Seeds.Make` (`Randf`, `RandfRange`);
  - `GodotSort.Sort`, the same order as Godot's sort;
  - `Vector2` in float32, with `FromAngle`;
  - `Gd.Roundi` (rounds half away from zero), `Floori`, `Clampf`, `Signf` and `TAU`.

  When no runtime is available, check against a C++ reference built with g++ from Godot's own sources (that is how
  `NoiseCheck.cs` got its golden values).
- **The PC (Windows, `C:/kt/`; worktrees in `../Kaiju-Incremental-wt/<topic>`).** Reach it with a Remote Control
  session only when the director has allowed PC use in his own words.
  - Windowed runs go through `bash C:/kt/gpu_slot.sh <command>`.
  - The player build is `SliceBuild.BuildRampage` (batch mode) to `unity/Build/KaijuRampage.exe`. The release zip is
    `tools/unity/build_release.py` (it never uploads).
  - `-flow-smoke` plays the whole loop (`-flow-continue` adds the second process). `-flow-still <dir>` writes a
    1080p PNG per screen. The rampage flags are `-rampage-*` (time, seed, stage and so on: see `GameFlow.cs`).
    `-quiet-window` keeps the window off the screen.
  - Shots live in `C:/kt/shots/<topic>/`.
- **Keep PC use light (the director's rules):**
  - one build or run at a time, and nothing left running in the background;
  - after each PR, delete its temporary builds and stills;
  - stop if C: drops under 30 GB;
  - delete only obsolete Kaiju dev files;
  - don't touch the casc bridge.

  He stopped PC use twice on 2026-11-26 over heavy use. It is paused now: wait until he asks again.
- **Gotchas.**
  - Unity stills taken before #645 (2026-11-26) are too bright: sRGB was encoded twice, so darks lift and reds turn
    salmon. Retake those before comparing numbers. His own window screenshots are true.
  - Binary `.kclip` files can't be merged. Any two PRs that rebake the same clip file conflict, so rebake one on top
    of the other.
  - `docs/STATUS.md` is generated by `python tools/status.py` and needs `gh` for the PR lists. In a session without
    `gh`, a shim that feeds it the same JSON from the GitHub API works (done in #656).

## Working with the director (Baggins)
- **Blocked on him:** any approval, permission prompt, choice or PC access. Post a decision card, never just a
  sentence. After he acts, check that the work actually started (for example the Remote Control status) and say so.
  A card once sat unapproved for 2 hours after "ok go", and he was rightly angry.
- **Act fast and directly** on urgent asks; don't relay through slow hops. Don't check in for progress.
- **Merge your own PRs when CI is green** (he said "keep working, stop checking in" on 2026-11-26). One PR per
  change, using the template's headings, with the evidence in the body.
- **Reuse existing captures and stills** before shooting new footage. Don't ask him to describe a visual bug you can
  see in a capture yourself. Never guess at a visual: show it and ask.
- **Don't react with the eyes emoji** on his messages. He is in Australia/Sydney.
