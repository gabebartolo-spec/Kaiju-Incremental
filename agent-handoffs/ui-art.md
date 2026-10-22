# UI art (HUD skill icons, D-127) handoff, 2026-10-22
## State: awaiting lead (critic, then the director)
## Task
HUD skill icons for the bottom-left rings (breath, dash, ultimate). Director (D-127, #45-47): icons show the move
(breath = croc jaws with lightning, dash = clawed foot mid-charge, ultimate likewise). Round 1 (3D renders, voxel vs
smooth) was rejected ("those icons look horrible"); he picked "Bold flat 2D icons" and "yellow circle is way too big".
Round 2: hand-authored flat SVG icons, thinner ring, board new flat (A) vs current (B); critic: art covered the ring.
Round 3 (this): art inside the dark disc with a 3-4 px gap; breath bolt 2x thicker inside the mouth, teeth cleared;
dash = side-view foot running right, 3 chunky clawed toes, white streaks left; ultimate = side-view head like breath
with a wide straight white-core beam; board on a flat grey panel, real size + 3x only.
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
scenes/hud_ring.gd: const OUTLINE := 2.0 -> 1.0; const ICON_SHARE := 0.62 -> 0.95
Then run tools/ui/svg_icons.gd on that branch to replace assets/ui/icons/*.png.
## Evidence
Board: lead scratchpad uiart/board3/skill-icons-board.png (A new flat vs B current, real size + 3x, flat grey panel
5c6068 under the HUD, hurt vignette hidden). Masters: uiart/board3/masters/*.png; ring diff: board3/ring-change.diff.
Captures: real game HUD (ui-redesign 0a44c8d6, scratch worktree, removed), 3840x2097, RTX 4070 SUPER, rings forced
ready (scratchpad/uiart/capture_icon_board.gd + --panel). Measured with scratchpad/uiart/gap.py (144 rays a ring):
yellow band 5.1-7.1 px incl. soft edge (current 7.4-9.3); art-to-ring gap min 3.0 / 3.3 / 3.1 px (breath / dash /
ultimate); icon square 59 px; all art inside r 119/128 of the 256 canvas.
Rasterising from the committed SVGs matches the board masters pixel for pixel.
## Not exercised
Rings on cooldown (grey tint over the new art) and the 125% UI scale.
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
