# capture-fast handoff / PR body draft

## PR body draft
Title: capture: --fast review mode as the CI default (gl_compatibility, 960x540, 20 fps, SSAO/glow off)

Why: CI captures took 15-32 min; 97% was software render. Runs 39270794927 / 39266833950 used
`renderer=auto` = forward_plus on lavapipe (2.2-5 s/frame). An explicit gl_compatibility WAS honoured
by the workflow (`gateway: gl_compatibility) run_one gl_compatibility opengl3`); the default `auto` was
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
(run id, wall time, readability verdict: filled in by the builder)

## State
Branch claude/capture-fast pushed, no PR (cap). Measurement ran on tmp/capture-fast-test
(= this branch + merge of claude/croc-contact for capture_contact.gd); delete it when done.
Not exercised: --full path on CI; other capture scripts with --fast.
