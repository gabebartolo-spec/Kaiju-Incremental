# Voxel-edges handoff, 2026-10-18
## State: running a check (before/after capture_looks on CI; local sim/smoke/city suites)
## Task
Director, 2026-10-18 (direct, in session): "Prototype voxel edge shading first and bring me a labelled
before/after capture through the lead." It came from a shader survey (session answer): edge shading
first, then scorch/char, LUT grade, volumetric fog, heat haze, impact pass. Look gate: director.
## Branch and commit
claude/voxel-edge-shading (worktree ../Kaiju-Incremental-wt/voxel-edges), base claude/look-options db2e73b.
A stray local branch claude/voxel-edges (cut from main by mistake, never pushed, no commits) is left;
delete it with `git branch -D claude/voxel-edges` once the worktree no longer uses it (the classifier
blocked removing it in the session).
## Unfinished changes
None uncommitted. PR not opened yet (opens once the capture is in hand).
## What changed
- scenes/voxel_edge.gdshaderinc (new): per-face coordinate -1..1, bevel normal tilt near the rim, thin
  dark seam, fades out where the rim band is under ~1 px (no shimmer far away).
- voxel.gdshader (box_mesh uniform: BoxMesh corners via sign(VERTEX); baked faces via UV),
  building_baked.gdshader (UV, front faces only), voxel_skin.gdshader (box corners, turned with the bone).
- building_mesher.gd + voxel_builder.gd write face UVs (BuildingMesher.FACE_UV); Look.edge_params sets
  the uniforms; building_view.gd and voxel_skin.gd call it.
- data/looks.json: edge_width 0.2, edge_bevel 0.7, edge_dark 0.3; run_sim_tests _check_looks keys.
## Evidence so far
- Before: CI capture_looks on claude/look-options (run 39052984488) -> scratchpad/before.
- After: CI capture_looks on this branch -> scratchpad/after. Check godot-*.log for SHADER ERROR.
- Local suites: first run crashed in the font import of a fresh worktree (exit 139, before any suite);
  rerun pending.
## Attempts (fix-loop record)
none yet
## Open decisions
- Director: does the edged look read better (labelled before/after, via the lead)? Tuning lives in
  looks.json only.
- If flat walls read as tiles, the next step is open-edge flags in the mesher (bevel only exposed
  rims, faint seam on flat walls).
## Running jobs
Two capture.yml runs (before, after); a local run_tests.sh (sim smoke city).
## Findings for the lead
- Worktree count is already over the cap of four (eight incl. this one); stale ones (lighting at the
  base commit, kaiju-motion paused) are the lead's call.
## Rules learnt the hard way (under 10 lines)
- PRs here target claude/look-options, not main (main is far behind).
- Headless test runs never compile spatial shaders: a shader error only shows in a rendered run (CI capture log).
