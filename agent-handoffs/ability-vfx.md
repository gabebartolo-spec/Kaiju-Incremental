# Ability VFX/SFX handoff, 2026-10-18 07:45
## State: running a check (CI on PR #33 bd97471 and PR #34 9f12f62, auto-fix ON for both). Next: (d) heli gun + crash

## Who
Lead is "Game demo planning" / "LEAD", local_106fc100-d2a4-4091-bc9a-4bda31df13ac. It does QA gates and director listens.
The old lead (local_9fac90d2) is on P3 Tripo only. Report and ask for jobs at local_106fc100.
Say "awaiting lead" only after asking for the next job with options (memory-shared work-while-waiting).

## Done
- PR #8 is MERGED (47e1b30): power SFX, footsteps and stomps on foot plants, crack (capped 2.5 s), collapse,
  breath, ready, deflect, regen, croc roar on the evolution reveal (Sfx.roar).
  Logged as D-052 (r2 shipped as heard) and D-055 (roar on the reveal and end card).

## Open PRs
- **#33** claude/sfx-bus → claude/look-options, head bd97471, flow 107.
  - (e) SFX and Music buses: PlayerSettings.BUSES/bus().
  - "Sound effects" slider (SettingsMenu.effects), sfx_volume saved in settings.cfg, default from tuning sfx
    default_volume 0.9.
  - (f) Menu sounds: Sfx.ui(sound) is static with one shared player. ui_click plays on every UiKit.button,
    ui_confirm / ui_deny on an upgrade buy.
  - demo_end.gd calls Sfx.roar(self) with each clip roar (roar_sounds); this only fires once ClipGait (#22) lands.
  - Evidence (shared notes side-session-notes/local_9fac90d2.../sfx-bus/):
    - settings_1080.png, settings_4k_ui125.png
    - ui_sounds.mp4 (real input: 3 clicks, confirm, deny)
- **#34** claude/army-sfx → base claude/sfx-bus (stacked), head 9f12f62, flow 110.
  - tank_fire, shell_hit (unarmoured hits), heli_rotor loop.
  - Sfx.listener / play_at / rotors; tuning near_distance 80, far_floor_db -18.
  - Clip: army-sfx/heli_rotor.mp4. There is no tank-fire clip: no tank fired in the 20 s seed.
  - When #33 merges, retarget #34 to claude/look-options (`gh pr edit 34 --base claude/look-options`) and
    merge look-options in.

## Next
- (d) Heli gun burst (PowersView._heli_fired) and heli crash (_heli_down), on top of claude/army-sfx.
  Use Sfx.play_at, add the build_sfx.py sounds plus provenance rows, add flow checks, and record a clip.
- Every sync: check `git log origin/claude/look-options -1` first. Floors are the real counts the suite prints.

## How-to
- Godot: /c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
  - Tests: GODOT=<that> SUITES_ONLY=1 tools/run_tests.sh [suite...]
  - Windowed captures need the no-focus override.cfg written first in its own command (a hook checks), and
    deleted afterwards.
- Sounds: python tools/sfx/build_sfx.py --kenney C:/Users/DANTE/AppData/Local/Temp/claude/sfx_dl.
  The Kenney CC0 packs are unzipped there, outside the repo. Rebuilt unchanged oggs differ only by stream
  serial, so `git checkout` them.
- Clips: tools/capture/capture_sfx_clips.gd (logs "SOUND <frame> <name>"), capture_roar.gd, capture_ui_sounds.gd.
  Run them with --write-movie, then cut with imageio_ffmpeg's ffmpeg.
- Do NOT edit scenes/kaiju_rig.gd or scenes/kaiju_model.gd.

## Running jobs
CI on #33 and #34. No Godot, no override.cfg.
