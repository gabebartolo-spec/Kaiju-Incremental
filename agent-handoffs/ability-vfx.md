# Ability VFX/SFX handoff, 2026-10-18 20:00
## State: running a check (#39 resync suites, bash bf7dmkgzh; merge of look-options 0817cf6 uncommitted on claude/heli-sfx)

## Who
- Lead is "Kaiju: Lead", local_106fc100-d2a4-4091-bc9a-4bda31df13ac. It runs the QA gates and the director's listens.
- Report to the lead and ask for jobs, always naming 2-3 options. Never just "await".

## Merged
- #8 power SFX, steps and stomps, crack, collapse, roar (D-052, D-055).
- #33 buses, slider, UI sounds (D-064).
- #34 tank fire, shell hit, rotor (D-067).
- #41 limiter and compressor.
- #43 crowd.
- #45 mix fixes (look-options 0817cf6).

## Merge chain (D-070, director shipped all sounds). The lead merges one at a time; I resync each right after the previous lands
- **#39 claude/heli-sfx (resyncing now, onto 0817cf6).** Conflicts resolved, keeping both sides:
  - tuning heli_gun/heli_crash plus crowd_panic -6;
  - provenance rows heli plus crowd;
  - rampage.gd `sfx.watch(_camera, _powers, _city.street)`;
  - sfx.gd `watch(camera, powers: PowersView, street: StreetLife)` sets listener, _powers, powers.sfx = self, _street.
  - Left to do: read the real flow count (look-options floor 131), set tests/expected_checks.txt, lint, commit the merge, push, send the SHA to the lead.
- **#42** claude/footstep-variants (ef73246): resync after #39 lands.
- **#46** claude/rifle-sfx (e520b7b): resync after #42 lands.
- **Gap job (a), after #46:** a small PR off look-options.
  - Change: shell_hit high-passed at 120 Hz in tools/sfx/build_sfx.py:335, as `highpass(highpass(x,120),120)`, like tank_fire.
  - Evidence: an A/B clip plus masking numbers (capture_mix_log.gd plus mix_report.py; stomps masked by army is now 8).
  - Tabled for the director's listen.

## #36 claude/army-scales (D-069), pushed 4b3146c; waits for #50
- Local branch army-scales-sync (handoff commit 7b0db6d is local only). Push with `git push origin HEAD:claude/army-scales`.
- Pacing at 4b3146c (130 runs):
  - young: 31 runs, 0.62 h, ended 3/28/0;
  - Behemoth: 45 runs, 37/7/1;
  - Colossus: 54 runs, 29/25/0.
- **D-069a:** young defeats of 28/31 are too punishing; aim for about half (before #36: 16/28).
  - Cause: young per_level is already {}. #36 moved Armoured Scales behind Endless Rage (330 rubble).
  - Fix in data only: a stages[0] "army" override (tank_damage, maybe start_interval).
  - Sweep script: scratchpad/young_sweep.sh (45 runs per spec; edits and then restores data/tuning.json).
    WARNING: stopping it left its shell alive, and it copied #36's tuning over the #39 merge after the branch switch.
    Before any switch, confirm no bash process mentions young_sweep.
  - The sweep was stopped for #39 after the baseline only ({} gives 3/28/0). It still needs tank_damage 3, 2.5, and 3 with start_interval 6.
  - Order: after #50 lands, resync, tune, re-pace 130 runs, put before/after per stage in #36's body, and add "D-069a young stage softened to ~half defeats" to the Board and log.

## Rules
- Before every sync, check `git log origin/claude/look-options -1`.
- Squash merges: keep look-options' version of the merged PR's lines, then add only mine.
- Floors are the real counts the suite prints.
- Run gdlint over the whole tree before a push.
- rampage.gd is at 399/400 lines.
- run_flow_tests.gd is at about 359 lines. Each PR's checks live in a tests/lib file:
  - flow_heli_sounds;
  - flow_step_sounds;
  - flow_rifle_sounds.
- Kill Godot only by the PID I recorded. Another session runs its own tools/pacing.gd (no --runs); leave it alone.
- Do NOT edit scenes/kaiju_rig.gd or scenes/kaiju_model.gd.

## How-to
- Godot: /c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
  - Tests: `GODOT=<that> SUITES_ONLY=1 tools/run_tests.sh`
  - Windowed captures need override.cfg written in its own command first, then deleted afterwards.
- Sounds: `python tools/sfx/build_sfx.py --kenney C:/Users/DANTE/AppData/Local/Temp/claude/sfx_dl`. Revert unchanged rebuilt oggs (only the serial differs).
- Mix tools: tools/capture/capture_mix_log.gd and tools/sfx/mix_report.py. The report is in shared notes, mix-report/.

## Running jobs
- bf7dmkgzh: lint and all suites on the #39 merge.
