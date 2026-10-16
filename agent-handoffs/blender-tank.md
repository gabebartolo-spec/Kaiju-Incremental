# blender-tank handoff (2026-10-17 03:11)
State: blocked (session hit its usage limit mid-task)

## Done (commit on claude/blender-tank-eed18f, not pushed, no PR)
- assets/source/vehicles/build_tank.py: code-built MBT (Hull > Tracks, Turret > Barrel, CommanderMG;
  pivots on turret ring and trunnion). Real metres: 9.8 m with gun, 3.7 m over skirts, ~2.4 m tall. Desert tan palette.
- tank_mbt.blend, tank_mbt.glb (headless `blender -b`), tank_mbt_h10.kvox (voxelize.py, 10 tall, 1844 voxels).

## Not done / not verified
- NO renders looked at yet: geometry unchecked (wheel/track contact, winding, floating parts). Run six_view.py first.
- Live Blender MCP runs in SAFE MODE: no exec/open, so a script file cannot be run through it; paste code inline or use `blender -b`.
- Game scale: height 10 is a guess; compare with scenes/tank_model.gd (8 voxels tall at VOXEL 0.2, stubby) and RES 8 buildings.
- LICENSING_REGISTER row (our own model, CLEARED) not added. Comparison board, CI still, send to lead: not done.
- A Blender window (PID 461804) was already open with the MCP server; not started by this session, left alone.
