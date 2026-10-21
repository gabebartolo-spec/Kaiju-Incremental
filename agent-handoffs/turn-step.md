# turn-step handoff, 2026-10-22
## State: option B built; smoke (StepTurn) green; WIP pushed to PR #144 with 1 known red area (city rise-point, stage 1). No clip yet. No Godot running.
## Task
Lead 10: the turn must step, not swivel (comments #3, #31). PR #144 (claude/turn-weight). Push: `git push origin HEAD:claude/turn-weight` from worktree Kaiju-Incremental-wt/turn-step (branch claude/turn-step).
Bar (tests/lib/smoke_step_turn.gd): adult 90 deg 1.0-1.25 s; >=3 alternating footfalls; 0 both-feet-up yaw frames; >=70% of yaw within 0.15 s after a footfall; drift <5 cm; baby 0.60 s +-10%; sim step = half the clip stride. ALL PASS (smoke suite 39 checks, 0 failures).
## Built
- sim/body_contact.gd: step clock `phase` (walked(distance, dt) from RampageSim and Dash; integer = footfall, even = left), `step_ratio`; steer() yaws only in a slice at each footfall and rotates kaiju_pos about the world-fixed foot that just landed (`_feet`); per-stage `pivot` = [how far ahead a foot lands, half foot gap]; `turns_in_steps()` false while the beam is on (beam follows the stick at SpeciesPowers.beam_turn_rate(), new helper).
- data/tuning.json contact: step_len, support_both, slice_from/open/accel, turn_cadence, cadence_ease, turn_min, step_ratio_min, turn_rate 1.62, turn_rate_still 2.7, turn_size_exp 0.55, bodies.reptilian[].pivot.
- scenes: KaijuGait.step_phase/step_ratio, KaijuModel.animate(.., step_phase, step_ratio), Rampage + capture_walks pass them; ClipGait follows the sim's step clock (_step_frame, _first_landing) and scales foot fore-aft travel by step_ratio (_stepped).
- tools/capture/capture_walks.gd --no-label. tests/lib/city_spawn_view.gd: the bot now keeps walking at one chunk until it is down (a player does; the old re-pick every step zig-zagged between equal chunks with a stepping body).
## Full local suite (before the last 3 edits): all pass except native (no dll, expected), powers beam graze (FIXED since: beam bypasses steps and body rate limit; powers suite passes), city rise-point.
## LEFT: city rise-point (tests/lib/city_spawn_view.gd, must be down within 10 s)
Stage 1 (baby), walking in with the committed-target bot: stepped turn 12.0 / 13.6 / 10.0 s (seeds 98765 / 7301 / 1234); smooth turn with the new rates (--nopivot) 10.9 / 7.9 / 8.0 s. Stage 2 passes (10.0, 6.0, 5.4 stepped; stage 2 seed 98765 = 10.0 borderline). Cause: the baby's stepped turns swing the body sideways (pivot about the foot ahead) and delay small corrections up to one step. Ideas (lead's call if a design trade): small corrections (|turn_left| < ~20 deg) turn smoothly without slices/pivot; or a faster baby turn; probe: scratchpad/ts/rise.gd --tier= --seed= [--nopivot] [--key=value cfg overrides]. Never loosen the 10 s bar.
## Next
1. Fix the rise-point (above), rerun city + smoke + powers + military + clips + sim_play suites, re-run the full suite once.
2. Clip on the LOCAL GPU per notes RULES-NOW.md: untracked override.cfg (no_focus, off-screen), --windowed --write-movie --fixed-fps 60, APPDATA scratch, log must say RTX 4070 SUPER, delete override.cfg after: `capture_walks.gd -- --stage=adult --course=turn90 --cam=game --seconds=6 --no-label`; output notes walk-m2/clips.
3. Report to the lead and ask for the next task.
## Known
Adolescent and baby still show a few both-feet-up frames in turns on some offsets (leg reach / old-foot gap); not in the bar.
