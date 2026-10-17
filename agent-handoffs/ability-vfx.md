# Ability VFX/SFX handoff, 2026-10-18 12:00
## State: running a check (2-min mix capture, bash blpfr5jk5) for job (o): the mix measurement report

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
- **#43** claude/crowd-sfx, head 272a285, flow 114: crowd_panic loop.
  - Driven by StreetLife.panicking() and the destruction rate; ducks 9 dB under breath; high-passed at 300 Hz.
  - Sfx.watch(camera, helis, street). Clips in crowd/.
- The PRs collide on flow floors and on the sfx.watch line (#39 vs #43). Resync to the real counts as each lands.

## Branch waiting
- claude/rifle-sfx (b1a43d2, pushed, no PR): rifle.ogg plus the Sfx "rifle" stream, for #40 (rooftop defenders),
  which calls Sfx.play("rifle").
  - After #40 merges: merge look-options in, change rooftop_view's call to play_at("rifle", <squad pos>)
    for the distance fade, add a flow check, record a clip, then open the PR.
  - A/B listen: rifle/rifle_vs_tank.wav.

## Job (o): mix measurement report (lead: report + proposal only, no level changes before the director listens)
- Branch claude/mix-report (off claude/crowd-sfx, local, not pushed):
  - tools/capture/capture_mix_log.gd logs every sound (frame, name, volume dB, pitch) and the loop volumes;
    2 min of croc Behemoth autoplay with helicopters.
  - tools/sfx/mix_report.py rebuilds per-category stems and measures LUFS and true peak (ffmpeg ebur128),
    share of energy, and masking (SMR < 3 dB in the category's band), alongside the real master mix.
- Output goes to scratchpad/mix/, then the report and proposed level table go to shared notes mix-report/,
  then tell the lead.

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
CI on #39, #42 and #43. Godot capture running (mix); override.cfg is present until it ends; delete it after.
