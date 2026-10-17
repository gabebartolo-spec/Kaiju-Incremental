# Ability VFX/SFX handoff, 2026-10-18 15:20
## State: available (#46 resynced to look-options 39acc0a = #38 + #47; others resync as they come up)

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

## Branch waiting
- claude/rifle-sfx (b1a43d2, pushed, no PR): rifle.ogg plus the Sfx "rifle" stream, for #40 (rooftop defenders),
  which calls Sfx.play("rifle").
  - After #40 merges: merge look-options in, change rooftop_view's call to play_at("rifle", <squad pos>)
    for the distance fade, add a flow check, record a clip, then open the PR.
  - A/B listen: rifle/rifle_vs_tank.wav.

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

## Sync status (#39/#42/#43/#45 on look-options f71c527; #46 on 39acc0a; base flow is now 117)
| PR | Head | Flow |
|---|---|---|
| #39 heli | bac13d7 | 116 |
| #42 footsteps | dc8fd13 | 117 |
| #43 crowd | c216ac0 | 117 |
| #45 mix (on #43) | 9acb9e2 | 118 |
| #46 rifle | c871803 (on 39acc0a) | 118 |

- run_flow_tests.gd is at 393 lines on look-options. Each PR keeps its added checks in its own tests/lib file:
  flow_heli_sounds, flow_step_sounds, flow_sounds (crowd + regen), flow_rifle_sounds.
  So the PRs merge in any order with only a floor resync.
- The lead merges them one at a time in the director's order and pings me. Resync each to the real count.

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
