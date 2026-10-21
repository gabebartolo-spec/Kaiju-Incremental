# intro-cinematic handoff, 2026-10-21
## State: running a check (final CI clip + 4K still on a0022b79)
## Task
Run intro (#11): "a quick, dramatic camera shot, zoomed in on the water which begins to ripple and fount before our
kaiju emerges, roaring with rage before the camera zooms out into the play angle ... no longer than 3 seconds".
R 20.1-20.4, ripples/fount presentation only, #27 (towers must not hide it). Lead 10 brief; push, no PR.

## Branch and commit
claude/intro-cinematic, worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/intro-cinematic,
from origin/claude/emerge-shore 1498501e + merged origin/claude/building-fade ebddc614 (CameraFollow, #27 fade).
Scratch: C:/Users/DANTE/AppData/Local/Temp/claude/C--Users-DANTE-Documents-GitHub-Kaiju-Incremental/
1df8b1cf-e628-4706-b71f-8a6225701701/scratchpad/ic (IC). native dll copied from the emerge-shore worktree (same sources).

## What changed
- sim/emergence.gd: hold_seconds (still under, top "depth" x scale below the water), rise_seconds, then a wade of
  fixed wade_seconds (stride = distance left / ticks left; any stage), max_seconds cap 3.0 kept for stalls.
  New: surfaced, "surface_break" event (top clears the water; deck_burst moved to the same tick), progress(),
  total(), break_at(). Tuning emerge: hold 0.8, rise 1.0, wade 1.0, depth 0.6 -> out on tick 168, break tick 57.
- scenes/run_intro.gd RunIntro: ticks per frame (full 1; short cut jumps to break - 0.15 s then runs the rest
  at a rate to last short_seconds 1.5; skip runs skip_ticks 8/frame), on_input (any key/pad/click, not pause),
  static shot(sim, follow, fov, frac): eye yaw 100 deg off the rest direction, low and close over the water,
  pull-out from 1.5 s, ends exactly on CameraFollow focus + rest. Tuning "intro".
- scenes/intro_water.gd IntroWater: ripple rings (Fx.shockwave) every 0.2 s while under, cube-droplet fount
  from 0.3 s to the break, a spray burst at the break. Tuning intro.water.
- scenes/rampage.gd: input read moved to scenes/run_input.gd RunInput (unchanged logic, for the 400-line cap);
  multi-tick loop (breaks after the first live tick so presses land once), roar (KaijuModel.roar + Sfx.roar) on
  surface_break, intro camera override in _place_camera, legs walk while wading. full_intro var.
- scenes/camera_follow.gd: rest field + hold(eye). scenes/river_view.gd: break splash on emerge.surfaced.
- scenes/main.gd: full_intro when the size tier differs from save "intro_size" (first run, after an evolution).
- tools/capture/capture_river.gd: --short.
- Tests: tests/lib/city_rise_time.gd (city suite _check_rise_fits_intro, stages 1-3 x COVERAGE_SEEDS x base/max
  growth, <= 180 ticks); tests/lib/flow_intro.gd (flow, via flow_staged_start): 3 s / 1.5 s, roar on break,
  no camera pop, real Space press skips, skipped/short/whole same state 45 frames after handover;
  tests/lib/fade_spawn.gd replays the intro camera (load suite).
- Fail-first (IC/ff_rise.log): old 2.5 s rise + 2 s wade -> 181 ticks, 6/6 FAIL; shipped 6/6 PASS.

## Since the first push
- 6befd2c2 tests/lib/flow_intro_main.gd: Main's whole/short rule through a real save and clicks (fail-first:
  always-whole fails). No-pop fail-first: max_seconds 2.0 -> 0.81 of offset, FAIL.
- 43a8f166/a0022b79: first 4K still failed my 2x look (camera inside the channel under the deck, head cut,
  HUD on). Now: eye 8x scale over water at yaw 110, aim tracks the head (aim_head 0.75), HUD hidden in the
  intro, shown on kaiju_emerged. capture_river --still-at takes a list. Stills sheet IC/sheet2.png (43a8f166).
- military "tank falling back 21 of 24" fails on the base too: lead handles it separately.

## Left
- CI runs 39560818384 (stills), 39560822471 (1080p clip), 39560826525 (4K still 1.6 s) -> IC/r3-<run>;
  review at 2x, report paths to the lead. Local load+flow on a0022b79 (IC/suites6.log).
## Open decisions
- none yet (yaw side, distances are data; lead judges the clip).
## Findings for the lead
- none yet
## Rules learnt the hard way
- A Node method named _input clashes with a var _input (parse error hides behind "could not parse Rampage").
