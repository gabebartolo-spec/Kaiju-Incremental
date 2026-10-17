# Performance handoff, 2026-10-18 04:55
## State: awaiting director (ledger written; the demo baseline bench needs the local GPU slot)

## Who
Performance role (director, 2026-10-18): keeps track of every addition to the game and judges its
frame-rate cost. Reads; measures; reports to the director and the lead. Does not cut detail on its
own: D-032 (looks first, tuning later) still holds; a slow frame is a finding, not a veto.

## Tools that exist
- `tools/capture/bench_rampage.gd`: autoplayed rampage, engine GPU/CPU render timers, frames over
  33 ms, worst process+physics, per-system `rampage.cost_usec`, street-life cost. Needs a window.
  Levels are fixed (claws 4, hide 3, rage 3, quake 2, evolve1 1, sig 2); city = seed 0, base
  `city` section. TO VERIFY: whether it builds the grown (per-evolution, D-039) city.
- `tools/capture/capture_growth.gd`: view build time, GPU frame, triangles per city stage.
- `tools/capture/profile_city.gd`: city build cost per phase (headless).
- Godot: C:/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
- GPU: RTX 4070 SUPER (director's PC). CI is lavapipe (software): fine for counts, useless for ms.

## Ledger: measured so far (4070 SUPER unless said)
| When | Change | Number | Source |
|---|---|---|---|
| 10-16 | City RES 4 vs 8 (#9) | 1080p GPU 6.5 vs 6.6 ms; 4K 14.2 vs 14.2 ms, ~61 of N frames >33 ms at 4K | #9 body (contended) |
| 10-16 | Hidden floor slabs lazily shown (#9) | GPU 7.3 -> 5.6 ms | city handoff |
| 10-16 | Street life, 363 people (#5) | ~1.0 ms avg, worst 5-9 ms; one 2 s burst of 17 slow frames | #5 body |
| 10-16 | Fx.sparks per call (#5) | 2-7 ms hitch per call (new GPUParticles node + material) | street-life handoff |
| 10-17 | Voxel skin (#15) | +0.43-0.46 ms GPU over an empty city | #15 body |
| 10-17 | City grows per evolution (#16) | young 3.0 ms / Colossus 11-12 / Apex 25-27 ms (~38 fps) GPU at 720p; tris 9-11M / 31-46M / 76-93M | #16 body |
| 10-17 | Apex streaming (#20) | load young 5.1 s, Behemoth 8.0 s, Colossus 9 s, Apex 13 s | #20 body |
| 10-18 | Croc clips (#22, open) | rig 0.375 ms avg CPU; no in-game GPU run | #22 body |
| -- | Tanks/heli (#17/#18), game flow (#14), croc adult (#19), SFX (#8), demo slice (#23) | NOT benched | -- |

## Demo read (D-050: reptilian, young -> Behemoth)
- Likely fine at 1080p60 on the 4070 SUPER: young 3 ms at 720p; Behemoth sits between young and
  Colossus and was never measured on its own. 4K is the risk (14 ms GPU on the 10-16 city, before
  growth, skin, army and clips).
- Unknown: any PC weaker than the 4070 SUPER; the exported release exe (P6) vs the editor build.
- No bench since #16 has run the full demo stack (voxel skin + croc clips + army + fires + SFX).

## Risks found in code (ranked by likely felt cost)
1. Stutter from per-burst node creation: `fx.gd _burst`, `ability_fx.gd _burst/_emitter`,
   `fx.gd` breath (160 particles) make a new GPUParticles3D + ParticleProcessMaterial per call.
   #5 measured 2-7 ms per call. Fix shape if it shows: pool emitters, `restart()` them.
2. Uncapped short lights: `CityView.flash` (9 call sites) adds an OmniLight3D per muzzle flash /
   explosion / breath with no cap. Army fire at Behemoth = many at once.
3. Fires: cap 30 (`city_view.gd MAX_FIRES`), each an OmniLight + 3 particle systems.
4. Debris: up to 600 RigidBody3D (`MAX_DEBRIS`): physics spikes on big collapses.
5. Street lamps: one OmniLight3D per lamp (`city_decor.gd _lamp`), count grows with the city tier.
6. Post stack on every frame: SSAO + SSIL + glow + fog + sun shadows (160 m) + MSAA 2x
   (`city_view.gd`, `project.godot`). Biggest 4K lever, and a look call (D-032), not mine.
7. Apex (not in demo): 25-27 ms GPU, 13 s load.

## In-flight additions and expected impact
- #22 croc clips: CPU 0.375 ms; GPU unchanged (same skin). Low.
- #8 SFX: audio only; check voice cap on stomps (0.25 s min interval already). Low.
- #23 demo slice: menus/end card. None in play.
- city-calm zebras (54e9f16): fewer paint instances. Tiny win.
- P3 croc baby/adolescent (Tripo): the game draws the baked voxel skin, so cost follows cell count,
  not mesh quads; keep each stage at or under the adult's cells.
- P6 export: measure the exe, not the editor.

## Next (proposed, not started)
1. Demo baseline: bench_rampage reptilian at Behemoth, 1080p and 4K, 30 s x3, off-screen window,
   isolated APPDATA, override.cfg removed after. Needs the GPU slot (lead) and the director's yes.
2. Same bench on each demo PR before merge (A/B vs look-options), recorded here.
3. Verify the bench builds the grown city; if not, add a `--stage=` arg (small PR).

## Task
Keep the ledger above current: every merged or open PR gets a cost line (measured or "not benched").

## Branch and commit
Main checkout, claude/look-options (lead's checkout; this file is the only thing committed here).
No worktree of my own (worktree count is already over the cap of 4).

## Unfinished changes
None.

## Attempts
None yet (survey only: code reading plus PR bodies #5 #9 #15 #16 #20 #22).

## Open decisions
Director: run the demo baseline bench now, or wait until #22/#8/#23 merge (asked 04:55).

## Running jobs
None. No Godot started, no override.cfg written.
