# Ability VFX/SFX handoff, 2026-10-18 09:10
## State: running a check (CI on #33 aa453bc, #34 31093be, #39 c9edc86; auto-fix ON). Asked the lead for the next job

## Who
Lead is "Game demo planning" / "LEAD", local_106fc100-d2a4-4091-bc9a-4bda31df13ac. It does QA gates and director listens.
The old lead (local_9fac90d2) is on P3 Tripo only. Report and ask for jobs at local_106fc100.
Say "awaiting lead" only after asking for the next job with options (memory-shared work-while-waiting).

## Done
- PR #8 is MERGED (47e1b30): power SFX, footsteps and stomps on foot plants, crack (capped 2.5 s), collapse,
  breath, ready, deflect, regen, croc roar on the evolution reveal (Sfx.roar).
  Logged as D-052 (r2 shipped as heard) and D-055 (roar on the reveal and end card).

## Open PRs
- **#33** claude/sfx-bus → claude/look-options, head aa453bc, flow 109 (the lead merges it via a watcher; push only to fix conflicts or CI).
  - (e) SFX and Music buses: PlayerSettings.BUSES/bus().
  - "Sound effects" slider (SettingsMenu.effects), sfx_volume saved in settings.cfg, default from tuning sfx
    default_volume 0.9.
  - (f) Menu sounds: Sfx.ui(sound) is static with one shared player. ui_click plays on every UiKit.button,
    ui_confirm / ui_deny on an upgrade buy.
  - demo_end.gd calls Sfx.roar(self) with each clip roar (roar_sounds); this only fires once ClipGait (#22) lands.
  - Evidence (shared notes side-session-notes/local_9fac90d2.../sfx-bus/):
    - settings_1080.png, settings_4k_ui125.png
    - ui_sounds.mp4 (real input: 3 clicks, confirm, deny)
- **#34** claude/army-sfx → base claude/sfx-bus (stacked), head 31093be (Sfx.watch keeps rampage.gd at 400 lines), flow 112, D-064 (menu sounds + slider shipped) in its Board and log.
  - tank_fire, shell_hit (unarmoured hits), heli_rotor loop.
  - Sfx.listener / play_at / rotors; tuning near_distance 80, far_floor_db -18.
  - Clips: army-sfx/tank_fire_shell_hit.mp4 (capture_sfx_clips.gd -- --army) and heli_rotor.mp4.
  - When #33 merges, retarget #34 to claude/look-options (`gh pr edit 34 --base claude/look-options`) and
    merge look-options in.

- **#39** claude/heli-sfx → base claude/army-sfx (stacked), head c9edc86, flow 112.
  - heli_gun and heli_crash via PowersView.sfx; Sfx.watch(camera, powers).
  - Clip: army-sfx/heli_gun_crash.mp4.
  - Retarget it as #33 and #34 land.

## Next
- Ask the lead for the next job (offered: footstep variety per surface, a Music bus track, Sonniss roars).
- Every sync: check `git log origin/claude/look-options -1` first. Floors are the real counts the suite prints.
- Run gdlint across the whole tree before a push. rampage.gd is at the 400-line cap; a merge can push it over.

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
