# Post-fx handoff, 2026-10-22 22:55
## State: awaiting director (clip sent to the lead); no PR until the lead says the director approved
## Task
ROADMAP "Post effects (D-142)": subtle vignette on every preset (red pulse at low health) + split-second colour fringe on the
biggest hits only. Deliverables: code, ONE ~6 s 1080p GPU clip, cost on vs off (high preset).
## Branch and commit
claude/post-fx (worktree C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/post-fx), from origin/claude/look-options (7 commits behind:
sync by merge before the PR). Local commits only, nothing pushed. Open PR as ready only after the lead says the director approved.
## What is built
- data/tuning.json "post_fx" (all numbers): vignette strength 0.42; low_health below 35% red pulse 1.3 Hz; fringe peak 6 px at 1080,
  0.2 s, cooldown 4 s, bars: stomp radius >= 4.4, topple >= 28 units, one frame losing >= 12% max hp.
- scenes/post_fx_state.gd (numbers), post_fx.gd (CanvasLayer 0 under the HUD, two ColorRects), vignette.gdshader (alpha only),
  fringe.gdshader (screen texture; its rect is visible only during a burst).
- scenes/rampage.gd: ONE added line `add_child(PostFx.new(self))` (file is 401 lines vs the 400 gdlint cap until #149 splits it; say so in PR body).
  PostFx reads sim.events, stomp_ring_at growth and hp itself. Fringe also scaled by the camera-motion setting.
- tests/run_postfx_tests.gd (+README row), tools/capture/capture_post_fx.gd (--probe, clip, --cost), bench_rampage.gd (--nofx, --preset).
## Evidence
- Suites (quick, own APPDATA): postfx 8/8 functions 22 checks, camera 9, smoke 30, flow 206: all pass. Mutation: cooldown 0 -> 2 checks fail
  (fringe on 28.7% of a minute of giant stomps). NOT run: full suite (tuning.json changed: run it before the push), CI.
- Clip: C:/Users/DANTE/AppData/Local/Temp/pfx/out/post_fx_clip.mp4 (6 s, 1920x1080, 60 fps, RTX 4070 SUPER Vulkan, seed: reptilian size-3 body,
  city seed 0, run 1 night, frames 325..685 of an autoplay). 0-2.0 s normal vignette; fringe 2.0-2.2 s on a stomp; red pulse from 2.8 s
  (kaiju health HELD at 8% by the capture script, the one thing set by hand).
- Looked at: full frames at 1 s, 2.07 s, 4.5 s and 2x edge crops. 14 px fringe was too heavy on bright windows -> 6 px. At 6 px the kaiju
  (centre) and the HUD stay sharp, the red edge reads, the calm vignette is subtle (hard to see against a night scene).
- Cost (paused frame, 1080p high, 3 alternating rounds x 120 frames): gpu off 23.97 ms, vignette 23.87, mid-fringe 22.86; cpu 3.70/3.58/3.46:
  all inside the +-1 ms noise, no cost measurable. (bench_rampage on/off was unusable: 7-9 fps and different run each time.)
## Not exercised
Other graphics presets and 4K; day scenes (vignette only seen at night); stages other than the third body; the hurt trigger in play
(tested on the state only); a real stomp+collapse together; gl_compatibility.
## Open decisions
- Railgun (8%, D-143) is below the 12% bar: Taskforce PR 1 should raise a railgun_hit event that fires the fringe.
- agent-handoffs/taskforce-plan.md (untracked, lead's request) lives only in this worktree: copy it before the worktree is removed.
## Rules learnt the hard way
- godot_quiet.sh from the brief does not exist; used the console exe + own APPDATA + timeout. override.cfg removed after the renders.
- Python text-mode writes make CRLF on Windows: use newline='' and check `file`; a silent no-op replace cost three reruns.
- ffmpeg: C:/Users/DANTE/AppData/Roaming/Python/Python314/site-packages/imageio_ffmpeg/binaries/ffmpeg-win-x86_64-v7.1.exe
- Stop only PIDs you started and logged; a pause order lets runs already going finish (lead 2026-10-22, after I stopped a PID that was probably another agent's).
