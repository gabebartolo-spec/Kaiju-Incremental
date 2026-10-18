# Ability VFX/SFX handoff, 2026-10-18 22:00
## State: running a check (CI mix-log capture for the shell_hit PR, bash bue4oa2qy)

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
- #39 heli gun and crash (look-options d135937).
- #42 footstep variants (look-options 71dc65b). The lead's --delete-branch removed this worktree; it was restored on claude/rifle-sfx and nothing was lost. The lead no longer uses --delete-branch.

## Merge chain (D-070, director shipped all sounds). The lead merges one at a time; I resync each right after the previous lands
- **#46** claude/rifle-sfx: resyncing onto 71dc65b. Conflicts kept both sides:
  - provenance rows, sfx.gd stream list, crowd funcs plus last_volume;
  - FlowHeli/FlowRifle preloads, build_crowd plus build_rifle;
  - capture --army: helis plus rooftop range 60.
  All 9 suites green, flow 133; pushed, SHA sent to the lead.
- **Gap job (a): branch claude/shell-hit-hp (off look-options 71dc65b, 4f6f623 pushed, no PR yet).**
  - build_sfx.py: shell_hit high-passed at 120 Hz (energy below 120 Hz 82% -> 33%; below 300 Hz 97% -> 84%).
  - The provenance row is updated. capture_mix_log.gd now takes --out=<dir>.
  - Old file for the A/B: scratchpad/shellhp/shell_hit_before.ogg.
  - CI capture (60 fps, 2 min) downloads to scratchpad/shellhp/ci.
  - Next: run mix_report.py on that log twice (swap the old ogg into assets/sfx for "before", then restore).
    Compare stomps masked by army, build an A/B clip (stem sums muxed on the video), open the PR
    (tabled for the director's listen), and send the lead the numbers.
  - The lead said this PR comes after #46; open it after #46 lands, or say it can merge in either order.

## #36 claude/army-scales (D-069), pushed 4b3146c; waits for BOTH #50 and the croc P3 PR (P3 also tunes young: D-074 revised)
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
  - Tune young LAST, against #50's and P3's final numbers (P3: baby speed 0.6, more hp, demo ~35 min). Target stays ~half early defeats, with Scales where #36 puts it.
  - Order: after #50 and P3 land, resync, tune, re-pace 130 runs, put before/after per stage in #36's body, and add "D-069a young stage softened to ~half defeats" to the Board and log.

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
- bue4oa2qy: CI capture of capture_mix_log.gd on claude/shell-hit-hp.
- Local-only handoff commits on army-scales-sync: 7b0db6d, 3518703.
