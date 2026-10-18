# Military AI handoff, 2026-10-18 (night, late)
## State: awaiting lead (round-2 clip + 2x checks + damage table sent; fresh critic next; PR #50 head 4146dbf+handoff, Auto-fix on)

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". Brief from LEAD
(session "Kaiju: LEAD", local_106fc100...). Critic round 2 FAILED (6 points); D-082: this is the
LAST fix round. If LEAD's fresh critic fails, the demo ships with today's army and #50 goes in
the next build. Director AFK: no render cap; local windowed renders need override.cfg (create it
in its own command first: focus-guard checks before the command runs), removed after.

## Branch and commit
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options, code head 4146dbf (look-options 6b27da9 merged at bce6433). LEAD merges.

## Round 2 work
- 633424c tanks own pose (ConvoyRoute.front, oriented SAT hulls, standing pivots); helicopters
  own yaw/alt (fire_cone 30, hover_yaw, line-up), bank in powers_view.
- 853e5c1 retune: young range 11 / tank_damage 10, Apex tank_damage 8.25.
- 7fd2687 driving skew: RoadGraph._square_legs (skew_deg 8, square corner), _sweep_fits,
  no shuffle/back-off half turned, settle while yielding, re-plan after yielding.
- c034646 altitude scans a fan of next paths (not a 25 m disc).
- 4146dbf altitude check (military 17); clip kaiju at CLIP_AT (5,-70), north-end crossing.
- LEAD chose B (keep full roof clearance): residual, the pair climbs out of the game camera near
  anything over ~12 m (wheel at the start, spire). Flying round towers = post-demo (my lateral
  push attempt broke pair spacing/kaiju clearance: reverted).

## Evidence (PR body has it all)
- Suites at 4146dbf (snapshot): all 10 pass, military 17, city 23, load 13, flow 138.
- Clip: notes military-ai/clip_r3/clip_720.mp4 (+ clip.mp4 1080p; Godot ignores --resolution),
  2x sheets/strips in clip_r3/review/. Self-check passed: hulls on roads, parked tanks within 8
  deg (turrets turn to the kaiju: reads as skew at a glance), runs nose-on, 8.25 s turn-back is
  a travelling teardrop with bank, pair 13.0 m.
- Damage vs af7eb05: young -8.7% per run (rate +3.9%; per-run capped by defeats), Behemoth
  +4.6%, Colossus -0.1%, Apex +1.2%.
- Failing first: driving skew 739 -> 0; old 0d1fd53: 24/24 bursts off the nose, rotor -11 m,
  13/966 hover turns; climb-only mutant fails the altitude check; parked skew not shown on old.
- Timing (noisy): Apex mean ~1.0-1.4 ms, p95 3.2-5.0 ms (round 1: 0.4 / 1.1).

## Next
1. Pacing running: task b1w4jw0o1 -> scratchpad pacing_c2.txt (snapC = c034646 tuning, same as
   4146dbf). Fill "Pacing" line in scratchpad pr_body.md, gh pr edit 50 --body-file.
2. Act on LEAD's fresh critic result (last round).
3. Follow-up to propose: traffic/police cars (presentation) should yield to or be crushed by
   tanks; a parked tank sits over a police car at 15-20 s in the clip.

## Findings for the lead
- Check the drawn model vs the sim hull first (tank voxels 20 x 40 at 0.124 m = 2.48 x 4.95 m).
- A roof-clearance altitude must be checked against the game camera (~40 m up at Behemoth).
- At 2x a turret turned to the target reads as a skewed hull: ask the sim for the hull pose.
- Kill orphaned Godot children by PID after TaskStop (parent timeout.exe; match start time).

## Rules learnt the hard way
- gdformat on Windows writes CRLF: sed -i 's/\r$//' after it. Python: open(..., newline='').
- Never edit sim files while a background run reads the worktree: git archive snapshots.
- grep filters on probe output: match the probe's own prefix, or the result is silently lost.
