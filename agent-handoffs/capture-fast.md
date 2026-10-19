# capture-fast handoff / PR body draft

## PR body draft
Title: capture: --fast review mode as the CI default (gl_compatibility, 960x540, 20 fps, SSAO/glow off)

Why: CI captures took 15-32 min; 97% was software render. Runs 39270794927 / 39266833950 used
`renderer=auto` = forward_plus on lavapipe (2.2-5 s/frame). An explicit gl_compatibility was already honoured by the workflow; the default `auto` was
the cause: nobody passed it.

What:
- `tools/capture/capture_modes.env`: the only place for the numbers (fast and full).
- `capture.yml`: new input `fast` (default true); renderer/fps/resolution default to the mode's;
  `--fast` appended to the script args; RENDERER.txt now also records the engine banner line.
- `ci_capture.sh`: `--fast` (default) / `--full`.
- `scenes/city_view.gd`: SSAO and glow off only when `--fast` is among the user args.
  Shipped game unchanged (no arg, no change).

Evidence: see "Measurement" below (filled after the run).

## Measurement
Run 39280140412 (tower take, --fast): job 19m50s vs 32 min before. RENDERER.txt: OpenGL 4.5 Mesa llvmpipe, 960x540 @ 20 fps. Frames 150/450/690: croc, tower fall, debris, fire all clear; flatter shading, no glow.
Clip: C:/Users/DANTE/AppData/Local/Temp/kcap/fast-39280140412/capture-39280140412-0/clip.mp4

## State
Branch claude/capture-fast pushed, no PR (cap). Measurement ran on tmp/capture-fast-test
(= this branch + merge of claude/croc-contact for capture_contact.gd); delete it when done.
Not exercised: --full path on CI; other capture scripts with --fast.
