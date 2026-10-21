# turn-step handoff, 2026-10-21
## State: running a check (one CI clip)
## Task
Lead 10: fix the turn (comments #16, 2026-10-21 #3 "swivelling on the spot like a plastic toy") on
PR #144 (claude/turn-weight). Lead's ruling (director 2026-10-21 "bigger = slower but not TOO
slow, lumbering within reason, its not fun to play if hes too sluggish"): sim turn rate scaled by
body size; adult 90 deg in about 1.0-1.2 s; >=2 footfalls; yaw only with a foot down; baby keeps
its <=1.5 s about-face; planted-foot drift <5 cm. Then ONE adult turn90 CI clip at --cam=game.
Also: ci_capture.sh reads its own run id from `gh workflow run`'s output.
## Branch and commit
Worktree Kaiju-Incremental-wt/turn-step, local branch claude/turn-step tracking
origin/claude/turn-weight (base 9fc46308). Push with `git push origin HEAD:claude/turn-weight`.
## Changes (uncommitted, worktree turn-step)
- sim/body_contact.gd _rate(): turn_rate and turn_rate_still / body_scale^turn_size_exp.
- data/tuning.json contact: turn_rate 3.5 -> 1.85, turn_rate_still 6.0 -> 3.0, turn_size_exp 1.0
  (the baby, scale 0.5, keeps its old 3.7/6.0 rad/s; exp 0.5 failed city rise-point 10.9 s and
  the powers beam graze; turn_slow 0.35 made city worse, 11.4 s).
- tests/lib/smoke_step_turn.gd (smoke, StepTurn): adult turn90 at 60 Hz, 3 checks (time
  1.0-1.25 s, >=2 footfalls, drift <5 cm).
- tools/capture/capture_walks.gd (from walk-m2 517fa36c, no --bare, local FOCUS_FOLLOW).
- tools/capture/ci_capture.sh reads its run id from `gh workflow run` output.
## Evidence so far
Fail first (9fc46308): adult 90 deg 0.60 s, 21 yaw frames both feet up. Now: adult 1.10 s,
4 footfalls, drift 0.0 cm; adolescent 0.80 s; baby 0.60 s. Still 36 yaw frames with both feet up
(FOLLOW-UP, lead chose A: not pinned in the test, measured by scratchpad probe_turn.gd).
Full local suite: all pass but native (no local dll); military re-pinned RAMPAGE_SEEDS
[2,4,8] -> [3,6,9] (5 -> 154 tank-steps in range; seeds 0-11 also showed a hull-touch fail on
some other seed: latent); claws check now uses per-run cities (its 5 pairs were one city).
Cause (per-frame log): the node turns about kaiju_pos, ~8.6 body units behind the planted feet
(adult; baby 4.7, adolescent 5.2), so 10 deg swings the stance foot 1/3 stride -> catch re-steps
that overlap the other foot's swing.
## Attempts (fix-loop record, all reverted)
hold yaw aloft (body lag 0.8 rad, HeadLead slide fails); defer re-step (foot dragged 20 m);
hurry other foot down (drag 10 m); turning cadence 1.4/2.0 (more aloft); sim pivot about the feet
(12 aloft); pivot + forward-speed cycles (16 aloft).
## Open decisions
Lead chose A. B (gait rework: sim pivot about the feet + turn-aware foot placement) goes to the
director only if the clip still reads as a swivel.
## Running jobs
one CI clip: ci_capture.sh --movie --fps=60 capture_walks.gd -- --stage=adult --course=turn90
--cam=game --seconds=6
## Findings for the lead
Both-feet-up frames in a turn come only from overreach re-steps (straight walking has 0); the
node turns ~8.6 body units behind the adult's feet.
