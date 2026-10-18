# Military AI handoff, 2026-10-19 (r4 in progress)
## State: running a check (pacing base d18bba1 vs #50 4f1ad4a, headless, background; CI green at 4f1ad4a; tanks clip done: notes clip_r4/clip_720.mp4)

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

## Next (LEAD 2026-10-19: #50 tanks only; helis on claude/heli-flight after a design note)
#50 head 4f1ad4a, CI green (military 9 tank checks). Probe table so far (CI VIEW, clip scene):
tank drawn gap min 0.87 m, 0 touching, yaw while moving max 8.0 deg (1084 tank-steps).
Earlier local probe (Behemoth + Apex rampages, 3 seeds): 0 touches, 0 yaw > 10.
Clip: local opengl3, off-screen override.cfg (removed), 18 s at 4f1ad4a:
notes military-ai/clip_r4/clip_720.mp4 + stills.
2x check: frame 600's near tank looks diagonal, but numerically it is on a N-S street at yaw 0
(perspective at the frame edge). Tank 5 at 840 is a standing 37 deg pivot at the crossing.
Tanks over parked cars: item 7, out.
1. Pacing: scratchpad snapB5 (base) and snapM5 (#50), tools/pacing_dmg.gd (pacing + DMG per tier).
   Output pacing_snapB5.txt / pacing_snapM5.txt. Bars: evolve1 within 5% of the base, young
   defeats within 2, tank dmg/run within 5% per tier. Retune young if outside the bar.
2. PR body (scratchpad pr_body.md: rewrite for tanks only) + gh pr edit 50.
3. Design note (probe_note.gd, run headless after pacing), then ping LEAD with the full SHA.

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
