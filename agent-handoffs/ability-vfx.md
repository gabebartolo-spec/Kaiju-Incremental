# Ability VFX/SFX handoff, 2026-10-19 02:45
## State: running a check (CI stills for stomp-dust, bash bbjoendh4: after then before); #56 waits for #50; #36 last

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
- #42 footstep variants (look-options 71dc65b).
- #46 rifle volleys (look-options e14854c). All five tabled sound PRs are in. The lead's --delete-branch removed this worktree; it was restored on claude/rifle-sfx and nothing was lost. The lead no longer uses --delete-branch.

## Merge chain (D-070, director shipped all sounds). The lead merges one at a time; I resync each right after the previous lands
- **#52 CLOSED unmerged:** the director kept A, the full boom (D-079). shell_hit stays as it is.
  - capture_mix_log --out landed as #60.
  - Clip and notes stay in shared notes shellhit-ab/.
- **Rifle gap = PR #53 (claude/rifle-gap): per-sound "min_interval" in tuning sfx, {"rifle": 0.3}; flow 134; check shown failing at gap 0.**
  - Measured with rooftop-density 7000a1f merged, seeded Behemoth, gap 0 vs 0.3:
    - rifle sounds 187 vs 60 (4.8/s vs 1.5/s while firing);
    - stomps cut by the pool 50 vs 24;
    - rifle never masks stomps.
    The numbers are in #53's body. The lead merges on green before the rooftop clip.
    Whichever of #50/#53 lands second resyncs the flow floor only.
  - The rooftop session ("Kaiju: denser rooftop fire (D-076)") merged #53 into its claude/rooftops-capture branch.
  - Temp branch tmp-rifle-measure (rifle-gap + 7000a1f) is still local; deleting it was denied, so it's left for the user or lead.
  - FINDING (approved by the lead as job, see the voice-pool section below): even with the gap, 24 of 73 stomps (and 23 of 33 tank shots) are cut short because the 8-voice pool is shared.
    Fix idea: give stomps and breath their own voices, or raise POOL. Measure with scratchpad/riflegap/measure.py.

- **Voice pool (lead approved; separate PR, in the demo if green before #36): branch claude/sfx-voices, on look-options b810d1a (#53 in), flow 135, all suites green; PR #56.**
  - Sfx: const POOL removed; voices come from tuning "sfx" "voices" (24).
  - New `sounding(sound)` helper. New check tests/lib/flow_voice_sounds.gd check_tail (a stomp survives 12 more plays), called from flow_sfx.gd (+1 flow).
  - Simulated on the logged gap-0.3 run (scratchpad/riflegap/pool_sim.py), cut short:
    - 8 voices: stomps 24, tanks 23 (73 total);
    - 16 voices: 9 total;
    - 24 voices: 0;
    - 3 stomp + 1 breath reserved + 8: tanks 13 still cut. So choose a bigger pool.
  - Fail-first done: at voices 8 the check FAILS; tuning.json is back to 24.
  - capture_mix_log.gd uses the pool size now (it read Sfx.POOL).
  - APPROVED by the lead. It merges straight after #50 lands; then resync the flow floor only (the lead pings).
  - Limiter: at 24 voices the pre-dynamics peak is -3.3 dBFS and 0% of the run is over -1 dBFS (scratchpad/riflegap/peaks.py). This is in the body. Demo chain (D-078): #50 -> P3 #54 -> rooftops -> landmark sites -> stadium matches -> #36 -> build.

- **Footfall dust (lead, greenery finding): branch claude/stomp-dust off look-options e3b0c5a, pushed 91d6d3c, no PR yet.**
  - Problem: rampage._on_footfall called Fx.dust, the collapse cloud (2.6 s, 0.47 alpha, 2.2 m puffs), every step, so a walk piled into a grey haze.
  - Fix:
    - new Fx.footfall(at, size) with tuning fx "footfall_dust" {seconds 1.0, alpha 0.28, rise 1.6, max_live 3}, skipped while 3 are up;
    - rampage.gd:298 now calls it (line count unchanged, 399).
  - Check: tests/lib/city_footfall_dust.gd from run_city_tests (+1 city, 12 -> 13). It's a haze budget, puffs x alpha <= 0.9.
    Shown failing at max_live 100 (haze 2.80).
  - Stills: tools/capture/capture_walk_dust.gd --out --before --at=6,9,12 (--before replays the old Fx.dust per step on the same seed).
  - Suites green (city 13, flow 134). The flow suite caught a freed puff in a typed filter lambda; fixed with a plain loop.
  - Running: CI capture twice with an explicit renderer: `ci_capture.sh --renderer=forward_plus capture_walk_dust.gd -- --at=6,9,12`, once with --before.
    Then the board, the PR, and the stills to the lead.

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
  - Order (director): #50 -> P3 -> rooftop density -> #36 -> demo build. Targets: about half of early runs defeated, evolve1 near 0.71 h (D-074b). After those land, resync, tune, re-pace 130 runs, put before/after per stage in #36's body, and add "D-069a young stage softened to ~half defeats" to the Board and log.

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
- bbjoendh4: CI stills to scratchpad/walkdust/{after,before}.
- Local-only: army-scales-sync handoff commits 7b0db6d, 3518703; branch tmp-rifle-measure (delete was denied; leave it).
