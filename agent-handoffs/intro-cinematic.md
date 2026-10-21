# intro-cinematic handoff, 2026-10-21
## State: fixes pushed, lead to judge the CI still and clip
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

## Latest (6ca955ed)
- Shot pivots on the head (yaw 90: eye due west along the river, 4x scale over water); breath-aim cone hidden in
  the intro; camera first placed after the HUD exists. Probe: stage 1 sight line eye->head clear of decks;
  stage 2 head sits at the deck's edge (z 50), so the fount there is partly hidden.
- Local: load, flow, city, smoke all pass on 6ca955ed (IC/suites8.log).
- CI: stills 39564287560 (IC/sheet4.png), 1080p clip 39564292772 (IC/r4-39564292772/*/clip.mp4, emerged
  frame 168 = 2.80 s), 4K still 39564296988 (IC/r4-39564296988/*/river_s1_1.60s.png, crop IC/crop4k_head.png).
- Known look issues for the lead: sand shore slab large in the left foreground; a channel-end block hides the
  body below the head at 1.6 s; jaw reads closed in the 1.6 s still; spray cubes are flat unshaded squares.

## Done since (intro-fix builder, 2026-10-21; commits df009a9f + the eye-farther one)
1. Foreground: tests/lib/river_sight.gd (quay walls, decks+parapets, shore as solids) used by fade_spawn: head,
   neck, shoulders in sight on every frame 1.45-1.6 s. Fail-first on old framing (height 4): stage 1 22/27, FAIL.
   Fix is data: tuning intro distance 28, height 16 (was 20/4). CI still 39581561041 (distance 20, height 12)
   still showed the sand slab big at left and a wall hiding the lower body; farther/higher run 39584674092 (still),
   39584753285 (clip) to judge.
2. Jaw: KaijuModel.roar(open_seconds) -> BipedHead.hold_open; tuning intro roar_jaw_seconds 1.3. Open in the still.
3. Spray: lit material, tones from tuning intro.water.colors (3), drop_min 0.35 for small cubes.
Local: full suite: only growth ("lots of young city at Apex, 16 moved") and military (tank fall-back, known on base)
failed; growth not yet checked on the base.
## Open decisions
- none yet (yaw side, distances are data; lead judges the clip).
## Findings for the lead
- none yet
## Rules learnt the hard way
- A Node method named _input clashes with a var _input (parse error hides behind "could not parse Rampage").
