# turn-step handoff, 2026-10-22 (builder 2)
## State: D-130 built (small corrections smooth, real turns step); StepTurn bar green; rise-point stage 1/2 still over 10 s; asked lead how to proceed. Ratchet cleanup in progress. No clip yet. No Godot running.
## Task
Lead 10: the turn must step, not swivel (comments #3, #31), and D-130 (2026-10-22, "Small turns smooth"): corrections under ~20 deg turn smoothly while walking (no slice, no pivot); real turns still step; turn rates unchanged (+5% of comment #49 was never committed); the 10 s rise-point bar stays. PR #144 (claude/turn-weight). Push: `git push origin HEAD:claude/turn-weight` from worktree Kaiju-Incremental-wt/turn-step (branch claude/turn-step).
Bar (tests/lib/smoke_step_turn.gd): adult 90 deg 1.0-1.25 s; >=3 alternating footfalls; 0 both-feet-up yaw frames; >=70% of yaw within 0.15 s after a footfall; drift <5 cm; baby 0.60 s +-10%; sim step = half the clip stride.
## Built (builder 1, commits 909f116a..ba70e967)
- sim/body_contact.gd: step clock `phase`, `step_ratio`, slices at footfalls, pivot about the landed foot (`_feet`, per-stage `pivot`), `turns_in_steps()` false while the beam is on.
- data/tuning.json contact: step_len, support_both, slice_*, turn_cadence, cadence_ease, turn_min, step_ratio_min, turn_rate 1.62, turn_rate_still 2.7, turn_size_exp 0.55, bodies.reptilian[].pivot.
- scenes: ClipGait follows the sim's step clock; capture_walks --no-label; city_spawn_view bot keeps one target chunk until it is down.
## Built (builder 2)
- ceeed697: the dead builder's uncommitted edit, finished: a split for the 400-line cap (KaijuCodeBody out of KaijuModel, ClipSteps out of ClipGait; KaijuModel.follow_steps(phase, ratio) before animate()). Merged origin/claude/look-options (47de51c8, clean).
- e400ade5 D-130: body_contact `_real_turn` (a turn that starts at contact.smooth_below = 0.35 rad or more steps to its end, i.e. until |turn_left| <= turn_min); otherwise the turn is smooth: turn_accel, no slice gate, no cadence, no pivot.
## Numbers (probe C:/Users/DANTE/AppData/Local/Temp/ts-builder/rise.gd --tier= --seed= [--smooth_below=] [--repick] [--ahead=] [--verbose])
StepTurn: adult 1.03 s, 3 footfalls, 0 aloft, 88% sliced, 0.0 cm, step 3.150 vs 3.145, baby 0.63 s: ALL PASS.
Rise point (s), stage1 98765/7301/1234 | stage2 same seeds:
- D-130 (hysteresis, 0.35): 11.7 12.0 12.0 | 12.0 10.0 8.0
- D-130 without hysteresis: 12.0 10.0 8.0 | 12.0 5.5 8.0
- all stepped (old): 12.0 13.6 10.0 | 10.0 6.0 5.4
- all smooth at today's rates: 12.0 7.9 8.8 | 8.0 5.7 6.0
- threshold 25/30/40 deg: chaotic, 8-16 s
- old re-pick-every-step bot + all smooth: 10.0 7.9 8.0 | 10.0 5.7 6.0; + D-130: stage 1 never finishes (zig-zag)
Diagnosis: stage 1 seed 98765 the committed-target bot clears the west group first, then walks ~14 units back east (4 s of straight walking), so even a fully smooth turn misses; the bot's greedy order, not the small corrections, decides the time. Needs the lead's call.
## Next
1. Lead's answer on the rise point. Meanwhile: complexity ratchet (steer, ClipGait._choose, RampageSim.step, BipedHead.update grew on this branch; move the 2 KaijuModel baseline rows to kaiju_code_body.gd).
2. Suites city, smoke, powers, military, clips, sim (sim_play); gdlint/gdformat/ratchet/tuning_keys.
3. Clip on the LOCAL GPU per notes RULES-NOW.md: `capture_walks.gd -- --stage=adult --course=turn90 --cam=game --seconds=6 --no-label` (+ a baby walk-in if the tool allows); output notes walk-m2/clips.
## Known
No native dll in this worktree (GDExtension error at start; GDScript fallback runs). Adolescent and baby show a few both-feet-up frames in turns on some offsets; not in the bar.
