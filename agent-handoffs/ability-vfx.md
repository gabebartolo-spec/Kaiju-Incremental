# Ability VFX/SFX handoff, 2026-10-18 10:40
## State: running a check (CI on #39, #41, #42; auto-fix ON for all). Asked the lead for the next job

## Who
- Lead is "Kaiju: Lead", local_106fc100-d2a4-4091-bc9a-4bda31df13ac. It does QA gates and director listens.
- The director is asleep, so anything for his ear is tabled with the lead.
- Report to the lead and ask for jobs, always naming 2-3 options. Never just "await".

## Merged
- #8: power SFX, footsteps and stomps on plants, crack, collapse, roar on the reveal. D-052, D-055.
- #33: SFX/Music buses, Sound effects slider, menu sounds, end-card Sfx.roar. D-064.
- #34: tank fire, shell hit, heli rotor. D-067.

## Open PRs (each → claude/look-options)
- **#39** claude/heli-sfx, head 1c66048, flow 112.
  - Heli gun and crash via PowersView.sfx; Sfx.watch(camera, powers).
  - Clip: army-sfx/heli_gun_crash.mp4. Waiting for the director's listen.
- **#41** claude/sfx-limiter, head 89cef13, flow 113.
  - Compressor on SFX and a HardLimiter (-1 dB) on Master, via PlayerSettings._dynamics(); tuning sfx.dynamics.
  - Stacked worst case: peak before 0.0 dBFS with 409 clipped samples; after -2.9 dBFS, 0 clipped.
    Normal play is -0.5 dB.
  - Clips: sfx-limiter/.
- **#42** claude/footstep-variants, head 9e47407, flow 113.
  - footstep_1..3 plus Sfx.STEPS round-robin.
  - Clips: footsteps/walk_in_game.mp4 and footstep_round_robin.wav.
- #39, #41 and #42 each add to flow on a 112 base. Whichever merges later needs a floor resync to the real count.

## Next
- The lead's queue is done except (h), Sonniss roars, which waits for the director (taste + licence).
  Ask the lead for more.
- Every sync: check `git log origin/claude/look-options -1` first.
  - Squash merges: keep look-options' version of the merged PR's lines, then add only mine.
  - Floors are the real counts the suite prints.
  - Run gdlint over the whole tree before a push. rampage.gd is at the 400-line cap.

## How-to
- Godot: /c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
  - Tests: GODOT=<that> SUITES_ONLY=1 tools/run_tests.sh [suite...]
  - Windowed captures need override.cfg written in its own command first (a hook checks), and deleted after.
- Sounds: python tools/sfx/build_sfx.py --kenney C:/Users/DANTE/AppData/Local/Temp/claude/sfx_dl.
  The Kenney CC0 packs are unzipped there, outside the repo. Revert unchanged rebuilt oggs (only the serial differs).
- Clips: tools/capture/capture_sfx_clips.gd ("-- --army" for tanks and helis), capture_roar.gd,
  capture_ui_sounds.gd, capture_loud.gd. Use --write-movie, then imageio_ffmpeg's ffmpeg.
  Shared notes live at side-session-notes/local_9fac90d2.../.
- Do NOT edit scenes/kaiju_rig.gd or scenes/kaiju_model.gd.

## Running jobs
CI on #39, #41 and #42. No Godot, no override.cfg.
