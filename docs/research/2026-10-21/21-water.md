# Stylised interactive water that reads with voxels and reacts to the kaiju (playtest comment #12)

Researched 2026-10-21. Repo read only, no edits. Files read: `sim/city_river.gd` (in full), `sim/emergence.gd` (in full, the #113 rise), `scenes/river_view.gd` (in full), the river and water parts of `scenes/city_ground.gd` (`_river`, `_water`, `_sheet`), `scenes/fx.gd` (`shockwave`, `_burst`), the head of `scenes/carve_debris.gd`, the event emitters in `sim/` (`stomp`, `tail_sweep`, `fall_land`, `throw_land`, `limb`, `chunks_broken`), and the `KaijuRig.foot_planted` emitters in `scenes/gait_*.gd`. Builds on `10-destruction.md` (debris is presentation, Jolt only decorates), `12-lighting.md` (renderer limits) and `18-graphics-presets.md` (preset table).

**What the repo has today.** The river is one `PlaneMesh` per channel (`CityGround._sheet`): a `StandardMaterial3D` with albedo `river` `#2a5a6c`, roughness 0.12 and metallic_specular 0.8. It sits at y = -`river_depth` (1.6), between stone quay slabs. There are no subdivisions, no shader and no motion. The bay is a second flat sheet at y = -0.8. The only water reaction is `RiverView`: three `Fx.shockwave` rings during the rise (open, break the surface at 45% risen, step out). The sim already emits everything water needs: `stomp` {radius, lift}, `tail_sweep` {side, reach}, `fall_land` {id, kind, building, scrap}, `throw_land` {at, radius} and `limb` {at}, plus `kaiju_pos`, `facing`, `stand_y` and `emerge.risen()`. Presentation emits `KaijuRig.foot_planted(side, strength, pos)` for every footfall and tail slam. `Fx._burst` already makes one-shot `GPUParticles3D`.

## Key findings

1. **Depth-based foam works in gl_compatibility, but the depth-to-NDC maths differs and must be branched.** Godot's advanced post-processing page gives the Forward+ form `vec3(SCREEN_UV * 2.0 - 1.0, depth)` and says Compatibility needs `vec3(SCREEN_UV, depth) * 2.0 - 1.0`, switched with `#if CURRENT_RENDERER == RENDERER_COMPATIBILITY` (https://docs.godotengine.org/en/latest/tutorials/shaders/advanced_postprocessing.html). The screen copy is taken "after the opaque geometry pass, but before the transparent geometry pass", and materials that read `hint_screen_texture` "are considered transparent themselves" (https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html). What Compatibility lacks for water: compute shaders, the normal/roughness buffer, SSR, decals and particle SDF collision. Forward+ has all of them (https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html). Inference: depth foam and a depth tint (shallow-to-deep) are available in both renderers, while SSR reflections, decal foam and compute are Forward+ only.

2. **A uniform-array ripple field is cheap, and the hard limit is large: 65,536 bytes (4,096 vec4) on desktop.** Godot's shading-language page: "On most desktop platforms, this limit is 65536 bytes, or 4096 vec4 uniforms. On mobile platforms … 16384 bytes, or 1024 vec4". vec2/vec3 pad to vec4, arrays count their full size, and a texture is the escape hatch past the limit (https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html). A Godot 4 forum write-up (Feb 2026, weak source) used a ring buffer of 8 ripple origins and ages, flushed every frame, with each ring as `sin((dist - age*speed)*freq)` times a double-exponential envelope. Its pitfalls: arrays must be padded to the declared size, a drifting `ripple_count` fires "phantom waves from origin", and vertex displacement "gets noticeably faceted on anything less than a fairly dense mesh" (https://moonjump.com/forum/game-dev/wrote-a-godot-4-interactive-water-ripple-system-world-space-contact-points-to-shader-array-surprisingly-clean-582a92). Inference: 64 impulses at 2 vec4 each is 2 KB, about 3% of the desktop cap. The cost is ALU per vertex times N, not memory.

3. **Shipped games make interaction from a few dozen cheap "splash" stamps, not a fluid sim.** Teardown, the closest voxel reference, draws water as quads "at the very end of the G-buffer pass", with a static foam layer plus "up to 64 smaller, distorted foam 'splashes' that appear in the wake of boats or when an entity intersects with the water". Its ripples come from normal offsets and it uses one foam texture (third-party frame breakdown: https://juandiegomontoya.github.io/teardown_breakdown.html). Sea of Thieves (SIGGRAPH 2018) adds foam "around objects that intersect the water surface within a camera centered window using depth buffer comparisons" and blurs that foam buffer "with feedback to simulate the foam dispersing". Only shallow features such as water on deck use a GPU water simulation, based on Mei et al. 2007 (https://dl.acm.org/doi/pdf/10.1145/3214745.3214820). Inference: a capped impulse list (Teardown's 64) plus intersection foam is the proven shape, and a real heightfield sim is reserved for small local areas.

4. **Wind Waker's look comes from flat colour layers over sine-displaced geometry, and the texture moves while the mesh stays still.** Nathan Gordon's analysis builds the swell from "compound sine curves" displacing y. Foam is a tiled mask that adds white, then the mask is repeated in dark blue "offset … slightly, so that the white and blue lines didn't fall on top of each other". "The ocean geometry doesn't shift with the boat's movement, instead the texture and swell shifts across the plane" (https://medium.com/@gordonnl/the-ocean-170fdfd659f1). A 2026 Godot recreation of Wind Waker's still-boat ripples uses only shaders, animating rings out from the hull's shape (https://www.reddit.com/r/godot/comments/1u3czxe/recreating_wind_waker_water_ripples_with_only/, thread title and snippet only). Inference: two or three flat tones with hard-edged crest lines is the stylisation that sits next to flat-coloured voxels. Smooth PBR gloss, like today's roughness-0.12 sheet, is the clash.

5. **The faceted and stepped read is a known shader trick with CC0 examples.** godotshaders' "Low poly water" builds face normals from `cross(dFdx(VERTEX), dFdy(VERTEX))`, so every triangle shades flat. The page says it is "under CC0 license" (https://godotshaders.com/shader/low-poly-water/). The Godot Asset Store's "Pixel Water" is "water in three flat shades with thin crest lines", licensed **CC0** (https://store.godotengine.org/asset/fcidade/pixel-water-godot-shader/). A Godot proposal thread confirms flat shading can be emulated in a shader on smooth meshes (https://github.com/godotengine/godot-proposals/discussions/5211). Inference, for the voxel read specifically: quantise the displacement in xz by sampling the ripple at each cell's centre, so the surface becomes flat-topped tiles, and in y by snapping to a step. That turns rings into stepped terraces of water "voxels", the way CityV stair-steps its debris.

6. **The Kelvin wake is a fixed V of ±19.47°, independent of speed, so it is a cheap, readable shape.** Each wake arm sits at about arcsin(1/3) = 19.47° from the path, with feathery wavelets at about 53° inside it (https://en.wikipedia.org/wiki/Kelvin_wake_pattern). Physics World: "the angle … is 19.47°, irrespective of how fast the boat is travelling", though fast hulls narrow it (https://physicsworld.com/a/physicists-rethink-celebrated-kelvin-wake-pattern-for-ships/; Darmon et al. 2014, https://elieraphael.github.io/Publications/Kelvin_wake_pattern.pdf). Inference: a wading kaiju gets its wake from one analytic term. In the kaiju's frame (along a, across c, behind it), draw foam where |c| ≈ a·tan(19.47°) = 0.354·a, fading with a and scaled by wade speed. This costs one transform and a smoothstep, with no history buffer. Expanding rings dropped along the path do not form a V at wading speeds, because the source is slower than the rings (my reasoning, not sourced).

7. **GPU particles work in Compatibility, minus `emit_particle()` and SDF collision.** The GPUParticles3D page says `emit_particle()` "is only supported on the Forward+ and Mobile rendering methods, not Compatibility" (https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html). SDF collision is not supported in Compatibility (renderers page above). `amount_ratio` is the live preset knob (18-graphics-presets.md finding 7). A 2024 issue shows Compatibility can outperform Forward+ on heavy overlapping particle planes, which are fill-rate bound (https://github.com/godotengine/godot/issues/97903). Inference: one-shot emitters, which `Fx._burst` already makes, are the portable pattern. Fill rate from big translucent spray quads at 4K is the real cost, so voxel-cube droplets (opaque, small) cost less than soft sprite sheets and read as voxels.

8. **Render-target heightfield sims exist in Godot, but they are the heavy route.** Godot community ports run a ripple wave equation in a shader with feedback, and one author warns to set Max FPS to 60 because "unlocked FPS caused" problems: the sim steps per rendered frame (https://www.youtube.com/watch?v=VSwVwIYEypY). A 2026 Godot dev rebuilt theirs on compute plus a compositor effect, with a SubViewport reading colliders (https://www.reddit.com/r/godot/comments/1quq9t5/remade_my_entire_water_ripples_simulation_using/). Compositor effects and compute are Forward+ only (renderers page). Inference: a SubViewport ping-pong works in both renderers. It needs two alternating viewports, a fixed sim step decoupled from frame rate, and a world-to-texture mapping over the channel. Its state also depends on frame history, so a replay matches only if it is fed identically each fixed step. That is acceptable for presentation, but not "free".

9. **Refraction and screen-texture reads are a 4K fill-rate cost that a stylised river does not need.** A screen-texture read forces the material into the transparent pass and a full-screen copy (screen-reading page above). The current river is an opaque teal sheet in a 1.6 m-deep stone channel, with nothing under it to refract. Inference (estimate, unmeasured): a depth read for foam is worth it, while refraction is not. On Potato and Low, even the depth read can go, using analytic foam (recommendation 2).

## Route comparison

Costs are my estimates unless sourced; none were measured on the director's PC. The river is one long east-west channel, about one block deep (`CityRiver.channels`).

| Route | What it gives | Forward+ cost (4K) | gl_compatibility support / cost | Determinism notes | Preset fallback |
|---|---|---|---|---|---|
| **(a) Vertex ripple field from a uniform ring buffer** (`vec4 imp[64]` = x, z, t0, strength; `vec4 kind[64]` = radius, type, dir) | Rings from stomps, footfalls, tail slams, debris and throw impacts; the rise bulge; stepped terraces if quantised | Very low. A 0.5 m grid over the channel is tens of thousands of vertices × 64 sines, much less than 1 ms (estimate). Flat normals from derivatives are free. | Full support. The uniform cap is 4,096 vec4 desktop / 1,024 mobile (shading-language page); 128 vec4 is far below either. | Best. Impulses come from sim events and `foot_planted`, timed on the sim clock, not `TIME`. Same inputs give the same water. | Potato: 16 impulses, coarser grid (1 m), no y-quantise. Max: 64 impulses. |
| (a+) **Analytic Kelvin wake term** (kaiju pos, facing, wade speed as uniforms) | The V wake and bow foam while wading in the rise | Negligible | Full | Pure function of sim state | Every preset (cheapest strong read) |
| **Depth-based intersection foam** (`hint_depth_texture`) | Foam lines at quay walls, legs, tail, body and floating rubble | Low: one depth sample per water pixel, plus the transparent pass | Supported, with the NDC branch (finding 1); extra depth copy | Presentation only; follows whatever is drawn | Potato/Low: swap for analytic foam (distance to channel rect edges plus impulse radii) |
| **(b) SubViewport ping-pong heightfield** (256² to 512² over the channel) | True interference, wakes that persist, reflections off quay walls | Low to moderate: two small extra passes a frame (estimate) | Works (SubViewport plus canvas shader), but no compute and no compositor | Frame-history dependent; needs a fixed step and fixed inputs. Not replay-exact with variable frame time. | Off below High; route (a) remains |
| (b') **Compute heightfield** (RenderingDevice) | Same, faster, larger grids | Low | **Not supported** (renderers page) | As (b) | Needs (a) as the Compatibility path anyway, so double work |
| **(c) GPUParticles3D splashes** (cube droplets, crown, spray sheets) | Splash crowns on stomps and debris entry, sheets falling off the body during the rise | Fill-rate bound; opaque cubes are cheap, big translucent sheets are not | Supported; no `emit_particle()`, no SDF collision | Seed the FX's own RNG; never the sim RNG | `amount_ratio` 0.35 (Potato) to 1.0 (High), as in 18-graphics-presets.md |
| **Flow scroll** (UV scroll along the channel axis) | The river reads as moving, not a pond | Negligible | Full | Sim-clock time | Every preset |
| **Screen-space refraction / SSR** | Glassy realism | Full-screen copy plus SSR cost | No SSR; screen texture OK | n/a | Do not use: it clashes with the voxel look |

## Sources

- Godot docs, Advanced post-processing (depth NDC, Compatibility branch): https://docs.godotengine.org/en/latest/tutorials/shaders/advanced_postprocessing.html
- Godot docs, Screen-reading shaders: https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html
- Godot docs, Overview of renderers (feature tables): https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot docs, Shading language (uniform limits): https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/shading_language.html
- Godot docs, GPUParticles3D: https://docs.godotengine.org/en/stable/classes/class_gpuparticles3d.html
- Godot issue #97903 (Compatibility vs Forward+ particles, fill rate): https://github.com/godotengine/godot/issues/97903
- Godot proposals #5211 (flat shading in shader): https://github.com/godotengine/godot-proposals/discussions/5211
- godotshaders, Low poly water (CC0 per page): https://godotshaders.com/shader/low-poly-water/
- Godot Asset Store, Pixel Water (CC0): https://store.godotengine.org/asset/fcidade/pixel-water-godot-shader/
- Moonjump forum, Godot 4 ripple array (licence not stated; reference only, copy no code): https://moonjump.com/forum/game-dev/wrote-a-godot-4-interactive-water-ripple-system-world-space-contact-points-to-shader-array-surprisingly-clean-582a92
- Teardown frame breakdown (third party): https://juandiegomontoya.github.io/teardown_breakdown.html
- The Technical Art of Sea of Thieves, SIGGRAPH 2018 talk abstract: https://dl.acm.org/doi/pdf/10.1145/3214745.3214820
- Nathan Gordon, Wind Waker Graphics Analysis, The Ocean: https://medium.com/@gordonnl/the-ocean-170fdfd659f1
- Reddit r/godot, Wind Waker ripples with shaders (snippet only): https://www.reddit.com/r/godot/comments/1u3czxe/recreating_wind_waker_water_ripples_with_only/
- Wikipedia, Kelvin wake pattern: https://en.wikipedia.org/wiki/Kelvin_wake_pattern
- Physics World, Kelvin wake rethink: https://physicsworld.com/a/physicists-rethink-celebrated-kelvin-wake-pattern-for-ships/
- Darmon, Benzaquen, Raphaël 2014, Kelvin wake at large Froude numbers: https://elieraphael.github.io/Publications/Kelvin_wake_pattern.pdf
- YouTube, Water simulation in Godot 4 (frame-rate caveat): https://www.youtube.com/watch?v=VSwVwIYEypY
- Reddit r/godot, ripples rebuilt on compute (2026): https://www.reddit.com/r/godot/comments/1quq9t5/remade_my_entire_water_ripples_simulation_using/
- Sibling notes: 10-destruction.md, 12-lighting.md, 18-graphics-presets.md (same folder)

## For Kaiju Incremental

Ranked, simplest viable first. Every item is presentation only. Water reads sim state and events; nothing reads water. No new sim field or event is needed. FX randomness gets its own `RandomNumberGenerator` seeded from the map seed plus a constant, the way `CityRiver.sheds` seeds with `map_seed + 3`, and never the sim RNG.

1. **Replace the river `_sheet` with one `river.gdshader` on a subdivided plane: a ripple ring buffer plus a stepped, flat-shaded toon look (route a).** *Cost: about 1 to 1.5 days for one builder, plus a capture pass in both renderers.*
   - **Mesh.** `PlaneMesh.subdivide_width/depth` at about 0.5 m spacing over each `CityRiver.channels` rect (1 m on Potato).
   - **Shader.** `uniform vec4 imp[64]` (x, z, t0, strength) and `uniform vec4 imp2[64]` (radius, kind, dir.x, dir.z), plus `uniform float now` fed from the sim's clock, so pause and replay freeze it (not `TIME`).
   - **Ring term.** Each ring is `sin(k*(d - c*(now-t0)))` times an envelope that dies with age and distance.
   - **Voxel read.** Sample the field at `floor(xz/cell)*cell + cell/2` and snap y to a step, so rings show as stepped terraces of tiles.
   - **Toon colour.** Shade flat via `cross(dFdx(VERTEX), dFdy(VERTEX))` (the CC0 technique, finding 5). Use two or three flat tones, deep teal `river`, a lighter crest and white foam, with hard edges, in place of today's roughness-0.12 gloss.
   - **Flow.** A UV scroll along x reads as current. Bridges are slab decks with no piers, so no flow map is needed.
   - **Feeding (`RiverView`, GDScript ring buffer, padded to 64).** Push an impulse when the sim emits:
     - `stomp` at `kaiju_pos`, radius = event radius, only when the stomp lands in a channel;
     - `tail_sweep`;
     - `throw_land` / `limb` at `at` when that point lies in a channel;
     - `fall_land` with its footprint in a channel;
     - `KaijuRig.foot_planted(side, strength, pos)` when `pos` is in a channel. That is the per-footfall read, and the gait is presentation-to-presentation, so the sim stays untouched.
   - **Why first.** Comment #12 ("react to the kaiju") is mostly answered by this item alone, in both renderers.

2. **Add the wade wake and the rise: an analytic Kelvin V, a rise bulge and foam rings, all from `Emergence` state.** *Cost: about half a day on top of item 1.*
   - **Wake.** Uniforms: kaiju pos, facing, wade speed (`kaiju_pos` delta over sim dt) and `stand_y`. Draw foam where |across| ≈ 0.354·behind (19.47°, finding 6), fading over about 4 body lengths. Draw a bow-foam crescent ahead of the kaiju while `stand_y < 0` and it moves.
   - **Bulge.** While `emerge.active` and `risen() < SURFACE_AT`, add a broad dome of height `A·smoothstep(risen)` over the body footprint along the channel. The body lies along x (`Emergence._along`), so make it an ellipse, not a circle. It reads as something huge pushing water up before the head breaks.
   - **Surface break.** At `SURFACE_AT`, push one strength-max impulse and keep `RiverView`'s existing ring.
   - **Foam.** Add an "around the body" ring, a fixed impulse at the spawn whose radius tracks `body_scale()`.
   - **Why it matters.** The rise is the first thing the player sees every run (D-083). Today it is three flat rings on a static sheet.

3. **Splashes as voxel-cube `GPUParticles3D` through the existing `Fx._burst`: a crown on stomps and impacts in the water, and falling sheets during the rise.** *Cost: about half a day.*
   - **Crown.** Reuse `_burst` with a water-white `ParticleProcessMaterial` and a small `BoxMesh` (cube droplets read as voxels, like the carve debris). Shape it as a ring emission and an upward cone, gravity on, 0.8 to 1.2 s.
   - **Rise cascade.** From `risen()` 0.45 to 1.0, a continuous emitter along the body's top AABB, spawning downward with low spread: "sheets of water falling off the body".
   - **Cost control.** Opaque cubes avoid the 4K fill-rate trap of big translucent sheets (finding 7). Scale with the preset `amount_ratio` (0.35 to 1.0). Do not use `emit_particle()`: it is unsupported in Compatibility.

4. **Floating rubble: debris that reaches the water bobs instead of sinking to the 1.6 m bed.** *Cost: about half a day.*
   - **Hand-over.** In `CarveDebris`, a piece whose centre enters a channel rect and drops below the water plane leaves Jolt (free its RID). It joins a "floating" MultiMesh whose vertex shader bobs it: `y = -river_depth + ripple(xz) + a·sin(ω·now + phase)`, with drift along x at the flow speed and a slow sink-and-fade after N seconds.
   - **Shared include.** Put `ripple(xz)` in a `.gdshaderinc` used by both the water and the floater, so rubble rides the same rings with no CPU sampling.
   - **Seeding.** Phase comes from INSTANCE_CUSTOM, seeded by the FX RNG.
   - **Entry.** Push an impulse plus a splash on entry.
   - **Boundary.** Presentation only (10-destruction.md already says this layer "never writes back").

5. **Intersection foam: depth on Medium and up, analytic on Potato and Low.** *Cost: about half a day plus a gl_compatibility capture to prove the NDC branch.*
   - **Medium and up.** `hint_depth_texture` foam where scene depth minus water depth is small, giving white lines along the quay walls, legs, tail and floating rubble. Use the `CURRENT_RENDERER` branch from finding 1 and posterise to one hard foam band.
   - **Potato/Low.** Skip the screen read. Compute foam from distance to the channel rect's edges (pass `vec4 channel`) plus the active impulse radii and the kaiju footprint.
   - **Fallback.** The quays are axis-aligned and known, so the analytic version is nearly as good, and costs nothing.

6. **Bay sheet: give it the same shader with impulses off (swell and toon tones only), so river and bay match.** *Cost: about 1 hour.* Today the bay is a separate glossy sheet (`CityGround._water`, `#1c2c34`).

7. **Only if the director wants more after items 1 to 5: a SubViewport ping-pong heightfield over the rise area, High and Max only (route b).** *Cost: 2 to 3 days plus a determinism note.* It must run at a fixed step from the sim clock, it needs route (a) as its fallback anyway, and compute is out because Compatibility has none. I do not recommend it before a playtest of items 1 to 3.

**Do not do:** refraction or SSR (it clashes with the voxels, costs fill rate at 4K, and SSR is Forward+ only), compute water (a Compatibility dead end), or feeding any water value back into the sim.

**Evidence gaps:**
- No measured millisecond cost exists for any route on the director's GPU at 4K; every cost above is my estimate and must be captured with the GPU-time monitor.
- That `hint_depth_texture` foam renders correctly in gl_compatibility is inferred from the docs' Compatibility NDC formula; it has not been tested in this repo.
- GPUParticles3D's fixed-seed property, for repeatable splash shapes, was not verified in the 4.7 docs.
- No primary Townscaper, Astroneer or Dredge water write-up was retrieved.
- The Wind Waker wake method was not found in the source read; only its ocean layers were.
- The Teardown details come from a third-party frame breakdown, not voxagon.se.
- The Moonjump ripple post is a forum source with no licence, so copy no code from it.
- The godotshaders "Low poly water" CC0 claim was read from a search snippet; re-check the page before copying.
- The channel's exact width in metres was not computed, so the vertex counts are order-of-magnitude.
