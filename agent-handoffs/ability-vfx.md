# Ability VFX/SFX handoff, 2026-10-18 10:10
## State: running a check (CI on #39 1c66048 and the limiter PR). Next: (g) footstep variants with round-robin

## Who
Lead is "Game demo planning" / "LEAD", local_106fc100-d2a4-4091-bc9a-4bda31df13ac. It does QA gates and director listens.
The old lead (local_9fac90d2) is on P3 Tripo only. Report and ask for jobs at local_106fc100.
Say "awaiting lead" only after asking for the next job with options (memory-shared work-while-waiting).

## Done
- PR #8 is MERGED (47e1b30): power SFX, footsteps and stomps on foot plants, crack (capped 2.5 s), collapse,
  breath, ready, deflect, regen, croc roar on the evolution reveal (Sfx.roar).
  Logged as D-052 (r2 shipped as heard) and D-055 (roar on the reveal and end card).

## Merged
- #33 (bus, slider, menu sounds; D-064) and #34 (army sounds; D-067). Their branches are gone.

## Open PRs
- **#39** claude/heli-sfx → look-options, head 1c66048, flow 112. Heli gun and crash; waits for the director's listen.
- **Limiter PR** claude/sfx-limiter → look-options, flow 113.
  - PlayerSettings._dynamics(): AudioEffectCompressor on SFX (-6 dB, 2:1, 5 ms, 250 ms) and
    AudioEffectHardLimiter on Master (ceiling -1 dB, release 0.1). Values in tuning sfx.dynamics.
  - Proof: tools/capture/capture_loud.gd stacks breath, 2 collapses, 3 tanks, stomp_2, crack and roar three times.
    - Before: peak 0.0 dBFS, 409 clipped samples.
    - After: peak -2.9 dBFS, 0 clipped.
    - Tail (normal play) RMS is only 0.5 dB lower, so no pumping.
  - Clips are in shared notes sfx-limiter/.

## Next
- (g) 3-4 footstep variants with round-robin. (h) Sonniss roars waits for the director.
- Every sync: check `git log origin/claude/look-options -1` first. Squash merges mean "keep look-options'
  version of the merged PR's lines; add only mine". Floors are real counts. Run gdlint over the whole tree
  before a push. rampage.gd is at 400 lines.

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
