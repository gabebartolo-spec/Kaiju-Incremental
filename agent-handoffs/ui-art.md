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
assets/ui/icons/src/{breath,dash,ultimate}.svg: Lorc silhouettes recoloured (fill f2efe6 = UiKit.TEXT, accent ffcc00 =
UiKit.ACCENT), clipped to a 111 px radius disc (256 canvas), a mask clears a channel for the bolt in the head.
- breath = Dinosaur Rex head biting Power Lightning (yellow bolt); dash = Bird Claw foot + yellow speed streaks (ours);
  ultimate = Dinosaur Rex head mirrored + wide yellow beam with white core (ours).
- All by Lorc (https://lorcblog.blogspot.com), https://game-icons.net/1x1/lorc/{dinosaur-rex,power-lightning,bird-claw}.html,
  CC BY 3.0. LICENSING_REGISTER row CLEARED; credit line in the new docs/CREDITS.md (the project had no credits file).
- Other candidates seen (all Lorc/Delapouite, CC BY 3.0): croc-jaws (reads as a messy tile in a circle, rejected),
  dragon-head, shark-jaws, t-rex-skull, velociraptor, frog-foot, fire-dash, sprint, boot-stomp, heavy-lightning,
  energy-breath, ringed-beam.
tools/ui/svg_icons.gd rasterises to 256 px PNGs (ThorVG handles clipPath and mask). Source repo clone was
github.com/game-icons/icons (license.txt: per-author folders).
## Ring change for claude/ui-redesign (NOT pushed there; the lead hands it on; unchanged from round 3)
data/tuning.json ui.hud: "ring_radius" 16.0 -> 17.5, "ring_small_radius" 16.0 -> 17.5, "ring_width" 4.0 -> 3.0
scenes/hud_ring.gd: const OUTLINE := 2.0 -> 1.0; const ICON_SHARE := 0.62 -> 0.95
Then run tools/ui/svg_icons.gd on that branch (replaces assets/ui/icons/*.png).
## Evidence
Board: lead scratchpad uiart/board4/skill-icons-board.png (A new vs B current, real size + 3x, flat grey panel 5c6068,
hurt vignette hidden). Captures: real game HUD on a scratch worktree of origin/claude/ui-redesign e79cd24d, 3840x2097,
RTX 4070 SUPER, off-screen no_focus override.cfg, rings forced ready (board4/zz_icon_board.gd, hud_cap.sh).
Measured (board4/../gap.py, 144 rays a ring, screen px): yellow band 5.1-7.1; art-to-ring gap min 4.4 (breath),
4.0 (dash), 3.8 (ultimate); icon square 59 px; art max radius 111/128 of the canvas.
## Not exercised
Rings on cooldown (grey tint over the art), 125% UI scale, in-game credits screen (none exists yet).
## Open decisions
Director: the set (A). Both heads are the same Lorc rex (breath faces right with a bolt, ultimate mirrored with a beam).
## Rules learnt the hard way
A SCRIPT ERROR in a --script SceneTree never quits: run Godot under `timeout`, check the exit code. Git clone into a
long scratchpad path fails on Windows (use -c core.longpaths=true). Python PIL needs no -I (user site); run -I only on
scripts that read downloads.
