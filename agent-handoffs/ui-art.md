# UI art (HUD skill icons, D-127) handoff, 2026-10-22
## State: awaiting lead (critic, then the director's A/B pick)
## Task
Wave 2 brief (lead scratchpad BRIEF-ui-art.md): tools/capture/render_icon.gd renders breath, dash and ultimate icons
in BOTH styles (A voxel, B smooth), 256 px masters, transparent, readable in the 80 px HUD ring. One labelled board
(A vs B, each icon at real size in the HUD ring and at 2x) captured from the game's HUD on the local GPU. Push, no PR.
Director (D-127, #45-47): icons show the move itself (breath = croc jaws with lightning, dash = clawed foot
mid-charge, ultimate likewise); "try both and show me".
Models (lead six-view PASS, Tripo): C:/Users/DANTE/Downloads/kaiju_tripo/hud_croc_head_c9b2b460.glb,
hud_dash_foot_ab9504ce.glb. Both face +z, up +y; read in ~10 s, no decimation needed. Never in assets/.
## Branch and commit
claude/ui-art rebuilt on origin/claude/look-options 802636cd (old WIP da048e0a cherry-picked, then finished).
Backup of the old history: local ref claude/ui-art-pre-rebase (not pushed). Tools only: nothing in assets/ or data/.
## What the tool does now
render_icon.gd: GLB read once; --style=voxel|smooth|both; several yaws per run; --crop; --fx=lightning|beam|dash
with --mouth/--aim/--reach; --margin; --exposure; 256 px master + 80 px preview. Camera fits the model AND its FX
exactly (IconStage._aim); the light rig turns with the view; SSAO radius scales with the model.
Fixes in the stopped builder's WIP: posmod -> fposmod in the texture sampler (every voxel took texel 0,0: black
voxel croc); typed-array ternary parse error; outline colour from UiKit.BG (outline_color is ui-redesign only);
FX alpha-blended (additive vanished on a transparent background); beam is our own ribbon (beam.gdshader used TIME).
## Final render commands (each wrapped in timeout 400; ~40 s each, RTX 4070 SUPER)
common: --face=0,0,1 --cells=20 --margin=0.02 --exposure=1.5 --style=both
breath:   croc --yaw=80 --pitch=8 --fx=lightning --mouth=0.5,0.42,0.95 --reach=0.45
dash:     foot --yaw=60 --pitch=10 --fx=dash --mouth=0.5,0.4,0.3 --reach=0.6 --crop=0,0,0,1,0.55,1
ultimate: croc --yaw=80 --pitch=8 --fx=beam --mouth=0.5,0.42,0.95 --reach=0.5
Wrapper: scratchpad/uiart/render_all.sh (env BREATH/DASH/ULT carry the per-icon args).
## Evidence
Board: lead scratchpad uiart/board/ui-art-icons-board.png; masters uiart/board/masters/*_256.png.
Board frames: real game HUD (claude/ui-redesign 0a44c8d6) in a scratch worktree, 3840x2097 window, local GPU,
icons dropped into assets/ui/icons, rings forced ready (scratchpad/uiart/capture_icon_board.gd, not committed).
Measured: ring 81.6 px, icon 54.4 px with HudRing.ICON_SHARE = 1.0 (lead's yes for the board; 0.62 today = 33.7 px).
Determinism: a rerun from the committed code gave pixel-identical masters (max diff 0, all 6).
Lint: gdformat/gdlint clean, tuning_keys ok, complexity_ratchet ok, check_scripts 346/0.
## Not exercised
Suites: no suite loads tools/capture (check_scripts compiles them). Ring not ready (grey tint) and the 125% UI scale
not captured. Icons not wired into assets/ (waits for the director's pick + licensing row).
## Open decisions
Director: A (voxel) or B (smooth). ui-redesign owner: ICON_SHARE 0.62 -> 1.0 (one line in scenes/hud_ring.gd).
## Running jobs
none
## Findings for the lead
posmod() on floats silently truncates to int: the voxel sampler read one texel. A colour bug in a tool hides
behind "dark lighting"; measure the sampled colour before tuning lights.
## Rules learnt the hard way (under 10 lines)
A SCRIPT ERROR in a --script SceneTree never quits: always run Godot under `timeout` and check the exit code.
