# City-sound handoff, 2026-10-23
## State: paused (no Godot until 03:28 per the director); suites, planted-curve run and audio render still to run
## Task
City sound atmosphere for M1 (ROADMAP "Playtest milestones"), serving D-155 (panic then eerie quiet), D-125 (music in
layers), D-138 (new SFX from ElevenLabs, the lead generates). One driver reads the sim's destruction share and the
street's people-fled count, sets crowd / siren / distant gunfire / fire roar / wind beds from a data curve, and fades the
music stems on the same phase. Lead's later note: stems per city are drums, bass, lead, choir/pads in that fade-in order;
tempos 100 (baby), 120 (adolescent), 90 half-time (adult) (docs/audio/music-briefs.md). Tempo can change per take.
## Branch and commit
claude/city-sound, from origin/claude/look-options (95f01083). PR against claude/look-options (not yet open).
## What is built (all new files under 400 lines)
- `scenes/city_curve.gd` CityCurve: pure maths. phase(destruction, fled, population, cfg), level(bed, phase, cfg),
  along(keys, x), stem_db.
- `scenes/city_sound.gd` CitySound (Node): the one driver. advance(delta) is public so tests step it. Crowd = a TRIM
  on SfxCrowd.trim_db (its own panic level stays); other beds = absolute dB on looping players, played only when the
  file exists. Created by Rampage._start_sound (replaces the sfx.watch line; _ready did not grow).
- `scenes/music_layers.gd` MusicLayers (Node): ONE AudioStreamSynchronized on ONE player; stems silent placeholders
  (AudioStreamWAV zeros of exact bar length, shared) until `assets/music/city_N_<stem>.ogg` exists; lock_error() flags a
  stem off the bar grid; warns at load.
- `scenes/sfx_crowd.gd`: + trim_db (4 lines). `data/tuning.json`: "city_sound" (phase, curves), "music" (3 tracks:
  bpm, beats_per_bar, bars, stems with enter/full), audio.sounds + 4 beds on Ambience/Military buses.
- `tools/sfx/build_city_beds.py` + `assets/sfx/city_{siren,gunfire,fire,wind}.ogg`: in-house PLACEHOLDER loops
  (levelled to target RMS); gunfire built from rifle.ogg. Provenance + licensing rows added.
- `tests/run_city_sound_tests.gd` + `tests/lib/city_sound_run.gd` (sim-fed fixture, real RampageSim + StreetLife, pinned
  seeds); README row. `tools/capture/capture_city_sound.gd`: per-bed RMS per second off the real mixer.
## Unfinished changes
- Calibrate city_sound.phase (destruction_full 0.12, fled_full 0.6 are guesses) from a measured run, so phase reaches
  ~1 within a rampage's length. Then run the suite, show it failing on a planted bad curve, run smoke + flow.
- Render: windowed off-screen run with override.cfg (no_focus, position -20000) and --write-movie; --headless
  --write-movie SEGFAULTS (no frame to read), so headless cannot be used for the audio render.
- Fill in PR body: Evidence, Not exercised, ElevenLabs spec list.
## Evidence so far
- tuning_keys.py ok, complexity_ratchet ok (rampage._ready unchanged at 57 lines).
## Attempts (fix-loop record)
- Import: `--headless --import` loops font errors forever in a fresh worktree; seeded .godot from status-check-b96b26
  and added the new class_names to .godot/global_script_class_cache.cfg with a script (no editor import needed).
## Open decisions
None for the director. The curves and stem enter/full windows are my starting numbers (balance tunables, not design).
## Running jobs
None kept alive on exit.
## Findings for the lead
- godot_quiet.sh named in the brief does not exist at that path; used tools/run_tests.sh rules instead.
## Rules learnt the hard way
- Never Godot `--headless --write-movie`: it segfaults. A new class_name needs the cache entry before a --script run.
