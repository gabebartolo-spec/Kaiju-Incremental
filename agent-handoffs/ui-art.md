# UI art (HUD skill icons, D-127) handoff, 2026-10-22
## State: awaiting lead (critic, then the director)
## Task
HUD skill icons for the bottom-left rings (breath, dash, ultimate). Director (D-127, #45-47): icons show the move
(breath = croc jaws with lightning, dash = clawed foot mid-charge, ultimate likewise). Round 1 (3D renders, voxel vs
smooth) was rejected ("those icons look horrible"); he picked "Bold flat 2D icons" and "yellow circle is way too big".
Round 2 (this): hand-authored flat SVG icons, a thinner ring, icons filling the ring, board new flat (A) vs current (B).
## Branch and commit
claude/ui-art on origin/claude/look-options 802636cd: 7a18ceb8 = the 3D renderer (tools/capture/render_icon.gd,
icon_*.gd, kept as a tool), then the flat icons commit. Old history backup: local ref claude/ui-art-pre-rebase.
## What is on the branch
assets/ui/icons/src/{breath,dash,ultimate}.svg (+ .gdignore): hand-written paths, fill f2efe6 (UiKit.TEXT), accent
ffcc00 (UiKit.ACCENT), shapes >= 16 px at 256 (>= 4 px at 64). tools/ui/svg_icons.gd rasterises them to 256 px
PNGs (default out res://assets/ui/icons; ui-redesign loads breath/dash/ultimate.png from there).
LICENSING_REGISTER row: ours, CLEARED.
## Ring change for claude/ui-redesign (NOT pushed there; the lead hands it on)
data/tuning.json ui.hud: "ring_radius": 16.0 -> 17.5, "ring_small_radius": 16.0 -> 17.5, "ring_width": 4.0 -> 3.0
scenes/hud_ring.gd: const OUTLINE := 2.0 -> 1.0; const ICON_SHARE := 0.62 -> 1.25
Then run tools/ui/svg_icons.gd on that branch to replace assets/ui/icons/*.png.
## Evidence
Board: lead scratchpad uiart/board2/skill-icons-board.png (title, A/B rows with names, real size + 3x, in-game
bottom-left crop at real size). Masters: uiart/board2/masters/*.png.
Captures: real game (ui-redesign 0a44c8d6 in a scratch worktree, since removed), 3840x2097, RTX 4070 SUPER,
300 fight frames, rings forced ready (scratchpad/uiart/capture_icon_board.gd).
Measured (dash ring, 7 angles): yellow band 7.9 px -> 5.7 px; dark rim 3.9 -> 1.9 px (1 unit); ring outer ~78 px
(unchanged); icon square 77.7 px; art span breath 67.4 x 54.3, dash 68.6 x 66.2, ultimate 64.3 x 59.5 px.
Rasterising from the committed SVGs matches the board masters pixel for pixel.
Lint: gdformat/gdlint clean, tuning_keys ok, complexity_ratchet ok, check_scripts 347/0.
## Not exercised
Rings on cooldown (grey tint over the new art) and the 125% UI scale; the icon art overlaps the band slightly at
its widest points (by design, icon >= 80% of the ring), so the charge arc is partly covered there.
## Open decisions
Director: the flat set (A). Accent colour is the UI hazard yellow; one hex in each SVG if he wants another.
## Running jobs
none
## Findings for the lead
posmod() on floats truncates to int (the 3D voxel sampler read one texel). Godot's SVG reader (ThorVG) handles
clipPath and evenodd holes: a flat icon set needs no extra tool.
## Rules learnt the hard way (under 10 lines)
A SCRIPT ERROR in a --script SceneTree never quits: always run Godot under `timeout` and check the exit code.
The focus guard hook resolves `--path .` from the session cwd: pass the absolute --path for windowed runs.
