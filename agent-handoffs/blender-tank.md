# blender-tank handoff (2026-10-17 12:55)
State: running a check (CI capture of tanks firing + helis, heli branch)

## Task
Director 2026-10-17 "make a tank in blender"; D-042 picked 2x real size, desert tan. Lead brief: wire the
tank into the game (turret aims, gun recoils, crush/grab intact), CI capture, PR; then a helicopter
the same way (spinning main + tail rotor nodes) as a second PR.

## Branches and PRs
- claude/blender-tank-eed18f -> PR #17 into claude/look-options (tank). Worktree .claude/worktrees/blender-tank-eed18f.
- claude/blender-heli (same worktree, stacked on the tank branch) -> heli PR into claude/look-options;
  it carries #17's commits until #17 merges. Switch with `git switch <branch>` (both clean when committed).

## Done
- Pipeline: assets/source/vehicles/build_tank.py, build_heli.py (bpy, headless) -> .blend/.glb (LFS) ->
  tools/blender/voxelize_parts.py (one grid, per-part kvox + <base>.parts.json hinges) -> assets/vehicles/.
- scenes/vehicle_parts.gd (VehicleParts loader), TankModel (hull/turret/barrel, aim, fire recoil),
  HelicopterModel (body, main rotor Y spin, tail rotor X spin, chin gun aim, fire muzzle).
- rampage.gd: hull heads where it drives, turret aims at the kaiju, shells from the muzzle.
  powers_view.gd: heli gun aims, bursts from the muzzle; heli no longer scaled by body_scale (D-042 fixes 2x).
- tuning.json "vehicles": tank_height 1.61, heli_height 2.75, turn/recoil/spin rates.
- Smoke checks: _check_tank (3), _check_heli (2); floor smoke 12 -> 17. All six suites green locally.
- Boards (notes folder): blender-tank/tank_board.png (lead PASS), tanks_reptilian_*.png (CI still);
  blender-heli/heli_board.png. Licensing rows for both models.

## Blocked / not exercised
- GitHub Actions refuses every job ("recent account payments have failed or your spending limit...").
  CI tests + captures cannot run; billing is the director's. Only one CI capture got through (run 38935554448).
- No capture of a tank firing, a grab/throw of the new tank, or the heli in game.
- Track scroll skipped: flat dark tracks under the skirts would not show it.

## Gotchas
- Blender MCP: safe mode (no exec/open/quit); open_mainfile works. Start a window with
  --python-expr registering a timer that calls bpy.ops.blendermcp.start_server(). Close by PID.
- glTF-imported roots use quaternion rotation: set rotation_mode "XYZ" before rotation_euler.
- Fonts are LFS: a fresh worktree needs `git lfs pull --include "assets/fonts/*"` or the flow suite
  floods font errors and times out.
- GODOT=C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe

## Next (lead, 12:49)
- Director: "tank and heli models look great". Repo public, Actions back; lead reran #17/#18 checks.
- look-options merged into both branches; capture_tanks.gd now wades into buildings for 40 s.
- Capture dispatched on claude/blender-heli with --movie (reptilian). Send stills + clip to the lead.
- No octopus-grab capture: locomotion paused (D-044).
- Worktree is checked out on claude/blender-heli.

## Running jobs
CI capture (capture.yml, ci_capture.sh --movie --ref=claude/blender-heli) -> scratchpad ci2/. Blender closed.
