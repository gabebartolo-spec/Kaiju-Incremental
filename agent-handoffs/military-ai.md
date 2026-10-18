# Military AI handoff, 2026-10-19 (r5 in progress)
## State: awaiting lead (#50 r5 at 98d21cc, CI green; heli design note sent)

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". LEAD = session
"Kaiju: LEAD" (local_106fc100...). #50 is tanks only (LEAD split 2026-10-19); helicopters live
on claude/heli-flight (head f1ee22f) and wait on a 10-line design note (methods D and B).

## Branch
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options. LEAD merges. Pushed head 4f1ad4a (CI green). Base has moved to 615930c
(tuning, pacing.gd, street_life): merge before the clip and pacing.

## r5 critic list (LEAD 2026-10-19) and what the probe found
Probe: scratchpad probe_r5.gd (clip scene, every frame, drawn models; env WALK=1 WALK_TO=780
FROM/TO dump window). Dumps F (per tank), SCR (screen angles), POLY (drawn part outlines),
CAR, CLOSE lines.
1. "Hull 35-40 deg across the N-S street at 9-10.5 s": NOT the hull. Tank 2 drives N on x=24,
   drawn hull on screen -18.9 deg = the road's own screen slope (0.0 off); the turret is at
   -57..-72 deg on screen (aimed at the kaiju). Overlay: notes military-ai/r5/
   hull_vs_turret_0600.png and _0960.png (green hull from voxels, orange turret, red barrel).
   The street is 4 m (half 2.0) + 1 m sidewalks; hull centre x=24.0; screen overhang is the
   hull's height in perspective (camera 19 m to the left).
2. Cars: police were presentation-only and ignored. New scenes/tank_keep_out.gd: cars stop
   for a tank in their lane (its real footprint) and turn round at once; a parked cruiser a
   tank closes within 6.5 m pulls back 9 m along its street; police never blockade within
   13 m of a tank. Uncrushed tank-car touches 653 (424 police) -> 0, min gap 0.44 m.
3. "Hull swings 15->40 at 15-17.5 s": the turret again; parked hull swing totals 16-24 deg
   over the whole 18 s (settling to the road).
4. Centre tank to 0.7 m: tank 8's plan to a reserve post ran through the kaiju's own
   crossing (5,-70). Fix: FiringPosts.crosses_danger rejects any route passing inside the
   danger radius; a tank in danger then falls back straight along its road (fall_back).
   Closest now 10.6 m standing, 10.3 m with the walk (danger 9.3).
5. Clip: the kaiju strides east frames 540-780 (capture_military WALK_FRAMES, walk()); tank 4
   reverses out along the avenue mid-frame (screen ~1200-1310, 590), tank 2 lower centre.
Tests: military_view.gd uses Clip.walk; new check (closest >= danger-0.5, no hull on a car).
military floor 10, README row updated.

## r5 done (head 98d21cc, synced look-options c64fa34; PR body + packet updated)
- Fixes after the suite: settle at a crossing (parked) to the nearer road; a falling-back tank
  held up re-plans after 1 s (CI caught 1.1 s in danger at Apex seed 2).
- Clip: notes military-ai/clip_r5/clip_720.mp4 + stills (450c96a). Known look issue: the lead
  tank backs out under the snout at 13-16 s (10.3 m, danger 9.3; reverse 1.5 m/s).
- Pacing vs 83af6d6 (snapB6 / snapM7): evolve1 0.27 vs 0.26 h, young 7/8 vs 6/8, tree 4.79 vs
  4.82 h; tank dmg/run young 133 vs 167 (outcome-matched), Beh 309/299, Col 651/656, Apex 686/660.

## Next
1. CI green at 98d21cc -> ping LEAD (full SHA, clip, overlay, probe table, pacing).
2. Heli design note DONE: notes military-ai/heli-design-note.md (D impossible: 8 m facades; B x1.6 23%/44%).

## Findings for the lead
- Numeric per-frame probes caught what crops missed; screen-space part outlines settle
  "is that the hull or the turret" at once.
- A headless Godot viewport is 1920x1920 unless root.size is set.
- A new class_name needs an --editor --import before a headless script can see it.

## Rules learnt the hard way
- gdformat on Windows writes CRLF: sed -i 's/\r$//' after it. Python: open(..., newline='').
- Warnings are errors: Variant from a Dictionary/Array into a typed param needs a typed var.
- Never edit sim files while a background run reads the worktree: git archive snapshots.
- Kill orphaned Godot children by PID after TaskStop (match start time).
