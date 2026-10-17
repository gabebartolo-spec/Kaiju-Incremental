# blender-tank handoff (2026-10-17 15:20)
State: running a check (CI --air capture of helicopters around a baby kaiju, for PR #18 round 1)

## Task
D-042 vehicles from Blender at 2x real, desert tan. Tank: PR #17 MERGED (ee43f3c into look-options).
Helicopter: PR #18 (claude/blender-heli) got a FIX from the lead: a heli hid the baby kaiju at the game
camera. The size stays 2x; fix the view: (1) helis orbit to the side, never in the camera-to-kaiju line,
cruise at least about 1.5x the heli length beyond the silhouette; (2) backstop: fade any vehicle that
passes between the camera and the kaiju to about 35%. Prove it with a ~20 s game-cam clip of helis
circling a baby kaiju (kaiju visible every frame) and a frame grid.

## Branch and commit
Worktree .claude/worktrees/blender-tank-eed18f, on claude/blender-heli. look-options merged in (54cee60);
fix commit c2f124c, pushed. PR #18 body updated with round 1. The tank branch is done (merged).

## Round 1 changes (c2f124c)
- sim/air_wing.gd: Heli.turn, Heli.cruise; spawn inside the allowed arc; `_keep_clear` turns a heli back
  at the arc ends; orbit_pos dives at the sides (relative to the camera bearing) to the old depth
  (radius x dive) and cruises at `cruise` = max(circle, body + clear_margin).
  tuning air: camera_bearing 90, clear_arc 60, clear_margin 16.
- scenes/vehicle_fade.gd (VehicleFade), voxel.gdshader `opacity` (4x4 Bayer screen door),
  VehicleParts.set_opacity, PowersView.helis(), eased heli heading (vehicles.heli_turn).
  rampage.gd is at the 400-line lint cap: add nothing there.
- Checks: tentacles _check_heli_keeps_clear (floor 18); smoke _check_vehicle_fade (floor 19).
- capture_tanks.gd --air: helis called in at once (chunks_destroyed), the kaiju stands 20 s, a still every 2 s.

## Attempts
- First sim version dived to 20% of the new, wider cruise: claws-5 reptiles stopped swatting helis and
  the sim check "five levels of claws break clearly more" failed (0.102 vs 0.090). Fixed by keeping the
  dive depth of the old circle. Lesson: the orbit radius is gameplay (swat window), not only a view.

## Gotchas
- The focus-guard hook blocks any Bash command whose text mentions godot + script/write-movie
  (even inside a heredoc). Write such edits with the Write tool, not python heredocs.
- Fonts are LFS: a fresh worktree needs `git lfs pull --include "assets/fonts/*"`.
- GODOT=C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
- CI capture: a 40 s 1080p clip times out (3000 s step); use --resolution=1280x720 and about 20 s.
- Blender MCP: safe mode (no exec/open/quit); open_mainfile works; start the server with a
  --python-expr timer calling bpy.ops.blendermcp.start_server(); close by PID. Coordinate with
  blender-reptile before opening Blender (one MCP instance at a time).

## Next
1. When the --air capture lands (scratchpad ci3/, log $TMP/ci3.log): check every frame that the kaiju
   is visible (frame grid at 2x), then send the clip + grid to the lead (notes folder blender-heli/).
2. Wait for the lead's re-review of #18.

## Running jobs
CI capture: ci_capture.sh --movie --resolution=1280x720 --ref=claude/blender-heli capture_tanks.gd
-- --species=reptilian --air. Blender closed.
