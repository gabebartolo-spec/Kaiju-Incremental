# City-sound handoff, 2026-10-23
## State: holding for the lead go (no engine runs): swap in the 4 ElevenLabs loops from Downloads/kaiju_sfx_raw/city_beds/final/
## Task
City sound atmosphere for M1 (ROADMAP "Playtest milestones"), serving D-155 (panic then eerie quiet), D-125 (music in
layers), D-138 (new SFX from ElevenLabs, the lead generates). One driver reads the sim's destruction share and the
street's people-fled count, sets crowd / siren / distant gunfire / fire roar / wind beds from a data curve, and fades the
music stems on the same phase. Music briefs (docs/audio/music-briefs.md): stems drums, bass, lead, choir in fade-in
order; tempos 100 (baby), 120 (adolescent), 90 half-time (adult); a take's tempo can change (edit bpm and bars in data).
## Branch and commit
claude/city-sound, from origin/claude/look-options (95f01083). Pushed; tip = see `git log -1` (last report gives the sha).
PR body ready at scratchpad/city_sound_pr_body.md (Evidence, Not exercised, ElevenLabs specs, Board and log filled).
## What is built (all new files under 400 lines)
- `scenes/city_curve.gd` CityCurve: pure maths. phase(destruction, fled, population, cfg), level(bed, phase, cfg),
  along(keys, x), stem_db.
- `scenes/city_sound.gd` CitySound (Node): the one driver. advance(delta) is public so tests step it. Crowd = a TRIM
  on SfxCrowd.trim_db (the loop keeps its own panic level); other beds = absolute dB on looping players, played only
  when the file loads. Created by Rampage._start_sound (replaced the sfx.watch line; _ready did not grow).
- `scenes/music_layers.gd` MusicLayers (Node): ONE AudioStreamSynchronized on ONE player; a stem with no file is a
  silent AudioStreamWAV of exact bar length (shared); lock_error() flags a stem off the bar grid; warns at load.
  Real stems: `assets/music/city_N_<drums|bass|lead|choir>.ogg`, bars*4*60/bpm s long.
- `data/tuning.json`: "city_sound" (phase windows, curves), "music" (3 tracks), audio.sounds + 4 beds.
  `sfx_crowd.gd` +trim_db. `tools/sfx/build_city_beds.py` + 4 placeholder loops (+ hand-written .ogg.import).
- `tests/run_city_sound_tests.gd` + `tests/lib/city_sound_run.gd`; `tools/capture/capture_city_sound.gd` (per-bed RMS
  off the real mixer). Provenance + licensing rows + tests/README row added.
## Evidence so far
- city_sound 9/9 functions 87 checks 0 failures; failing first on planted bad curve (4 failures); smoke 13/13 42
  checks; flow 7/7 206 checks. gdformat/gdlint/ratchet/tuning_keys clean.
- Render (RTX 4070 SUPER, baby city run 0, 60 s): crowd peaks -30.5 dBFS RMS at 16 s, sirens -34.0 at 17 s, both silent
  from 49 s; last 10 s: fire -39.0, wind -46.6, gunfire -52.3.
## Attempts (fix-loop record)
- Editor import loops font errors in this checkout and never ends; the fix was copying `.godot/imported/*.ogg-*` and
  `kaiju_*` font data from vfx-lead's worktree and adding new class_names to global_script_class_cache.cfg with a
  script. Flow timed out twice before the font data was fixed (font error spam, 1.2M log lines), then passed in 284 s.
## Next (on the lead's go)
Replace assets/sfx/city_{siren,gunfire,fire,wind}.ogg with the finals (README in C:/Users/DANTE/Downloads/kaiju_sfx_raw/
city_beds/final/ has picks, levels, provenance); update docs/provenance/sfx.md and docs/LICENSING_REGISTER.md rows from
it (the placeholder rows become ElevenLabs rows; gunfire no longer built from rifle.ogg); check each loop's RMS and peak
against the specs; run city_sound, smoke, flow behind engine_slot.sh; push once.
## Open decisions (for the lead, not the director)
- Late-city beds are quiet (fire -39 dBFS RMS vs panic peak -30.5): raise the end keys of fire / wind / gunfire in
  tuning "city_sound" if the playtest wants them louder. Phase windows (destruction_full 0.2, fled_full 0.6) are
  calibrated on the scripted player (fast): a human rampage may need them wider.
## Running jobs
None.
## Findings for the lead
- godot_quiet.sh named in the first brief did not exist at that path; used tools/run_tests.sh and engine_slot.sh.
- A fresh worktree whose .godot is copied from another can carry bad font data: flow then times out on error spam.
  Compare md5 of `.godot/imported/kaiju_*.fontdata` with a working tree before blaming the change.
## Rules learnt the hard way
- Godot `--headless --write-movie` segfaults; render windowed with the no_focus override.cfg (create it in its own
  command first: the focus hook checks before the command runs) and delete it after.
- A compile error in a --script run makes the process hang to the timeout: use a short timeout on the first run.
