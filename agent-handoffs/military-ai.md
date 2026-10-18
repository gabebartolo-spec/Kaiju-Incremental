# Military AI handoff, 2026-10-18 (night, after r3 critic)
## State: available (r3 FAILED fresh critic; demo ships WITHOUT #50 (D-082), merges after the build (D-083); r4 fix list below; PR #50 head 55cacbc, Auto-fix on)

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". LEAD = session
"Kaiju: LEAD" (local_106fc100...). Merges into claude/look-options after the demo build;
playtest fixes come first (D-083). Compute is free (director AFK): no render cap; local
windowed renders need override.cfg (create it in its own command first; focus-guard checks
before the command runs), removed after. Captures: local GPU, gl_compatibility.

## Branch
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options. LEAD merges. Resync before the next clip.

## r4 fix list (LEAD, fresh critic on clip_r3 at 4146dbf, confirmed on 1080p frames)
1. Tank A 9-12 s, narrow N-S street: hull yaw 30-40 deg while driving, a corner over the lot.
   Finish the turn at the intersection; hold yaw within 10 deg of the road axis while moving.
   (Test today: DRIVE_DEG 20 + skew_deg 8 + pivot_deg 15 residual. Tighten to 10 and find
   what still drives skewed: likely the move during a <= pivot_deg turn, convoy._drive
   `move` is along `dir` while `front` lags; consider move only when |turn| <= rate.)
2. Tank pair 13-16 s: one perpendicular mid-street, hulls interpenetrating (my SAT check says
   no overlap at 5 x 2.5 m: compare with the DRAWN hull + barrel + turret overhang, add a
   margin). Tank-to-tank separation = footprint + margin; stagger deploy slots along the road;
   never rotate in place inside another's footprint (sweep check vs other hulls with margin).
3. Helis out of frame 11.3-15.0 s and under the HUD 3.0-4.5 s: clamp orbit and attack arcs to
   the camera view with a margin (today only clear_arc on the camera side).
4. Pair 5.9-6.4 s: one passes under the other. Enforce 13 m lateral offset + altitude stagger
   (pair check measures 2D centre spacing only: make it 3D/lateral).
5. Rotors over a tower facade 10.4-10.8 s and 17.5-18.7 s: keep 15 m horizontal clearance from
   footprints (not just rotor over roof); no turn-back at a tower top.
6. Assert heli yaw error at fire time < 20 deg, logged in the probe (9.5 s unclear).
7. (LEAD: worth doing) tank vs car: tanks crush or push traffic/police cars (presentation:
   scenes/traffic.gd, scenes/police.gd). I proposed it as a separate session (task_bd54430b);
   fold it in here if r4 takes it, then dismiss that proposal.

## What is in #50 (round 2/3)
- Tanks own pose (ConvoyRoute.front, oriented SAT vs lots, standing pivots, _sweep_fits,
  _square_legs skew_deg 8 with square corners, settle when held/yielding, re-plan after yield).
- Helicopters own yaw/alt (fire_cone 30, hover_yaw, line-up; altitude over roofs on a fan of
  next paths, LEAD B: full roof clearance); bank in powers_view. Clip spot CLIP_AT (5,-70).
- Retune vs af7eb05: young range 11 / tank_damage 10, Apex tank_damage 8.25. Damage per run:
  young -8.7% (rate +3.9%, defeats cap per-run), Behemoth +4.6, Colossus -0.1, Apex +1.2%.
- Checks: military 17 (driving skew 739 -> 0; old 0d1fd53: 24/24 bursts off nose, rotor -11 m,
  13/966 hover turns; climb-only mutant fails altitude check). Suites all green at 4146dbf.
- Timing (noisy): Apex Army.step mean 1.0-1.4 ms, p95 3.2-5.0 ms (round 1: 0.4 / 1.1).

## Open
- Pacing at 4146dbf tuning running: task b1w4jw0o1 -> session scratchpad pacing_c2.txt (may be
  lost with this session; rerun tools/pacing.gd -- --species=reptilian on a git archive
  snapshot if so). Bar 0.59 h / 4.46 h +-5%. PR body "Pacing" line still says running.
- Notes folder military-ai/: clip_r3 (+review), sim-review-packet.md (section 6 current to r3).

## Findings for the lead
- My 2x self-check passed what the critic failed (interpenetration, skew, heli framing):
  judging single crops is not enough; check every tank pair's DRAWN extents numerically per
  frame (probe), and the heli's screen position vs the frame/HUD.
- At 2x a turret turned to the target reads as a skewed hull: ask the sim for the hull pose.
- Kill orphaned Godot children by PID after TaskStop (parent timeout.exe; match start time).

## Rules learnt the hard way
- gdformat on Windows writes CRLF: sed -i 's/\r$//' after it. Python: open(..., newline='').
- Never edit sim files while a background run reads the worktree: git archive snapshots.
- grep filters on probe output: match the probe's own prefix, or results are silently lost.
