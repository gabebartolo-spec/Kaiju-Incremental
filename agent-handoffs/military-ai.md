# Military AI handoff, 2026-10-18 (night)
## State: awaiting lead (helicopter altitude A/B/C asked; PR #50 head c034646, Auto-fix on)

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". Brief from LEAD
(session "Kaiju: LEAD", local_106fc100...). Critic round 2 FAILED (6 points); D-082: this is the
LAST fix round. If the next fresh critic fails, the demo ships with today's army and #50 goes
in the next build. Clip: 720p gl_compatibility, local GPU (peer chain: croc #54 hands the slot
to us), self-check at 2x on all six points before sending. Then send LEAD clip + 2x checks +
damage table in ONE message; remove override.cfg after the local render.

## Branch and commit
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options, head c034646 (look-options 6b27da9 merged at bce6433). LEAD merges.

## Round 2 work (on top of round 1, see the PR body)
- 633424c: tanks own their pose (ConvoyRoute.front), oriented hull checks (SAT vs lots),
  standing pivots > pivot_deg 15 at hull_turn 90 deg/s, crown pivots, settle when held.
  Helicopters own yaw/alt (nose follows flight, line-up before runs, fire_cone 30, hover_yaw),
  bank in powers_view (presentation only).
- 853e5c1: retune vs af7eb05 baseline: young range 11 / tank_damage 10, Apex tank_damage 8.25.
- 7fd2687: driving skew (found at 2x in the 633424c CI preview: tank crabbing ~30 deg down a
  narrow street). RoadGraph._square_legs (skew_deg 8, square corner fallback), _sweep_fits
  (pivot starts only if the whole sweep fits), no shuffle/back-off on a half-turned hull,
  settle while yielding, re-plan after yielding. New check (military 16): driving hull within
  20 deg of its road: old 739 of 26232 tank-steps, now 0.
- c034646: helicopter altitude scans a fan of next paths (straight, both arcs, run in, break
  out) instead of a 25 m disc.

## Open problem (asked LEAD, options A/B/C)
Camera is ~40 m up at Behemoth; a pair clearing the 27 m Ferris wheel (by the clip's start)
flies at 31 m and is out of frame for the whole clip. Flying round towers (lateral push) broke
pair spacing, kaiju clearance and faced break-off: reverted (third failed fix: stopped).
A = cap at 16 m (visible, rotors clip anything > 12 m); B = keep clearance (invisible near tall
landmarks); C = proper avoidance, next build. For A: _alt_over returns min(ceiling, ...) and
the roof-clear check must exempt roofs above ceiling - roof_clear (disclose in the PR body).

## Damage per run (27 replayed pacing states, baseline af7eb05 = 178/202/478/669)
At 633424c before retune: -20.5 / 0 / -3.8 / +33% (Apex pair now does 172). Young per-run
damage saturates ~164 (defeats end runs): matched the damage RATE instead (3.35 vs 3.33/s);
Apex 8.25 -> -1.1%. Re-measure at c034646 running (scratchpad balance_c.txt, pacing_c.txt,
suites_c.txt, task b04wwzjeo).

## Next
1. Apply LEAD's A/B/C. 2. Read b04wwzjeo results; retune if outside +-5%.
3. Local GPU render when the slot reaches us (720p gl_compatibility, ~22 s), self-check 2x
   (hull over lot, parked skew, driving skew, fire cone, hover-yaw at tower, bank, pair gap).
4. PR body (draft scratchpad pr_body.md has a round-2 section with TABLE_R2/CLIP_R2 holes),
   packet section 6, then one message to LEAD.

## Findings for the lead
- Check the drawn model against the sim hull before blaming geometry: tank hull voxels
  20 x 40 at 0.124 m = 2.48 x 4.95 m, matches the 5 x 2.5 sim hull.
- A rotor-height clearance must be checked against the camera: anything above ~20 m near the
  kaiju leaves the Behemoth frame.
- Kill orphaned Godot children by PID after TaskStop (parent is timeout.exe; check start time).

## Rules learnt the hard way
- gdformat on Windows writes CRLF: run sed -i 's/\r$//' after it (repo is eol=lf).
- Python file writes: open(..., newline='') or CRLF creeps in.
- Never edit sim files while a background run reads the worktree: snapshot with git archive.
