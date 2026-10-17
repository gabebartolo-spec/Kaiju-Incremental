# Performance handoff, 2026-10-18 04:40
## State: available (demo baseline bench done and reported; GPU slot released to the lead)

## Who
Performance role (director, 2026-10-18): keeps track of every addition to the game and judges its
frame-rate cost. Reads; measures; reports to the director and the lead (LEAD session, "Game demo
planning", local_106fc100...). Does not cut detail on its own: D-032 (looks first, tuning later)
still holds; a slow frame is a finding, not a veto.

## Task
Keep the ledger below current: every merged or open PR gets a cost line (measured or "not benched").
GPU benches only with the lead's slot; one Godot, off-screen override.cfg (write it with the Write
tool in its own step: the focus-guard hook blocks any Bash command containing a windowed flag until
the file exists), isolated APPDATA, PID kill only, delete override.cfg after.

## Demo baseline bench, 2026-10-18 04:28-04:37 (4070 SUPER, game code = 553fdeb = be78c82)
Seed city 0, reptilian, autoplay 30 s, 3 runs (Behemoth) / 2 runs (pre-evolve). Contended CPU: helper
headless tests + Blender -b ran meanwhile, so frame gaps and logic max are pessimistic; GPU timers hold.
| Scene | Res | GPU avg | GPU max | Frames >33 ms | Worst gap | Street life avg |
|---|---|---|---|---|---|---|
| Pre-evolve, tier 1 baby (the demo's real worst play) | 1080p | 6.0-6.1 ms | 12 ms | 14-16 of ~2360 (0.6%) | 53-201 ms | 2.3 ms (385 people) |
| Pre-evolve | "4K" * | 13.3-13.4 | 32 | 30-34 of ~2000 (1.6%) | 66-73 | 2.3 |
| Behemoth, tier 2 adolescent, grown city | 1080p | 9.6-9.7 | 15 | 31-52 of ~1520 (2-3.4%) | 71-345 | 4.5-4.7 (956 people) |
| Behemoth | "4K" * | 20.0-20.2 | 40-43 | 103-115 of ~1290 (8-9%) | 72-78 | 4.5 |
\* Requested 3840x2160 windowed; the viewport reported 1977x1080 (window clamped to the screen), yet
GPU doubled, so the render size is unclear. True 4K NOT verified: next time render via a fixed-size
SubViewport or check the swapchain size.
Repeatable hitches (every run): signature ability first use 126-170 ms; tank spawn 35-45 ms; heli
spawn 30-42 ms. The demo never plays a Behemoth rampage (it ends on the card after evolve1).

## Ledger: earlier numbers (4070 SUPER unless said)
| When | Change | Number | Source |
|---|---|---|---|
| 10-16 | City RES 4 vs 8 (#9) | 1080p GPU 6.5 vs 6.6 ms; 4K 14.2 vs 14.2 | #9 body (contended) |
| 10-16 | Floor slabs lazily shown (#9) | GPU 7.3 -> 5.6 ms | city handoff |
| 10-16 | Street life, 363 people (#5) | ~1.0 ms avg, worst 5-9 ms | #5 body |
| 10-16 | Fx.sparks per call (#5) | 2-7 ms hitch (new GPUParticles node + material) | street-life handoff |
| 10-17 | Voxel skin (#15) | +0.43-0.46 ms GPU over an empty city | #15 body |
| 10-17 | City growth (#16), 720p | young 3.0 / Colossus 11-12 / Apex 25-27 ms GPU | #16 body |
| 10-17 | Apex streaming (#20) | load young 5.1 s, Behemoth 8.0, Colossus 9, Apex 13 | #20 body |
| 10-18 | Croc clips (#22, open) | rig 0.375 ms avg CPU; no in-game GPU run | #22 body |
| 10-18 | Baseline above | includes tanks/heli, voxel skin, croc adult rig, game flow | this file |
Still to land and NOT in the baseline: #22 clips, #8 SFX, #23 demo slice, city-calm zebras (D-054).

## Causes traced in code
1. Tank/heli spawn 30-45 ms: `TankModel._init` / `HelicopterModel._init` -> `VehicleParts` re-reads
   `.parts.json` + `.kvox` and builds each MultiMesh per spawn, no cache. Fix shape: static cache of
   the built meshes per part (no look change).
2. Ability 126-170 ms: roar + `_ability_fx` builds new GPUParticles3D + ParticleProcessMaterial
   (`fx.gd _burst/breath`, `ability_fx.gd _burst/_emitter`); likely first-use shader/pipeline
   compile. To verify: is it first use only? Fix shape: warm the emitters at load, pool them.
3. Street life scales with the city: 2.3 ms (385 people) -> 4.6 ms (956) CPU per frame at Behemoth.
4. Uncapped `CityView.flash` OmniLights (9 call sites); fires cap 30 with a light each; 600
   RigidBody debris; one OmniLight per street lamp.
5. Post stack (SSAO + SSIL + glow + fog + sun shadows 160 m + MSAA 2x): the big lever at high res, a
   look call (D-032), not mine.

## Bench recipe (scratch script is session-local; re-create it)
Copy `tools/capture/bench_rampage.gd`, then: add `--preset=` (pre = claws 4 hide 3 rage 3 quake 2;
behemoth = that + evolve1 1 + sig_power 2); build the city with
`CityGrowth.layout(Content.tuning(), Num.i(stats["size"]), Seeds.make("city", 0))` (the repo script
uses the base city for every tier); print viewport size and stage. Worth a small PR (proposed).

## Branch and commit
Main checkout, claude/look-options (lead's checkout; only this file committed here). No worktree.

## Unfinished changes
None. override.cfg deleted; all 11 Godot PIDs (1088517-1091817) exited on their own.

## Attempts
1st bench Bash call blocked by the focus guard (heredoc text contained the windowed flag) -> fixed by
writing override.cfg and run.sh with the Write tool.

## Open decisions
- Director/lead: fix the spawn and ability hitches now (cache + warm-up, no look change), or after
  the look is locked (D-032)?
- Lead: bench PR (preset + grown city + true 4K) yes/no.

## Running jobs
None.
