# Graphics quality presets (Potato, Low, Medium, High, Max) for Kaiju Incremental, Godot 4.7.2

Researched 2026-10-21 against the Godot "stable" docs (served as 4.7), the 4.5 to 4.7 release pages, the official `godot-demo-projects/3d/graphics_settings` demo (MIT) and community sources. Repo read only, no edits: `project.godot`, `scenes/city_view.gd`, `autoload/settings.gd`, `autoload/player_settings.gd`, `data/tuning.json` (`display`, `crowd`, `street`, `carve_physics`, `fx` sections), plus greps over `scenes/` and `data/`. Builds on `12-lighting.md` (light caps, GI, renderer table) and `10-destruction.md` (MultiMesh and Jolt debris budgets).

**What the repo already has (important):** a graphics setting exists. `data/tuning.json` `display.graphics` holds two levels, `high` (scale 1.0, no FSR, msaa 2 = 4x) and `balanced` (scale 0.75, FSR1, msaa 0). `display.graphics_default` picks `balanced` + 60 fps on screens 2160 px or taller and `high` elsewhere. `PlayerSettings.apply_graphics()` applies only `scaling_3d_scale`, `scaling_3d_mode` and `msaa_3d` to the root viewport, and `Settings._process` re-applies it live whenever the level changes. Frame cap: `fps_caps [60,120,0]`, `fps_default 120`, `menu_fps 60`; `project.godot` sets `vsync_mode=2` (adaptive) and `msaa_3d=2`, and no `rendering_method` (so Forward+). Phase G therefore extends an existing data table from 2 to 5 rows and from 3 to roughly 15 columns; it is not new plumbing.

## Key findings

1. **The renderer cannot change at runtime; every other preset setting can.** `--rendering-method` accepts `forward_plus`, `mobile` or `gl_compatibility` on the command line (https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html). `rendering/renderer/rendering_method` is read at startup, and "any project setting can be overridden by creating a file named override.cfg" (https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/ProjectSettings.xml). So a Potato preset that means "Compatibility" needs a restart, done by writing `override.cfg` or a launch option. Since 4.4, Forward+ falls back to D3D12/Vulkan and then to Compatibility when RenderingDevice is not supported, unless `rendering/rendering_device/fallback_to_opengl3` is off (https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html). The official demo changes shadow atlas size, soft shadow filter, SSAO/SSIL/SDFGI quality, glow, volumetric fog, MSAA, TAA, FXAA/SMAA, scale, LOD and V-Sync all live from GDScript (https://github.com/godotengine/godot-demo-projects/blob/master/3d/graphics_settings/settings.gd). Two project settings are "only read when the project starts": `use_taa` and `mesh_lod/lod_change/threshold_pixels`. Their runtime equivalents are `Viewport.use_taa` and `Viewport.mesh_lod_threshold` (ProjectSettings.xml, same URL).

2. **Render scale is the biggest single lever at 4K, and the director's TV is a 4K fill-rate case.** With `canvas_items` stretch the 3D renders at window size, so native 4K is 8.29 MPix a frame. Scale 0.75 gives 4.67 MPix (56%), 0.67 gives 3.72 MPix (45%) and 0.5 gives 2.07 MPix (25%), because the scale is per axis (https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html). Renderer support (same page): bilinear works everywhere; FSR1 and FSR2.2 are Forward+ only and silently fall back to bilinear elsewhere; FSR2 brings its own TAA and ignores `use_taa`. The docs warn that "on very slow GPUs, the cost of FSR1 may be too expensive". 4.7 adds a nearest-neighbour 3D scaling mode whose cost is "roughly identical to bilinear" (https://godotengine.org/releases/4.7/). MetalFX is macOS/iOS only (https://docs.godotengine.org/en/stable/classes/class_viewport.html). **The current `balanced` row has a defect per the docs:** "FSR1 upscaling works best when coupled with another form of antialiasing. TAA or MSAA should preferably be used", and "the edge upscaling of FSR1 becomes much more convincing once 4x MSAA is enabled" (resolution_scaling page). `balanced` runs FSR1 with MSAA off, which is exactly the case they warn about.

3. **Anti-aliasing: in Compatibility only MSAA and SSAA exist.** The 4.7 AA table (https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html):
   - MSAA: medium cost, all renderers.
   - TAA: medium cost, Forward+ only.
   - FSR2: high cost, Forward+ only.
   - FXAA: very low cost, Forward+/Mobile, **not** Compatibility.
   - SMAA 1x: low cost, Forward+/Mobile, not Compatibility. It was added in 4.5 as "sharper AA than FXAA at the tradeoff of being more resource intensive" (https://godotengine.org/releases/4.5/).
   - Guidance on the same page: MSAA suits art "with a low amount of reflective surfaces (such as a cartoon artstyle)". Flat-coloured voxels with hard edges are that case.
   - MSAA does nothing for alpha-scissor or specular aliasing, and 8x "is usually too demanding".
   - Inference: MSAA 2x/4x is the right AA on High and Max, and SMAA is the cheap Low/Medium option in Forward+. Compatibility (Potato) gets MSAA 2x or nothing.

4. **Shadows: max distance, split count and map size are the levers; the sun is the only shadow caster we have.** From the docs (https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html):
   - The default is PSSM 4 splits, and "an object … large enough to appear in all four splits … results in increased draw calls". A giant kaiju and tall towers are that case, and it costs CPU, not only GPU.
   - "A lower maximum distance will result in better-looking shadows and better performance."
   - "High shadow resolutions result in sharper shadows, but at a significant performance cost."
   - Soft Low is the default filter, and higher filters take more samples. PCSS (`light_angular_distance`) has "a high performance cost, especially for directional lights". `city_view.gd` sets `light_angular_distance = 1.0` on the sun, so PCSS is on today.
   - Spot shadows are "significantly faster" than omni shadows.
   - The demo maps shadow size 512, 1024, 2048, 4096, 8192 and 16384 to bias 0.06 down to 0.005, and positional atlas size 0 to disable omni/spot shadows. Compatibility needs 512 instead of 0 to work around a rendering bug (demo settings.gd).
   - The GPU-optimisation docs: "Post-processing effects and shadows can also be expensive" and "reducing the size of shadowmaps can increase performance" (https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html).

5. **Screen-space effects: SSIL is Forward+ only; SSAO exists in Compatibility since 4.6, simplified; SDFGI stays off.**
   - "Since Godot 4.6, a simplified version of SSAO is available in the Compatibility renderer … only the Radius and Intensity parameters can be adjusted" (https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html). Note that the 4.6 release page itself does not list it (https://godotengine.org/releases/4.6/).
   - SSAO half size is "significantly faster but may miss small details" (environment page).
   - The SSAO/SSIL quality tiers (very low to ultra) are live through `RenderingServer.environment_set_ssao_quality` / `environment_set_ssil_quality` (demo settings.gd).
   - A shipped-style Godot demo author reports SSIL and SSAO "had similar performance costs", and that volumetric fog was too expensive and was replaced by distance fog plus noise planes (https://jedenjenda23.itch.io/outskirts-godot-environment-demo/comments?after=8).
   - SDFGI, volumetric fog, TAA, FSR2 and SSR are unavailable in Compatibility (12-lighting.md; https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html). `city_view.gd` already notes that SDFGI cost "~a tenth of the frame".

6. **Glow and fog are cheap, except bicubic glow on integrated GPUs.** Bicubic glow upscale "has a performance cost on the GPU which can be significant on integrated graphics", and desktop uses bicubic by default (environment page). It is live via `RenderingServer.environment_glow_set_use_bicubic_upscale` (demo). In 4.6 glow blends before tonemapping, with "similar or outright better performance" (https://godotengine.org/releases/4.6/). Compatibility glow is a separate, simplified implementation "optimized to run on low-end devices" (environment page). Depth fog has no documented cost and works in all renderers (12-lighting.md). Keep it on every preset: it carries the skyline read.

7. **Presentation counts are where a voxel rampage's cost actually lives, and every one can be a data knob with no sim effect.** Each item, with what it means for presets:
   - **Particles:** `GPUParticles3D.amount` restarts the system when changed, but `amount_ratio` "does not affect already-emitted particles". That makes amount_ratio the live preset knob for dust, sparks and footstep bursts (https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html).
   - **Visibility ranges:** they work on any GeometryInstance3D, MultiMeshInstance3D included. Fade mode "Disabled" is cheapest, while "Self" forces transparency during the fade (https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html). Use them for crowd and prop draw distance.
   - **Lights:** distance fade "can improve performance significantly in large scenes with dozens of lights" (lights_and_shadows page). Compatibility caps positional lights at 32 a frame and ignores the rest (12-lighting.md finding 1). That makes light-pool size a preset knob, capped at 32 on Potato.
   - **Debris:** a MultiMesh is one draw for millions of instances, while Jolt bodies number in the low thousands (10-destruction.md findings 4 and 5). `carve_physics.live_cap` (2000 Jolt bodies, cosmetic per `scenes/carve_physics.gd` "never writes back") is a CPU knob. `static_cap` (4000) is a GPU/memory knob.
   - **Mesh LOD:** `mesh_lod_threshold` only affects meshes "that have LOD variations generated" (https://docs.godotengine.org/en/stable/classes/class_viewport.html). Inference: the city is runtime-built voxel ArrayMeshes without generated LODs, so this knob does almost nothing here. Leave it at default rather than expose it.

8. **Shipped indie Godot games expose few settings, and community guides fix performance with a handful of them.**
   - Road to Vostok (Godot 4) does not surface Godot's FSR2. A mod adds it with presets Native 100%, Quality 77%, Balanced 67% and Performance 50% (https://modworkshop.net/mod/56902).
   - Players' guides turn off volumetric fog and ambient occlusion and drop shadows to Medium. One test rig reports 42 to 78 fps, a single anecdotal source (https://www.switchbladegaming.com/road-to-vostok/best-pc-settings/).
   - A Destructoid player tune of the same game: render resolution Medium, AO off, detail shadows off, 60 fps cap (https://www.destructoid.com/?p=1202131).
   - Cassette Beasts' listed minimum is "30 FPS @ 1080p on 'Low' quality preset", with 2 GB VRAM and OpenGL 3.3, so it ships a named preset tier on a GL renderer (https://www.pcgamebenchmark.com/cassette-beasts-system-requirements, store copy).
   - The official demo itself ships five presets, Very Low to Ultra, that set every option together (demo settings.gd). The pattern is one preset button that writes a row of individual values.
   - I found no PCGamingWiki pages with settings tables for Dome Keeper, Halls of Torment or Buckshot Roulette.

9. **Auto-detect: Godot gives adapter name, vendor and type but not total VRAM, so a short in-game timing is the reliable part.**
   - `RenderingServer.get_video_adapter_type()` distinguishes integrated, discrete, virtual and CPU GPUs. Its commit says it exists to "automatically adjust graphics settings" and that integrated GPUs are "typically (but not always) slower" (https://git.objectionable.solutions/Sara/behaviour-tree-test/commit/b3174e7af93e9840698bba53a5d866a61c37d2da, a mirror of Godot PR #55790).
   - `get_video_adapter_name()` returns strings like "GeForce GTX 1080/PCIe/SSE2" (https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/RenderingServer.xml).
   - `get_current_rendering_method()` reports `gl_compatibility` after a fallback (same XML). A running game can therefore tell it landed on OpenGL.
   - There is no cross-platform total-VRAM query. `RenderingDevice.MEMORY_TOTAL` is memory *used*, and the common workaround is a GPU-name table (https://forum.godotengine.org/t/get-gpu-vram-amount/128751).
   - Godot's own advice for measuring GPU cost is to examine "changes in the time spent rendering each frame" (gpu_optimization page).
   - Inference: a 3-5 s timed sample of real rampage frames, a step down if over budget, and the result saved is simpler and more honest than a name table.

10. **Shader compilation, not settings, is the hitch players notice first; presets add variants.** The 4.5 shader baker pre-compiles shaders "in the right format used by the driver on the target platform", reporting a "20x decrease in load times" in the TPS demo (https://godotengine.org/releases/4.5/). Road to Vostok guides blame first-encounter shader compiles for stutter (https://games.gg/id/road-to-vostok/guides/panduan-performa-road-to-vostok-pc-atasi-fps-lag-crash/, secondary). Inference: switching shadow filter, SSAO or SSIL tiers mid-rampage can compile new pipelines and hitch. Apply preset changes from the settings screen or pause, which the existing `Settings._process` already does on change, and turn on the shader baker for exports.

## Preset table (proposal for `data/tuning.json` `display.graphics`)

Values are my proposals unless marked. "Live" means it can be applied from GDScript without restart (source: demo settings.gd and the class docs above). F+ = Forward+, GLC = gl_compatibility.

| Setting (key) | Potato | Low | Medium | High | Max | Renderer notes | Live / restart |
|---|---|---|---|---|---|---|---|
| renderer (`renderer`) | gl_compatibility | forward_plus | forward_plus | forward_plus | forward_plus | Fallback can force GLC on any preset | **Restart** (override.cfg / `--rendering-method`) |
| 3D scale (`scale`) | 0.5 | 0.6 | 0.75 | 1.0 at 1080p, 0.85 at 4K | 1.0 | Scale itself works everywhere | Live |
| upscaler (`scaler`) | bilinear | fsr1 | fsr1 | fsr2 at 4K, else off | fsr2 at 1.0 (native AA) or off | FSR1/FSR2 F+ only, falls back to bilinear | Live |
| MSAA 3D (`msaa`, Viewport enum: 1=2x, 2=4x) | 0 | 0 | 1 (2x) | 2 (4x) | 2 (4x) | All renderers; useless with FSR2 | Live |
| screen-space AA (`ssaa`) | none | smaa | none | none | none | FXAA/SMAA F+ only | Live |
| sun shadow on (`sun_shadow`) | on | on | on | on | on | All | Live |
| sun shadow mode (`sun_splits`) | orthogonal | pssm2 | pssm2 | pssm4 | pssm4 + blend | Splits multiply caster draws | Live (light property) |
| shadow max distance (`shadow_distance`, m) | 60 | 90 | 120 | 160 (today) | 200 | All | Live |
| directional shadow size (`shadow_size`) | 1024 | 2048 | 2048 | 4096 (default) | 8192 | All; 8192+ needs VRAM | Live (`directional_shadow_atlas_set_size`) |
| soft shadow filter (`shadow_filter`) | hard | soft_very_low | soft_low (default) | soft_medium | soft_high | GLC filter support thinner (untested) | Live |
| PCSS (`sun_angular`, deg) | 0 | 0 | 0 | 0.5 | 1.0 (today) | F+ directional only | Live |
| positional shadow atlas (`omni_shadow_atlas`) | 512 (GLC bug: never 0) | 0 | 1024 | 2048 | 4096 | We cast no omni shadows today | Live |
| SSAO (`ssao`) | on, simplified | off or very_low half | low | medium | high | GLC: Radius/Intensity only (4.6+) | Live |
| SSIL (`ssil`) | n/a | off | off | low | medium | F+ only | Live |
| SDFGI | off | off | off | off | off | F+ only, rejected in repo | n/a |
| glow (`glow`) | on, bilinear | on, bilinear | on, bicubic | on, bicubic | on, bicubic | GLC separate implementation | Live |
| depth fog | on | on | on | on | on | All | Live |
| volumetric fog | off | off | off | off | off (optional later) | F+ only | Live |
| crease pass (`crease`) | off | off | on | on | on | Repo screen-space pass; GLC untested | Live (node toggle) |
| light pool size (`lights`) | 8 | 12 | 16 | 24 | 32 | GLC hard cap 32/frame | Live (pool re-picks) |
| light distance fade (`light_fade`, m) | 30 | 40 | 60 | 80 | 120 | All | Live |
| fires with real light (`max_fires`) | 10 | 15 | 20 | 30 (today) | 40 | All | Live (new fires) |
| physics debris live cap (`debris_live`, Jolt) | 300 | 600 | 1000 | 2000 (today) | 3000 | CPU cost, cosmetic only | Live (new pieces) |
| static rubble cap (`debris_static`) | 1000 | 2000 | 3000 | 4000 (today) | 6000 | GPU/memory | Live |
| flying debris pool (`debris_pool`, DebrisField) | 150 | 300 | 450 | 600 (today) | 900 | All | Next rampage |
| debris shadows (`debris_shadows`) | off | off | off | on | on | Shadow-pass draws | Live (per instance) |
| particle ratio (`particles`, amount_ratio) | 0.35 | 0.5 | 0.75 | 1.0 | 1.0 | All | Live |
| stadium crowd max (`crowd_max`) | 800 | 1500 | 2500 | 4000 (today) | 4000 | All | Next rampage |
| civilians per lot (`civilians`) | 1 | 2 | 2 | 3 (today) | 4 | All | Next rampage |
| crowd/prop draw distance (`draw_range`, m, visibility_range_end, fade Disabled) | 60 | 90 | 130 | 180 | 0 (unlimited) | All | Live |
| frame cap | 60 | 60 | 60 | 60 at 4K / 120 | player | Already `fps_caps` | Live |
| V-Sync | adaptive (today) | adaptive | adaptive | adaptive | adaptive | `DisplayServer.window_set_vsync_mode` | Live |
| mesh LOD threshold | default | default | default | default | default | Runtime voxel meshes have no LODs (inference) | Live |

Sim rule: every row above is presentation. The repo check: `scenes/street_life.gd`, `scenes/stadium_crowd.gd` and `scenes/traffic.gd` contain no `emit` or `sim.*()` writes, and `carve_physics.gd` says it "never writes back". `police.gd` (cops that fire) was not checked for damage to the kaiju. If police shots are sim-driven, police counts must stay out of presets.

## Sources

- Godot docs, Resolution scaling: https://docs.godotengine.org/en/stable/tutorials/3d/resolution_scaling.html
- Godot docs, 3D antialiasing: https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html
- Godot docs, 3D lights and shadows: https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html
- Godot docs, Environment and post-processing: https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html
- Godot docs, Overview of renderers: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot docs, GPU optimisation: https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html
- Godot docs, Visibility ranges: https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html
- Godot docs, Command line: https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Godot class refs: Viewport https://docs.godotengine.org/en/stable/classes/class_viewport.html ; GPUParticles3D https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html ; ProjectSettings XML https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/ProjectSettings.xml ; RenderingServer XML https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/RenderingServer.xml
- Godot releases: 4.5 https://godotengine.org/releases/4.5/ ; 4.6 https://godotengine.org/releases/4.6/ ; 4.7 https://godotengine.org/releases/4.7/
- Official graphics settings demo (MIT): https://github.com/godotengine/godot-demo-projects/blob/master/3d/graphics_settings/settings.gd
- get_video_adapter_type commit (mirror of PR #55790): https://git.objectionable.solutions/Sara/behaviour-tree-test/commit/b3174e7af93e9840698bba53a5d866a61c37d2da
- Godot forum, total VRAM: https://forum.godotengine.org/t/get-gpu-vram-amount/128751 ; GPU query proposal https://github.com/godotengine/godot-proposals/issues/6820
- Outskirts demo dev comments: https://jedenjenda23.itch.io/outskirts-godot-environment-demo/comments?after=8
- Road to Vostok: FSR Enabler mod https://modworkshop.net/mod/56902 ; Switchblade guide https://www.switchbladegaming.com/road-to-vostok/best-pc-settings/ ; Destructoid https://www.destructoid.com/?p=1202131 ; games.gg guide https://games.gg/id/road-to-vostok/guides/panduan-performa-road-to-vostok-pc-atasi-fps-lag-crash/
- Cassette Beasts requirements: https://www.pcgamebenchmark.com/cassette-beasts-system-requirements
- Sibling notes: 12-lighting.md, 10-destruction.md (same folder)

## For Kaiju Incremental

Ranked, simplest viable first. Every item only changes presentation; none touches `sim/`.

1. **Grow the existing `display.graphics` table to five rows (potato, low, medium, high, max) and fix `balanced`'s FSR-without-AA.** *Cost:* data edit plus a schema update, under an hour. Keep the current applier (`PlayerSettings.apply_graphics`), which already re-applies live on change. Map old saved keys: `high` to high, `balanced` to medium. Set Medium to scale 0.75 + FSR1 + MSAA 2x, which the docs say makes FSR1 edges "much more convincing". Point the 4K default (`graphics_default.large`) at High (0.85 + FSR2) or Medium, chosen by the timing in item 5.
2. **Add the environment and shadow columns to the applier: sun splits, max distance, shadow size, filter, PCSS, SSAO, SSIL and glow bicubic.** *Cost:* about 40 lines in one function, half a day plus captures. All are live (demo). `city_view.gd` must read them from the preset instead of its hard-coded `directional_shadow_max_distance = 160`, `light_angular_distance = 1.0`, `ssao_enabled`/`ssil_enabled = true`. On Medium and below, drop PCSS (`light_angular_distance` 0) first: the docs call it "a high performance cost, especially for directional lights". Measure SSIL second: in Forward+ it is the likeliest post-process cost per visual gain (estimate, unmeasured).
3. **Move the presentation caps out of code into the preset row: `MAX_DEBRIS` 600, `MAX_FIRES` 30 (city_view.gd), `carve_physics.live_cap`/`static_cap`, crowd `max`, `street.civilians_per_lot`, and a particle `amount_ratio`.** *Cost:* one day; it also clears magic numbers that hard rule 4 already rejects. Debris live cap is the CPU lever (Jolt). Crowd and civilian counts are the draw-count lever. Apply count changes at the next rampage start, so nothing pops mid-run.
4. **Ship the light pool (12-lighting.md rec 2) with its size taken from the preset: 8/12/16/24/32, plus distance fade on lamp, fire and beacon lights.** *Cost:* the pool is half a day already planned. The preset column is one key. 32 is Compatibility's hard per-frame cap, so Potato must never exceed it.
5. **Auto-detect the default: no saved choice yields a renderer and adapter check, then a 4 s timed sample.** *Cost:* about half a day.
   - **Step 1:** if `get_current_rendering_method() == "gl_compatibility"` (fallback hit), use Potato. Else if `get_video_adapter_type()` is integrated or CPU, use Low. Else use High at 1080p or the 4K row on a large screen (existing `min_height` rule).
   - **Step 2:** during the first rampage's opening seconds, measure frame time through `viewport_get_measured_render_time_gpu`, or Engine fps if that proves noisy. If the 90th percentile is over the frame budget (16.7 ms at 60), step down one preset and save it. Never step up automatically.
   - Say it once in the settings screen ("chosen for your PC").
   - No VRAM table (Godot has no total-VRAM query) and no Steam-survey tiers: the measured sample replaces both.
6. **Potato = Compatibility, behind a restart.** *Cost:* one to two days with a full Compatibility capture pass.
   - Write `override.cfg` with `rendering/renderer/rendering_method="gl_compatibility"` and show "restart to apply".
   - Compatibility loses FXAA/SMAA/TAA/FSR/SSIL/volumetric fog, its shadowed lights blend in sRGB, and the demo halves light energy to compensate (12-lighting.md; demo).
   - Do it last: the fallback already covers machines without Vulkan/D3D12, and Low in Forward+ at scale 0.6 may be enough for most integrated GPUs.
7. **Enable the 4.5 shader baker for exports, and apply preset changes only from menus or pause.** *Cost:* an export-preset tick plus a check that the applier never runs mid-rampage. This removes the hitch players blame on settings.

**Evidence gaps:**
- I found no published per-setting millisecond costs for Godot 4.7 at 4K (SSIL, SSAO, PSSM splits, PCSS); the table's ordering is inferred from the docs' qualitative wording and must be measured on the director's GPU with the monitor's GPU time.
- Whether `override.cfg` is read beside an exported Windows .exe (and whether that folder is writable under Program Files or Steam) is not verified. The ProjectSettings text says "project's root directory".
- Compatibility's soft-shadow filter support was not verified.
- I found no PCGamingWiki settings tables for Dome Keeper, Halls of Torment or Buckshot Roulette, and no Steam Hardware Survey tier data was fetched.
- `police.gd` was not checked for sim coupling.
- The current `balanced` preset's look at 4K was judged from the docs, not from a capture.
