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
## Stills run on a fixed frame clock

capture.yml passes a fixed fps to every run, stills included; give a local still capture the
same flag (`--fixed-fps 60`). Without it the frames between a script's awaits and the physics
steps drift with machine load, so the same seeded shot catches a short effect in one run and
misses it in the next.

## Heavy scenes go to the local GPU

Software rendering is slow: a 40 s 1080p clip hit the 3000 s step limit (PR #18), and the
stage-4 city killed runners (PR #16). Keep CI clips short (about 20 s, 720p). Render heavier
scenes locally with the off-screen no_focus override, only when the focus guard allows it.
CI checkouts need `lfs: true` (fonts are in LFS).

## Shared kit

`capture_kit.gd` holds what the scripts share: flags (`Kit.args`), the off-screen window check
(`Kit.window_ok`: a windowed run needs the no_focus override.cfg, or CI), the kaiju's stats, the flow
test's city and rampage, a staged city, frame waits, render timings, stills and 2x crops. A new
script preloads it (`const Kit := preload("res://tools/capture/capture_kit.gd")`) instead of
copying that code.

## Keeping the folder small

A capture, probe or bench script stays only while something references it (CI, prepush, a test, another
tool, a skill or a live handoff). A one-off made for a feature goes when the feature lands: git history
keeps it (`git log --diff-filter=D -- tools/capture/<name>.gd`). 2026-10-27 (debt row 11, D-295): 61
unreferenced scripts were removed; before adding a new one, extend `capture_kit.gd` or an existing script.

## The native library guard

A missing or stale native DLL does not stop the game: it falls back to the slow GDScript mesher
and flood, so a bench would time the wrong thing. Every bench and capture tool therefore starts
with `if not NativeGuard.ok(self): return` (`native_guard.gd`): it checks that each class and
method `native/src` binds is loaded, prints what is missing and quits with exit code 2. Fix a
refusal with `bash tools/native_dll.sh fetch` (main's CI build); `KAIJU_NATIVE_OPTIONAL=1` runs on
the GDScript path on purpose. A tool that never reaches the city or the sim goes on the exempt
list in `tests/run_native_tests.gd`, which fails a tool that is neither guarded nor listed.
`tools/prepush.sh` runs `tools/native_dll.sh check` (the local DLL's md5 against main's CI build).
