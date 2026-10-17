# Ability VFX/SFX handoff, 2026-10-18 13:50
## State: available (rifle PR #46 open; everything open is tabled for the director's listen)

## Who
- Lead is "Kaiju: Lead", local_106fc100-d2a4-4091-bc9a-4bda31df13ac. It does QA gates and director listens.
- The director is asleep, so anything for his ear is tabled with the lead.
- Report to the lead and ask for jobs, always naming 2-3 options. Never just "await".

## Merged
- #8: power SFX, footsteps and stomps on plants, crack, collapse, roar on the reveal. D-052, D-055.
- #33: SFX/Music buses, Sound effects slider, menu sounds, end-card Sfx.roar. D-064.
- #34: tank fire, shell hit, heli rotor. D-067.
- #41: Master limiter + SFX compressor.

## Open PRs (each → claude/look-options; all tabled for the director's listen, none merge tonight)
- **#39** claude/heli-sfx, head 2ecdbe0, flow 113: heli gun and crash. Clip army-sfx/heli_gun_crash.mp4.
- **#42** claude/footstep-variants, head aadc2f6, flow 114: footstep_1..3 round-robin. Clips in footsteps/.
- **#43** claude/crowd-sfx, head 8d37511, flow 114: crowd_panic loop.
  - Driven by StreetLife.panicking() and the destruction rate; ducks 9 dB under breath; high-passed at 300 Hz.
  - Sfx.watch(camera, helis, street). Clips in crowd/.
- The PRs collide on flow floors and on the sfx.watch line (#39 vs #43). Resync to the real counts as each lands.

- **#46** claude/rifle-sfx, head ad1f436, flow 116 (look-options has #40).
  - rifle.ogg; rooftop_view plays it with play_at at the squad (_squad_at).
  - Clip: rifle/rifle_volleys_in_game.mp4.
- #45 (mix levels) is stacked on #43.

## Job (o): mix report DONE (shared notes mix-report/report.md, run clip, log, raw tables)
- Master -21.4 LUFS, -3.9 dBTP. Loudness order is right.
- Problems: crowd inaudible (-44 LUFS, 26 dB under); regen loop on 86% of the run; tank_fire's thump masks stomps.
- Proposal (not applied, waits for the director's listen):
  - crowd -14 → -6 dB, quiet_db -30 → -24;
  - regen -20 dB, first 2.5 s per heal only;
  - tank_fire high-passed at 120 Hz.
- Tools: claude/mix-report (pushed, no PR) has tools/capture/capture_mix_log.gd and tools/sfx/mix_report.py.

## Job (o2) DONE: PR #45 claude/mix-levels → base claude/crowd-sfx (stacked on #43), flow 115
- crowd -6 dB (quiet -24), regen -20 dB as a 2.5 s cue per heal, tank_fire high-passed at 120 Hz.
- Re-measured: crowd gap -18.9 dB, regen on 6%, master -20.5 LUFS / -3.9 dBTP all met.
  Stomps masked by army 15 → 8, not 0: it's shell_hit's thud; a 120 Hz high-pass on it is the next step if wanted.
- A/B: mix-report/ab_before_after_20s.mp4. Report section 5 has the after numbers.
- When #43 merges, retarget #45 to look-options.

## Next
- Queue: (h) Sonniss roars waits for the director; (k) Atomic Beam waits (outside the demo). Ask the lead for more.
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
CI on #39, #42 and #43. No Godot, no override.cfg.
