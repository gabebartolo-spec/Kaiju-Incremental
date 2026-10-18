# Military AI handoff, 2026-10-19 (r4 in progress)
## State: running a check (CI tests.yml on eb7baf0; STILL CI-ONLY (LEAD: no local Godot, headless included); clip on capture.yml after tests are green; pacing waits)

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
CI history this round:
- 6a0a5db..638171c: smoke compile caught bool(Variant).
- 63c26b2: military shard killed. Cause: AirSpace rescanned lots per 1 m sample (fixed: roof cache per 2 m cell),
  and the three real-scene view runs were too slow on CI (fixed eb7baf0: only the clip's scene;
  per-stage framing comes from the sim rampages through the test's own camera, military_frame.gd).
- Tentacles grab: the heli came within reach, but the grabs went to cars. The window is now 16 s.
1. Read CI for eb7baf0 (rate limit: poll every 3 min, not 10 s). VIEW lines = probe table.
2. Clip on CI: capture.yml (check gh run list -w capture.yml first: one at a time),
   script capture_military.gd, --movie, renderer gl_compatibility, 1280x720, fps 60.
3. PR body r4 section (pr_body.md in the scratchpad), sim-review packet section 7 is written.
4. Pacing + young retune wait for LEAD's go (local Godot), or a CI dispatch.
5. Ping LEAD with the full SHA.

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
