# Captures

Scripts here render stills and clips of the game for the art and motion checks.

## Default: render on CI, not on the director's PC

Any windowed Godot run on the director's PC, even off-screen with `no_focus`, can steal focus
from his fullscreen game ("godot was still alt-tabbing me while i gamed"). So agents capture
on GitHub Actions by default (`.github/workflows/capture.yml`: ubuntu-latest, Godot 4.7.2,
`xvfb-run`, Mesa software rendering):

```bash
tools/capture/ci_capture.sh --movie capture_rig.gd -- --species=reptilian --stage=adult --out=dir
tools/capture/ci_capture.sh capture_looks.gd -- --out=dir
```

The helper dispatches the workflow on your current (pushed) branch, waits, and downloads the
artifact into `--out` (PNG stills, `clip.mp4` for `--movie`, `godot-<renderer>.log`,
`RENDERER.txt` naming the renderer that actually ran). Options before the script name:
`--movie`, `--renderer=auto|forward_plus|mobile|gl_compatibility`, `--fps=N`,
`--resolution=WxH`, `--ref=<branch>`. Commit and push the script and scene changes first; CI
captures the pushed branch, not your working tree.

Local windowed runs only when the director is away; the focus-guard hook blocks windowed runs
while a fullscreen app is in front. `bench_rampage.gd` is a performance bench and stays out of
CI: software rendering says nothing about frame rate.

`workflow_dispatch` only works for workflows that exist on the default branch, so
`ci_capture.sh` works once `capture.yml` is on `main`. Until then a push to a `claude/**`
branch that edits `capture.yml` runs the two example captures.
## Heavy scenes go to the local GPU

Software rendering is slow: a 40 s 1080p clip hit the 3000 s step limit (PR #18), and the
stage-4 city killed runners (PR #16). Keep CI clips short (about 20 s, 720p). Render heavier
scenes locally with the off-screen no_focus override, only when the focus guard allows it.
CI checkouts need `lfs: true` (fonts are in LFS).
