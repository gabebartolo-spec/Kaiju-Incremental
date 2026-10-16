# blender-tank handoff (2026-10-17 03:40)
State: awaiting lead (board sent; scale and palette are the lead's/director's call)

## Task
Director 2026-10-17: "ok can you make stuff in blender now? try to make a tank". Lead brief: model an MBT
in Blender via the MCP, GLB + .blend under assets/source/vehicles, voxelize at game scale, comparison board to the lead.

## Branch and commit
claude/blender-tank-eed18f (worktree .claude/worktrees/blender-tank-eed18f), pushed; no PR yet.

## Done
- `assets/source/vehicles/build_tank.py` builds the tank (headless `blender -b --python ... -- out.blend out.glb`).
  Hull > Tracks, Turret (pivot on ring) > Barrel (pivot on trunnion), CommanderMG. Faces -Y (glTF front, voxelize
  convention; Hull root turned 180 deg). 9.82 x 3.71 m, 2.4 m at cupola. Desert tan (#b89c6a), dark tracks.
- tank_mbt.blend / .glb; tank_mbt_h7.kvox (true scale, ~city RES 8 grain), tank_mbt_h14.kvox (for a 2x tank).
- Checked through the live Blender MCP `look`: 4 views clean, wheels on the belt, pivots turn/elevate.
- Board: side-session notes folder `blender-tank/tank_board.png` (+ compare_render.py that made the line-up).
- LICENSING_REGISTER row added (ours, CLEARED).

## Findings
- Game scale: 1 unit = 1 floor (~3.3 m); city voxel 1/8 u. Real tank = 0.8 u tall, 3 u long. The current
  code tank (scenes/tank_model.gd) is 1.6 u tall, 3.6 u long: ~2x real height and stubby.
- Olive goes near-black under blue-hour light; tan reads clearly.
- Voxelizing loses the wheels (skirts hide them, shell only) and thickens the barrel to one voxel.

## Gotchas
- Blender MCP runs in SAFE MODE: no exec/open; bpy.ops.wm.open_mainfile works. Paste code inline or use `blender -b`.
- glTF-imported roots use quaternion rotation: set rotation_mode = "XYZ" before touching rotation_euler.
- Blender (PID 461804, MCP host) closed at the end by PID, per the lead brief; quit_blender is blocked by safe mode.

## Open decisions (lead/director)
1. Scale: true scale (h7, 0.8 u tall) or the current 2x presentation (h14)?
2. Palette: tan (recommended) or olive.
3. Then: wire the kvox into TankModel (Kvox.read) and take an in-game CI capture. Not started.

## Running jobs
None.
