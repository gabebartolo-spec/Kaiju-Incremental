# Performance handoff, 2026-10-18 05:45
## State: available (PR #32 merged cfb063f; director said "finish up"; next items queued below)

## Who
Performance role (director, 2026-10-18): keeps track of every addition to the game and judges its
frame-rate cost. Reports to the LEAD session ("Game demo planning", local_106fc100...) and the
director. D-032 (looks first) holds: a slow frame is a finding, not a veto; no feel change without
the director.

## Task (next, assigned by the lead 05:3x; none started)
One PR each, same before/after bench discipline:
(a) Breath particle pooling: each later breath costs ~13 ms (fx.gd breath + ability_fx _burst build a
    new GPUParticles3D + ParticleProcessMaterial per call). Pool and restart() the emitters.
(b) Street life, no feel change: cache the four tuning floats (`Num.f(_cfg[...])` per person per
    frame) and update people beyond ~40 m of the camera every 3rd frame with 3x delta. Proof = 1080p
    game-camera still before/after with a diff of ~0. Cost now 2.3 ms (385 people) -> 4.6 ms (956).
    The 600-civilian cap is the director's call; the lead asks him once (b) lands.
(c) sim.step profile at Behemoth (which steps cost what) written here. No sim change without a
    kaiju-sim-review packet. Worst sim.step: 5-10 ms windowed, 33-64 ms headless.
Then re-bench after #22 lands (#8, #23 and #26 are merged).

## Branch and commit
#32 merged into claude/look-options as cfb063f (squash of head 6525a75). Worktree removed.
Branch claude/perf-hitches may still exist locally/on origin (my `git branch -D` was refused by
permissions): the lead can prune it.

## What #32 did
- First Atomic Breath 101-159 -> 19-24 ms: the prewarm drew the scorch decal at 0.5 rad, the breath
  uses cone_half_angle_deg 36 = 0.63 rad, and FxDecals caches by angle. Now
  `AbilityFx.new(..., cone)` prewarms at the run's angle (`AbilityFx.cone_half_angle`).
- Tank/heli spawn 34-58 -> 1.5 ms: VehicleParts static caches (kvox per path, MultiMesh per part) plus a
  per-vehicle material_override, so fades stay per vehicle; one of each built at rampage load.
- Flow floor 100 -> 102 (2 checks, shown failing on the old code). GPU unchanged.
- CI lessons: gdlint max-file-lines 400 (rampage.gd sits at 397); gdformat --check runs in gdlint
  (local: ~/AppData/Roaming/Python/Python314/Scripts/gdformat.exe and gdlint.exe).

## Ledger (4070 SUPER)
| When | Scene / change | Number |
|---|---|---|
| 10-16 | City 1080p / 4K (#9) | GPU 6.5 / 14.2 ms |
| 10-16 | Street life 363 people (#5) | ~1.0 ms avg |
| 10-17 | Voxel skin (#15) | +0.45 ms GPU |
| 10-17 | City growth 720p (#16) | young 3.0 / Colossus 11-12 / Apex 25-27 ms GPU |
| 10-17 | Apex streaming (#20) | load Behemoth 8.0 s, Apex 13 s |
| 10-18 04:30 | Demo baseline 1080p (be78c82) | pre-evolve GPU 6.0 ms, Behemoth 9.6 ms; "4K" 13.3 / 20.1 ms (window clamped to 1977x1080: true 4K unverified) |
| 10-18 05:15 | #32 hitches (before 40a2ec2 / after 7f63d01) | ability 101-159 -> 19-24 ms, tank 34-41 -> 1.5, heli 56-58 -> 1.4 |
Not yet benched: #8 SFX, #22 clips (rig 0.375 ms CPU per its body), #23 slice, #26 zebras.
Also open: the post stack (SSAO+SSIL+glow+fog+shadows+MSAA) is the 4K lever, and a look call.

## Bench recipe (scratch scripts are session-local)
`tools/capture/bench_rampage.gd` plus: `--preset=` (pre = claws 4 hide 3 rage 3 quake 2; behemoth = +
evolve1 1, sig_power 2); city from `CityGrowth.layout(Content.tuning(), Num.i(stats["size"]),
Seeds.make("city", 0))`; print the viewport and stage. Before = main checkout, after = worktree,
interleaved. override.cfg goes in EACH project dir, written with the Write tool first (the focus-guard
hook blocks any Bash command containing the windowed flag until it exists). Ask the lead for the GPU
slot; delete override.cfg after; kill by PID only. Headless runs give CPU handler costs (cost_usec)
without the GPU slot.

## Unfinished changes
None. No override.cfg, no Godot of mine running.

## Attempts
- The focus guard blocked a heredoc containing the windowed flag -> use the Write tool.
- `tasklist` hung for 120 s -> use PowerShell Get-Process / Get-CimInstance.
- CI failed twice on lint (file length, gdformat) -> run gdlint + gdformat --check locally before pushing.

## Open decisions
- Director (via the lead): civilian cap at big cities (feel change), after (b).

## Running jobs
None.
