# Post-fx handoff, 2026-10-22 22:15
## State: working (code done; Godot paused by the director until 22:40)
## Task
ROADMAP "Post effects (D-142)": subtle vignette on every preset (red pulse at low health) + split-second
colour fringe on the biggest hits only. Deliverables: code on claude/post-fx, ONE ~6 s 1080p GPU clip, ms/frame on vs off
(high preset). No PR until the lead says the director approved the clip.
## Branch and commit
claude/post-fx (worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/post-fx), from origin/claude/look-options. Not committed yet.
## What is built
- data/tuning.json "post_fx": vignette, low_health, fringe (all numbers; thresholds stomp_min_radius 4.4, collapse_min_length 28,
  hit_hp_fraction 0.12, cooldown_s 4, seconds 0.2).
- scenes/post_fx_state.gd (numbers, no clock), scenes/post_fx.gd (CanvasLayer 0 under the HUD, two ColorRects),
  scenes/vignette.gdshader (alpha only), scenes/fringe.gdshader (screen texture, rect shown only during a burst).
- scenes/rampage.gd: ONE line, `add_child(PostFx.new(self))` (lead's ruling: #149 splits rampage.gd; say so in PR body; file is 401
  until #149 lands). PostFx reads the sim itself: sim.events in _physics_process (fall_land), stomp_ring_at growth + hp in _process.
  AutoWalk change reverted.
- tests/run_postfx_tests.gd (+README row): 8 funcs. Passed 7/7 before the hooks moved into PostFx and the hp-drop/fall check was added; a background run (after_pause.sh) starts at 22:40.
  Mutation proof: cooldown 0 made 2 checks fail (fringe on 28.7% of a minute of giant stomps).
- tools/capture/capture_post_fx.gd (probe + clip), bench_rampage.gd got --nofx and --preset.
## Evidence so far
- Probe (headless, stage 2, run 1, 2400 frames): fringes begin at frames 184, 445, 722.
- Clip plan: --frames=700 --low_at=493, trim with ffmpeg -ss 5.4167 -t 6 (window frames 325..685: one fringe at 2.0 s,
  red pulse from 2.8 s). ffmpeg: C:/Users/DANTE/AppData/Roaming/Python/Python314/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe
## Unfinished
- Rerun postfx suite (and smoke/flow touching rampage; tuning.json changed so lead says full suite before push).
- Render clip (needs override.cfg no_focus off-screen, gitignored; delete after), view crops, bench on/off.
## Open decisions
- Fringe also scaled by camera-motion setting (0 = none). "Railgun" has no code yet: heavy hit = one frame losing >=12% max hp.
## Rules learnt the hard way
- godot_quiet.sh from the brief does not exist at that path; used the brief's console exe + own APPDATA + timeout.
- No ffmpeg on PATH; use the imageio_ffmpeg binary above. gdtoolkit via `python -m gdtoolkit.formatter` / gdlint main.
- Also done for the lead: agent-handoffs/taskforce-plan.md (Taskforce implementation plan, 120 lines). Finding: railgun 8% < fringe bar 12%.
