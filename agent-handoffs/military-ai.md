# Military AI handoff, 2026-10-19 (r4 in progress)
## State: running a check (r4 code 6a0a5db pushed to PR #50; CI is the only verification: NO LOCAL GODOT (director "dont use godot", LEAD); pacing waits for LEAD's go)

## Task
D-066 (director 2026-10-18): "make sure the tanks and helicopters path finding is logical and
not unnatural, they should look and operate like a professional military". LEAD = session
"Kaiju: LEAD" (local_106fc100...). #50 ships in a second exe straight after the demo (D-088).
r4 = LEAD's fix list 1-6 (item 7, tank vs car, stays out) plus a young retune.

## Branch
claude/military-ai (worktree ../Kaiju-Incremental-wt/military-ai), PR #50 into
claude/look-options. LEAD merges. Resync onto look-options after #36 lands (evolve1 cost 400).

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
1. Read CI for the r4 head (gh run list -b claude/military-ai). The military_view thresholds
   (95%, 0 HUD) never ran: a red result gives the real numbers. Fix on CI only.
2. Clip on CI: capture.yml (tools/capture/ci_capture.sh capture_military.gd --movie), 720p,
   gl_compatibility, one run at a time. Same spot, CLIP_AT (5,-70).
3. Probe table for the PR body: min drawn gap, max yaw while moving, heli in-frame % per
   tier, min facade clearance, rotor-roof clearance, fire yaw. The view check prints the clip's
   numbers; per-tier in-frame needs a CI probe or LEAD's go for local Godot.
4. Young retune + pacing (needs local Godot, LEAD's go): bar evolve1 0.26 h +-5%, young
   defeats within +-2 of the base count on the same seeds; measure the base the same way.
   Re-measure damage per stage (balance +-5%).
5. PR body r4 section, sim-review packet section 6 (TankSpacing, AirSpace, wing side), then
   ping LEAD with the full SHA.

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
