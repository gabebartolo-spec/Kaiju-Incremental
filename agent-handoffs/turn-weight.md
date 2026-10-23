# turn-weight handoff, 2026-10-23 (lead's builder, D-187 "Heavier, slower")
## State
Branch claude/turn-weight-d187 (claude/turn-weight on origin is old unmerged WIP ba70e967, left for the hygiene list),
from origin/claude/look-options, merged with #175 (a674fb20). Sim + data + tests built and pushed. Local: gait 24/0,
motion 30/0 (#175's gate), smoke 47/0, city 175/0, tuning_keys, complexity ratchet, check_scripts, gdlint, gdformat ok.
No PR (the lead opens it). The A/B clip is done (below); director pause 2026-10-23 until 'resume': no Godot runs.
## Task
ROADMAP "Director comments (2026-10-23, afternoon)" the swivel; D-187: the Behemoth and Colossus turn heavier and
slower, a U-turn while walking 2 s / 3 s (to within 5 deg of the new way), the yaw spread evenly over the steps;
the young croc keeps its smooth turn (D-131), corrections under ~20 deg stay smooth (D-130).
## What changed
- sim/body_contact.gd: a stepped real turn yaws at a trapezoid rate fixed by the stage's uturn_s and contact.turn_ramp
  (_turn_time, _turn_peak), independent of footfall, stride and the old slice bell / turn ease (both removed); the
  step clock's cadence in a turn is turn_steps / uturn_s; the stride at an about-face is the stage's own turn_slow;
  a real turn that comes within turn_min of its end keeps its stepped slowing to the last (_landing: the quick
  correction pace used to add a 26 deg/s lurch to the last 3 deg). _swing (pivot on the newest planted foot, D-177)
  is unchanged. The young croc (stepping() false) takes the unchanged smooth branch.
- data/tuning.json contact: NEW turn_ramp 0.15, turn_land_deg 5, per-stage (bodies.reptilian[1,2]) uturn_s 2.0 / 3.0,
  turn_steps 5.5, turn_slow 0.1 (young keeps the global 0.5), each with a _note_*; REMOVED slice_from, slice_open,
  slice_accel, turn_ease_min, turn_ease_peak, turn_cadence. step_turn_* stay for the smooth corrections.
- tests/lib/gait_turn.gd (new) + tests/run_gait_tests.gd (_check_u_turn, _check_young_turn): bars 1,2,3,4,5,7.
- tests/lib/smoke_step_turn.gd re-pinned (D-187, old -> new): adult 90 deg turn 1.0-1.25 s, slowest <= 1.4 ->
  1.55-1.9 s, slowest <= 1.95 (measured 1.73, the same from every place in a step); "80% of the yaw within 0.24 s of a
  footfall" (the old squeeze) -> "no step turns the body more than 40 deg" (measured below). Jump, drift, foot yaw,
  skate, footfall, both-feet-up bars unchanged and green.
## Numbers (U-turn, stick reversed, from four places in a step; walk 5.5 u/s). base -> now
Behemoth 1.58-1.62 s -> 1.98; Colossus 1.75-2.05 -> 2.98; peak yaw / mean 2.98x / 3.18x -> 1.18x; body middle
3.70x / 4.44x -> 1.7-1.8x of walk; origin (tail root) 6.3x / 11.5x -> 2.5x / 3.2x; 3 footfalls a foot; <= 36 deg a
step. Real steps (foot > 0.3 FL = 0.62 / 1.11 u): Colossus 3 in a row -> 5 (Behemoth already passed on base).
Young croc: 4 legs identical to the base to 0.001. Footfalls a second in the turn 2.75 / 1.83 (walk 2.14 / 1.75).
## Why bar 3 is 1.9x (body middle) and 3.5x (origin), not 1.5x (lead accepted)
The turn pivots on the planted foot (motion gate PIVOT_MAX, CENTRE_MAX). kaiju_pos is the tail root, 7.0 / 14.1 units
behind the feet, so it sweeps pi x that per U-turn (11 / 15 u/s at 2 / 3 s, 2x / 2.7x the walk); the body middle
moves yaw x the foot's side offset (2.8 / 4.0 u) plus the stride. No speed removes it; only moving the model origin to
the hips would (view/art). The guards sit just over today's numbers; the base fails both (3.7-4.4x, 6.3-11.5x).
## Rise point (D-131 10 s bar) -- READ THIS
The city suite passes (175/0) but its bot walks the YOUNG body in both stages (the default tree has no evolve levels).
With the real Behemoth (probe, same bot, three map seeds 7301 / 1234 / 98765): base 2.0 / 8.0 / 8.0 s; now with
turn_slow 0.1 (A) 4.0 / 8.0 / 12.0 s (seed 98765 over 10); with turn_slow 0.5 (B) 3.5 / 9.7 / 10.0 s. Colossus under
1 s. Young unchanged (4.0 / 6.0 / 4.0). A director question; the bar is untouched.
## A/B clip (the director asked to see turn_slow both ways)
C:/Users/DANTE/AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental--claude-worktrees-status-check-b96b26/b2b0bc5b-915b-4abe-b67a-dbc9a0712bcb/scratchpad/tw/turn_ab.mp4
3840x2160, 8 s, 60 fps, 68 MB: 2x2, A (0.1, "step round on the spot") left, B (0.5, "keep the walking arc") right, Behemoth
top, Colossus below; walk east, stick reversed at 2.0 s; real rampage, game camera, local RTX 4070 SUPER (log says NVIDIA).
Made with tools/capture/capture_turn_ab.gd (new; --turn-slow sets the stride at an about-face), four renders, composed
with scratchpad tw/compose.py. Checked at 1x (whole frame) and native-pixel crops: labels clear of the HUD, the turn reads.
A and B are close: stride at the turn's lowest 0.25 / 0.20 (A) against 0.59 / 0.56 (B), A under 0.3 of full for 0.38 /
0.75 s; sideways reach of the feet-centre 4.1 / 5.0 u (A) against 5.3 / 7.5 u (B); run-on past the reversal 11.0 / 22.2
against 11.8 / 23.6 u. B's wider swing brings the Colossus's tail into buildings sooner (dust at the clip's left in B).
## Decisions
turn_slow 0.1 vs 0.5: the director asked to see both (clip A vs B). turn_steps 5.5 and turn_ramp 0.15 are tuning picks
(bar 7's 40 deg a step and 0.3 FL real steps; peak <= 1.3x mean).
## Not exercised
The motion critic and a clip (the lead arranges); the drawn feet (bar 7 uses BodyContact._feet as asked); the smoke
suite's Behemoth turn (StepTurn drives the adult only); other species (bodies has the reptilian only).
