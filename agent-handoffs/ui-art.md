# UI art (HUD skill icons, D-127) handoff, 2026-10-22
## State: awaiting lead (critic, then the director)
## Task
HUD skill icons for the bottom-left rings (breath, dash, ultimate), each showing the move. Director (D-127): rounds 1-3
(3D renders, then hand-drawn SVG x2) rejected; he then picked "game-icons.net base" (human-made bold silhouettes,
CC BY 3.0, free commercial use, credit needed), art inside the dark disc with a 3-4 px gap to the yellow ring.
## Branch
claude/ui-art on origin/claude/look-options 802636cd; 7a18ceb8 = 3D renderer (kept as a tool); round-3 flat icons
662e64b9; round 4 (this): game-icons.net base.
## What is on the branch
assets/ui/icons/src/{breath,dash,ultimate}.svg: game-icons.net silhouettes (CC BY 3.0) recoloured (fill f2efe6 = UiKit.TEXT,
accent ffcc00 = UiKit.ACCENT), clipped to a 111 px radius disc (256 canvas).
- breath = T-Rex Skull (open jaws, eye, snout; Delapouite) + Power Lightning bolt (Lorc) in front of the snout, a cleared
  channel in the skull; dash = Bird Claw foot (Lorc) + yellow speed streaks (ours); ultimate = Sea Serpent head (Lorc),
  raised, mouth wide, + a wide yellow beam with a white core, soft fade at both ends (ours).
- Board-4 critic FIX (rex head = crumpled blob, short beam with a hard cut, same pose twice) fixed in board 5.
- URLs and authors in LICENSING_REGISTER (CLEARED) and docs/CREDITS.md (new; no credits file existed).
- Rejected: dinosaur-rex and dragon-head (blob at real size), croc-jaws (messy tile), others in the first sheet.
tools/ui/svg_icons.gd rasterises to 256 px PNGs with AA (ThorVG handles clipPath, mask and gradients).
## Ring change for claude/ui-redesign (NOT pushed there; the lead hands it on; unchanged from round 3)
data/tuning.json ui.hud: "ring_radius" 16.0 -> 17.5, "ring_small_radius" 16.0 -> 17.5, "ring_width" 4.0 -> 3.0
scenes/hud_ring.gd: const OUTLINE := 2.0 -> 1.0; const ICON_SHARE := 0.62 -> 0.95
Then run tools/ui/svg_icons.gd on that branch (replaces assets/ui/icons/*.png).
ALSO: assets/ui/icons/{breath,dash,ultimate}.png.import: mipmaps/generate=false -> true. The HUD shows the 256 px PNGs at
59 px (4.3x down) with LINEAR_WITH_MIPMAPS; without mipmaps the edges stair-step (seen in board4's capture), with them
they are smooth (board5).
## Evidence
Board: lead scratchpad uiart/board5/skill-icons-board.png (A new vs B current, real size + 3x smoothed, flat grey panel).
Captures: real game HUD on the scratch worktree ../ui-art-hud (origin/claude/ui-redesign e79cd24d + ring change + new
PNGs + mipmaps), 3840x2097, RTX 4070 SUPER, off-screen no_focus override.cfg (board4/zz_icon_board.gd, hud_cap.sh).
Measured (gap.py, screen px): yellow band 5.1-7.1; art-to-ring gap min 4.4 (breath), 4.0 (dash), 4.9 (ultimate);
icon square 59 px; art max radius 111/128. Lead removes ../ui-art-hud (and local branch claude/ui-art-hud-tmp).
## Not exercised
Rings on cooldown (grey tint over the art), 125% UI scale, in-game credits screen (none exists yet).
## Open decisions
Director: the set (A). Breath skull is by a second author (Delapouite, same licence).
## Rules learnt the hard way
A SCRIPT ERROR in a --script SceneTree never quits: run Godot under `timeout`, check the exit code. Git clone into a
long scratchpad path fails on Windows (use -c core.longpaths=true). Python PIL needs no -I (user site); run -I only on
scripts that read downloads.
