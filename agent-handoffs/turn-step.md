# turn-step handoff, 2026-10-22 (builder 2)
## State: D-131 built and rebuilt on origin/claude/look-options 56d92a1b (branch claude/turn-weight-v2). Full suite: 20 of 21 suites green; "native" fails only because this worktree has no native dll (KaijuCarve not registered), unrelated. StepTurn bar green, rise point under 10 s, lints green. Clip rendered.
## Task
Lead 10: the turn must step, not swivel (comments #3, #31); D-130 (#51): corrections under ~20 deg smooth, real turns step; D-131 (#54, "Baby turns smoothly"): the baby turns smoothly at the pre-stepped rates, adolescent and adult step real turns; the 10 s rise-point bar stays. PR #144 (claude/turn-weight at ba70e967).
Bar (tests/lib/smoke_step_turn.gd): adult 90 deg 1.0-1.25 s; >=3 alternating footfalls; 0 both-feet-up yaw frames; >=70% of yaw within 0.15 s after a footfall; drift <5 cm; baby 0.60 s +-10% (now smooth); sim step = half the clip stride.
## Built
- sim/body_contact.gd: step clock `phase`, `step_ratio`, slices at footfalls, pivot about the landed foot, `_real_turn` (a turn that starts at smooth_below 0.35 rad or more steps to its end; smaller corrections are smooth), `_rate()` reads `step_turn_*` rates for a stepping body (adolescent, adult) and the plain `turn_*` for the baby (D-131).
- sim/body_volume.gd (new): the disc queries (reach, near, collect) out of BodyContact for the 400-line cap.
- data/tuning.json contact: turn_rate 1.85 / turn_rate_still 3.0 / turn_size_exp 1.0 (baby, smooth: 90 deg in 0.60 s), step_turn_rate 1.62 / step_turn_rate_still 2.7 / step_turn_size_exp 0.55 (the old stepped rates); bodies.reptilian[0].pivot [0,0] (baby has no planted feet).
- scenes: KaijuCodeBody out of KaijuModel, ClipSteps out of ClipGait; ClipGait follows the sim's step clock; capture_walks --no-label.
- tests/lib/city_spawn_view.gd: back to the plain nearest-chunk bot (the committed-target bot only existed to tame the stepped baby's zig-zag).
## Numbers
StepTurn: adult 1.03 s, 3 footfalls, 0 aloft, 88% sliced, 0.0 cm, step 3.150 vs 3.145, baby 0.60 s: ALL PASS.
Rise point (stage1/2, seeds 98765 7301 1234) with the real city_spawn_view bot: stage 1 7.6 7.8 7.7 s; stage 2 7.8 5.6 5.6 s (all under 10 s).
## Branches
claude/turn-step-pre-rebase = f4dff814 (old history). claude/turn-weight-v2 = fb8098b3 on 56d92a1b, tree-equal to it except the docs row of comments #55-59. Not a fast-forward of claude/turn-weight (squashed base), so pushed as -v2.
## Clip
C:/Users/DANTE/AppData/Local/Temp/ts-builder/clip/turn90_adult.avi (adult, game camera, straight walk + 90 deg left turn, 6 s, 1280x720, local RTX 4070 SUPER, no label, drift 0.0 cm). No ffmpeg on the box, so avi (Godot MJPEG).
## Known
No native dll in this worktree (GDScript fallback runs). Adolescent and adult show a few both-feet-up frames in turns on some offsets; not in the bar. Not looked at the clip frames myself (lead QC).
