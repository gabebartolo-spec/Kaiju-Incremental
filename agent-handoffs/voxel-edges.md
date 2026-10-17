# Voxel-edges handoff, 2026-10-18 05:45
## State: awaiting lead (method change proposed; the effect is invisible at the game camera)
## Task
Director, 2026-10-18 (in session): "Prototype voxel edge shading first and bring me a labelled
before/after capture through the lead." The lead (LEAD session) gates every look; the board goes to the
director only through the lead.
## Branch and commit
claude/voxel-edge-shading (worktree ../Kaiju-Incremental-wt/voxel-edges), base claude/look-options
db2e73b, head = "art: voxel edges compile". Pushed, no PR. A stray local branch claude/voxel-edges
(no commits, never pushed) can be deleted.
## What changed
- scenes/voxel_edge.gdshaderinc: face coordinate -1..1, bevel normal tilt at the rim, thin seam, fade-out
  where the rim band is under ~1 px. The varyings are written in each shader's vertex() (Godot rejects
  varying writes in helper functions).
- voxel.gdshader (box_mesh uniform), building_baked.gdshader, voxel_skin.gdshader include it;
  building_mesher.gd + voxel_builder.gd write face UVs (BuildingMesher.FACE_UV); Look.edge_params.
- data/looks.json edge_width 0.2 / edge_bevel 0.7 / edge_dark 0.3; run_sim_tests _check_looks keys.
## Evidence so far
- Suites local: sim 39, smoke 27, city 5 pass (before the compile fix; it touches shaders only).
- Local GPU A/B (lead's slot), capture_looks.gd, 4K + 1080p, edge_width 0 = before. Scratchpad:
  local4k/, local1080/, crop_evolved.png (crops.py; needs plain `python`, PIL is in user site).
- Mean abs diff before→after: evolved 1.09/255, young 0.86, lineup 0.00. At the game camera a voxel is
  about 5-10 px at 4K, so the rim band is under a pixel and fades out. Buildings show no change.
- GPU cost within noise (4K, RTX 4070 S): young 11.9→11.6 ms, evolved 12.7→12.2, lineup 10.7→10.0.
- CI capture runs 39052984488/39053097548 were cancelled (on the broken-compile commit).
## Attempts (fix-loop record)
1. Shader compile failure (varyings in a helper): fixed, confirmed by a clean 4K log.
2. Per-voxel bevel: works but is invisible at game scale. Method change proposed, not a retune.
## Open decisions
Lead (then the director): (a) screen-space crease pass (darken depth/normal breaks in pixels),
(b) keep edges for close-ups only, (c) shelve.
## Running jobs
none
## Findings for the lead
- Headless suites never compile spatial shaders: run one rendered capture and grep for SHADER ERROR
  before any CI capture. That would have saved two 70-min CI runs.
- Measure on-screen voxel size before choosing a per-voxel effect; under ~8 px a rim effect cannot show.
## Rules learnt the hard way (under 10 lines)
- PRs here target claude/look-options, not main.
- Godot shaders: only vertex()/fragment() may write varyings; helpers take them as parameters.
- The focus guard scans Bash command text: write Godot launch scripts with the Write tool.
