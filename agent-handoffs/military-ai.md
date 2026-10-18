# Military AI handoff, 2026-10-19 (r4 in progress)
## State: blocked (local Godot paused by LEAD for the director's playtest; heli framing not converging on CI, next step is a local probe: scratchpad probe_room_miss.gd). Head e2882b5.

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". LEAD = session
"Kaiju: LEAD" (local_106fc100...). #50 ships in a second exe straight after the demo (D-088).
r4 = LEAD's fix list 1-6 (item 7, tank vs car, stays out) plus a young retune.

## Branch
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options. LEAD merges. Synced onto look-options bf06cdd (#36 in: evolve1 cost 400, per_level army scaling).

## r4 done (6a0a5db), measured with a headless clip probe before the Godot stop
Probe: scratchpad probe_clip.gd = capture_military's scene; every frame it reads the drawn tank
parts (voxel hulls through the models' transforms), yaw vs the plan's road, and helicopter
screen points vs the frame (4% margin) and HUD plates.
- Tanks (1, 2): TankSpacing = hull + turret + gun aimed at the kaiju, plus clear; post_gap 9.5;
  a tank moves only once its hull is on the new heading (|turn| <= one step's rate).
  r3: 169 overlap frame-pairs (the rear tank's BARREL over the front tank), yaw max 18 deg.
  Now: 0 overlaps, min gap 0.82 m, yaw max 8.0 deg, 0 over a lot.
- Helicopters (3-6), LEAD call A: AirSpace (air.view = camera + HUD plate rects) gives each
  bearing the farthest r in frame at roof_clear over roofs within facade 6 m; the pair turns
  back short of a bearing with nowhere (_blocked); fail-safe holds r (never in on the kaiju).
  Wingman: wing_gap 14 along the arc, stagger 3 m up, fixed side (no crossing), covers at
  cruise during the lead's run. fire_cone 18. In frame: r3 12% -> 77.5% at facade 15;
  facade 6 not yet measured.
  Room (bearings with an in-frame spot), facade 15 vs 6: Beh 23/65%, Col 48/82, Apex 66/86%.
- Checks: military 21 (stacked wingman; military_view.gd: air.view pinned to the camera,
  helis >= 95% in frame + 0 under HUD, drawn tank parts never touch). DRIVE_DEG 10, FIRE_YAW 20.

## Next
Decisions: LEAD A (2026-10-19). Helicopters fire only in sight. With no in-frame spot they hold
off-screen and sweep for room. Camera unchanged. Rebalance any lost damage with heli fire rate,
not tanks.
Done locally, not yet green on CI:
- Tanks: open_up after a gun swing, last metre, square = skew_deg. Probe: 0 touches, 0 yaw.
- Helis: fire in sight only (CI: 0 bursts unseen).
Still failing (CI e2882b5, military 6 of 22):
- Heli in sight where there is room: Beh 22%, Apex 68% (bar 95%).
- Helis in sight at all: Beh 8%, Apex 40% of rampage time.
- Rotor-roof -5.2 m, faced closest 11.4 vs 13.2, altitude "stays" 5.
- Bursts 2 at Behemoth (floor 20): damage collapse, so rebalance fire rate after the pacing.
1. On LEAD's go: run probe_room_miss.gd from tests/ (copy it in, delete after) at TIERS=2,4.
   Find why helis with room are not in sight (r vs plan, alt vs plan, state). After several failed
   fixes, change method. Consider: target = in-frame point nearest the formation slot, flown
   toward at a speed cap. That way in-sight follows from the plan, not from many easing rules.
2. Pacing base (snapBase4 = look-options 24dc0a8) vs r4, same seeds; young and damage per run by tier.
3. Clip on capture.yml (one at a time), PR body r4, ping LEAD with the full SHA.

## Findings for the lead
- Numeric per-frame probes caught what crops missed: the "hulls interpenetrating" was a gun.
- The Behemoth camera can't show a helicopter above ~13 m (16 m: not even over the kaiju),
  so roof clearance + frame force going round tall blocks, not over them.
- A headless Godot viewport is 1920x1920 unless root.size is set; screen probes need it.

## Rules learnt the hard way
- gdformat on Windows writes CRLF: sed -i 's/\r$//' after it. Python: open(..., newline='').
- Warnings are errors: Variant from a Dictionary/Array into a typed param needs a typed var.
- Never edit sim files while a background run reads the worktree: git archive snapshots.
- grep filters on probe output: match the probe's own prefix, or results are silently lost.
- Kill orphaned Godot children by PID after TaskStop (parent timeout.exe; match start time).
