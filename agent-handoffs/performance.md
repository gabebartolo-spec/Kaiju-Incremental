# Performance handoff, 2026-10-18 05:25
## State: awaiting lead (PR #32 open, CI pending, Auto-fix on; re-bench after #22/#23 land)

## Who
Performance role (director, 2026-10-18): keeps track of every addition to the game and judges its
frame-rate cost. Reports to the LEAD session ("Game demo planning", local_106fc100...) and the
director. D-032 (looks first) holds: a slow frame is a finding, not a veto; no feel change without
the director.

## Task
Lead brief 04:4x: one PR off look-options: (1) cache VehicleParts, (2) find and pre-warm the
signature's first-use stall, (3) report street life's cause and a proposed cap (no change).
Then re-bench after #22/#23 land (#8 already merged at 47e1b30, included in #32's base).

## Branch and commit
Worktree `../Kaiju-Incremental-wt/perf-hitches`, branch claude/perf-hitches, head c426f39 (rebased onto
47e1b30) + this handoff. PR https://github.com/gabebartolo-spec/Kaiju-Incremental/pull/32 into
claude/look-options. Suites green locally after the rebase (flow 100 -> 102). Remove the worktree when
it merges.

## What #32 does (causes found with headless timers)
- First Atomic Breath (101-170 ms): AbilityFx prewarm drew the scorch decal at 0.5 rad; the breath
  uses cone_half_angle_deg 36 = 0.63 rad; FxDecals caches by angle, so the first breath drew two
  192px textures per pixel in GDScript. Now the prewarm takes the run's angle.
- Tank/heli spawn (34-58 ms): VehicleParts re-read the kvox and refilled the MultiMesh per spawn. Now
  there's a static cache, a per-vehicle material_override (fades stay per vehicle), and one tank and
  one heli built at load.
- Bench (1080p, interleaved, CPU contended): ability -> 19-24 ms, tank 1.5 ms, heli 1.4 ms, GPU unchanged.

## Ledger (4070 SUPER)
| When | Scene / change | Number |
|---|---|---|
| 10-16 | City 1080p / 4K (#9) | GPU 6.5 / 14.2 ms |
| 10-16 | Street life 363 people (#5) | ~1.0 ms avg |
| 10-17 | Voxel skin (#15) | +0.45 ms GPU |
| 10-17 | City growth 720p (#16) | young 3.0 / Colossus 11-12 / Apex 25-27 ms GPU |
| 10-17 | Apex streaming (#20) | load Behemoth 8.0 s, Apex 13 s |
| 10-18 04:30 | Demo baseline 1080p (be78c82) | pre-evolve GPU 6.0 ms, Behemoth 9.6 ms; "4K" 13.3 / 20.1 ms (window clamped to 1977x1080: true 4K unverified) |
| 10-18 05:15 | #32 hitches | see above |
Not yet benched: #8 SFX (merged, CPU audio only), #22 clips (rig 0.375 ms CPU per its body), #23 slice,
#26 zebras (fewer paint instances).

## Remaining costs (for the next tasks; none started)
1. Each breath after the first costs ~13 ms (fx.gd breath + ability_fx _burst build new
   GPUParticles3D + ParticleProcessMaterial per call). Fix shape: pool and restart() emitters.
2. Street life: 2.3 ms (385 people) -> 4.6 ms (956) per frame. Cause: every person is updated and
   redrawn in GDScript every frame, including off-screen ones; each update does 4 Dictionary
   lookups (`Num.f(_cfg[...])`). No feel change: cache the four tuning floats; update people
   beyond ~40 m of the camera every 3rd frame with 3x delta (they are off-screen). Feel change
   (director's call): cap civilians, e.g. civilians_per_lot scaled so a city holds <= 600.
3. sim.step worst 5-10 ms (headless 33-64 ms): sim side, needs kaiju-sim-review; not touched.
4. Post stack (SSAO+SSIL+glow+fog+shadows+MSAA): the 4K lever; a look call.

## Bench recipe (scratch scripts are session-local)
`tools/capture/bench_rampage.gd` plus: `--preset=` (pre = claws 4 hide 3 rage 3 quake 2; behemoth = +
evolve1 1, sig_power 2); city from `CityGrowth.layout(Content.tuning(), Num.i(stats["size"]),
Seeds.make("city", 0))`; print the viewport and stage. Before/after: before = main checkout, after =
worktree, interleaved. override.cfg goes in EACH project dir, written with the Write tool first (the
focus-guard hook blocks any Bash command containing the windowed flag until the file exists). Ask the
lead for the GPU slot; delete override.cfg after; kill by PID only.

## Unfinished changes
None. override.cfg removed from both folders; all bench Godot PIDs exited.

## Attempts
- Bash with a heredoc containing the windowed flag was blocked by the focus guard -> Write tool.
- `tasklist` hung for 120 s -> use PowerShell Get-Process / Get-CimInstance.

## Open decisions
- Lead: next task (breath pooling, street life no-feel-change pass, or re-bench after #22/#23).
- Director (via the lead): civilian cap at big cities (feel change).

## Running jobs
None (CI on #32 is watched by Auto-fix).
