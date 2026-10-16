# blender-reptile handoff, 2026-10-17 04:05
## State: awaiting lead (board sent; A vs B is the lead's/director's call)
## Task
Director 2026-10-17: "try making the reptilian kaiju in blender". Brief from the lead: model the adult
reptile by hand in Blender via the MCP, rig-friendly; .blend + GLB under assets/source/kaiju; rig_voxel
at 160 into a separate test asset; labelled board (4 views vs Tripo adult + both voxelized) to the lead.
## Branch and commit
claude/blender-reptile-f5388e (worktree .claude/worktrees/blender-reptile-f5388e), pushed; no PR yet.
## Done
- `assets/source/kaiju/build_reptile.py` builds it headless in ~10 s:
  `blender -b --factory-startup --python assets/source/kaiju/build_reptile.py -- <out.blend> <out.glb>`.
  Metaball sculpt (tube() of overlapping ellipsoids, negative balls for eye sockets) -> voxel remesh
  0.38 m + smooth + cloud bumps; separate Jaw (+ lower teeth, tongue/palate in dark red); details by
  convex hulls placed by ray casts onto the hide: 3 rows of jagged 3-prong ivory spines (spaced by
  surface arc length), keeled scute rows, armour patches (shoulder, thigh, neck, tail flank), claws,
  teeth, small amber eyes under heavy brows. Colours per vertex -> smart UV (both objects packed
  together) -> Cycles EMIT bake 2048 -> Principled + texture; vertex colours removed before export.
- 100.6 m tall, 172 m long, faces -Y, Z up, feet on z=0 (both feet ~930 verts within 1 m), arms
  out ~10 deg below horizontal; hide watertight (0 non-manifold); 176k + 16k faces; GLB 14 MB (LFS).
- Test asset: assets/kaiju/test/reptilian_adult_blender.{kvox,rig.json} (height 160, snarl 0.35 like
  the adult): 78,692 voxels (Tripo adult 57,286), 27 bones, jaw 1013 voxels / 16 deg gap, colours
  from texture, 0 torso blemishes. Inert: the game loads kaiju by exact name only.
- Board: docs/captures/2026-10-17-blender-reptile/reptile_blender_board.png (+ notes folder copy
  blender-reptile/ with views.py, voxview.py, board.py that made it).
- Live Blender MCP: opened the .blend (PID 53284), get_scene_info + look x2 + vertex checks; closed by PID.
- LICENSING_REGISTER row (ours, CLEARED). assets/source/.gdignore (same empty file as the tank branch).
## Findings for the lead
- BUG FIXED in tools/blender/rig_voxel.py load(): `base` summed len((v, n)) = 2 per mesh, so any GLB
  with more than one mesh indexed mesh 2's triangles into mesh 1's vertices (jaw ended up as red
  voxels on the right arm). Tripo exports are single-mesh, so no current asset changes.
- rig_voxel clean_blemishes repaints "warm" torso voxels (r > g,b by 8/255): a warm ivory turned
  3,055 torso spine voxels olive. Ivory must be neutral (0.80, 0.79, 0.67).
- glTF export with a colour attribute left on makes the importer mix it over the texture, and
  rig_voxel then falls back to the species palette: remove colour attributes after baking.
- rig_voxel arm trace uses the widest band +-0.15H: drooping arms pull the root toward the thighs;
  arms must stay near horizontal (shoulder root still traces ~10 voxels low; motion code lowers arms).
## Open decisions (lead/director)
1. A (hand-modelled) or B (Tripo) for the adult? A: correct 25-30 deg lean, croc head, long
   counterweight tail, true digitigrade legs, editable script. B: richer muscle/plate surface detail.
2. If A: wire it in (rename to reptilian_adult.*), motion check in game; baby/adolescent same way?
## Running jobs
None. Blender closed.
## Rules learnt the hard way
- Blender MCP safe mode: no numpy in execute_blender_code; open the .blend by launching Blender with it.
