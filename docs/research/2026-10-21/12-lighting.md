# Lighting a giant voxel kaiju against a burning city in Godot 4.7 (Forward+ and gl_compatibility)

Researched 2026-10-21 against the Godot "stable" docs (served as 4.7), the 4.4 to 4.7 release pages and GitHub PRs. The repo was read but not edited: `scenes/city_view.gd`, `scenes/kaiju_model.gd`, `scenes/fire.gd`, `scenes/city_decor.gd`, `scenes/police.gd`, `project.godot`.

## Key findings

1. **The hard light limits differ a lot between the two renderers, and gl_compatibility's frame cap is the one that will bite.**
   - Forward+ draws up to **512 clustered elements in the camera view**. Omni lights, spot lights, decals and reflection probes all count toward that one pool. You can raise it with `rendering/limits/cluster_builder/max_clustered_elements`. Past the limit, lights silently stop rendering and pop in as the camera moves, and the docs say distance fade helps avoid that (https://docs.godotengine.org/en/stable/classes/class_projectsettings.html, https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html).
   - gl_compatibility allows **8 omni plus 8 spot lights per mesh** (`rendering/limits/opengl/max_lights_per_object`, default 8). It also caps **positional lights per frame at 32** (`rendering/limits/opengl/max_renderable_lights`, default 32): "If more lights than this number are used, they will be ignored." (https://docs.godotengine.org/en/stable/classes/class_projectsettings.html).
   - Both renderers allow at most 8 visible DirectionalLight3Ds (https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
   - A night city with one OmniLight3D per street lamp, fire and police car will pass 32 quickly. In Compatibility, that means lamps vanish arbitrarily unless we pool them.

2. **Shadowed positional lights are limited by the shadow atlas, and gl_compatibility renders shadowed lights differently.**
   - The default positional atlas is 4096 px, with quadrant subdivisions 2/2/3/4. That gives **up to 88 shadowed omni/spot lights in view (4 + 4 + 16 + 64)**, and the later quadrants get progressively less resolution (https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html, https://docs.godotengine.org/en/stable/classes/class_projectsettings.html).
   - A spot shadow is "significantly faster" than an omni shadow: it renders 1 texture instead of 6 cube faces (or 2 with dual paraboloid) (https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html).
   - In Compatibility, shadowed lights render in multiple passes **in sRGB space instead of linear**. That "can drastically alter the light's appearance compared to unshadowed lights", so a shadowed fire and an unshadowed fire will not match (same page).

3. **Directional sun shadows: the defaults suit us; tune normal bias for voxel edges and set max distance to the play area.**
   - Default mode is PSSM 4 splits; 2 splits is the cheaper option.
   - Max Distance sets where the shadow ends.
   - Blend Splits smooths the seams between splits, at some cost to detail and performance.
   - Fade Start can go up to 1.0 when Max Distance already covers the whole scene.
   - Pancake Size fixes missing shadows from large, unsubdivided meshes (https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html).
   - Bias: raising **Normal Bias is preferred over raising Bias**. It fixes acne with less peter-panning (shadows detaching from their casters), though it can thin shadows (same page). That matters on flat voxel faces with hard 90-degree edges.
   - The directional shadow map defaults to 4096 px, 16-bit depth, soft filter quality 2 (https://docs.godotengine.org/en/stable/classes/class_projectsettings.html).
   - Contact-hardening soft shadows (PCSS) come from `light_angular_distance` on a DirectionalLight3D. They work on all light types in Forward+ but only on omni/spot lights in Mobile (https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).

4. **GI with geometry that changes all the time: only screen-space methods and SDFGI qualify, and SDFGI only half-qualifies. Nothing GI-like works in Compatibility except SSAO.**
   - **SDFGI** is Forward+ only. It is "viable for procedurally generated levels (including when structures are generated during gameplay)", but "dynamic objects can receive GI, but not contribute to it" (https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html).
   - The draft HDDAGI PR describes SDFGI as one that "drops frames very significantly when moving" because it rebuilds its SDF even for small motion (https://github.com/godotengine/godot/pull/119869). Carved buildings would keep triggering that.
   - **VoxelGI** has to be baked, so it only works for levels "generated in advance (and not during gameplay)" (same docs page).
   - **LightmapGI** is "not viable for procedurally generated levels" (same docs page).
   - **SSIL** "works with both static and dynamic lights ... and occluders (including emissive materials)". It is Forward+ only and runs at half resolution by default (same docs page; https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html).
   - **SSAO** works in Forward+ and, since 4.6, in Compatibility as a simplified version that only exposes Radius and Intensity (https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html).

5. **HDDAGI, the SDFGI replacement, is still not merged as of October 2026.**
   - reduz's original PR #86267 ("Upgrade SDFGI to HDDAGI") is an open draft. Its thread is locked, and clayjohn says the timeline is uncertain (https://github.com/godotengine/godot/pull/86267).
   - A rebase, PR #119869, was opened 2026-05-29 by OrangeeZ. It is open, milestone 4.x, labelled "breaks compat", and lists "Dynamic objects support" as a TODO after merging (https://github.com/godotengine/godot/pull/119869).
   - The 4.7 release page lists no GI change (https://godotengine.org/releases/4.7/).
   - Conclusion: plan without HDDAGI. SDFGI is still the shipped Forward+ option and is not deprecated in the docs.

6. **Volumetric fog is Forward+ only. It can show searchlight beams with real shadows, but it has a finite range and leaves trails behind moving lights.**
   - Every light has a `volumetric_fog_energy` setting, and "enabling shadows on a light will also make those shadows visible on volumetric fog" (https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html).
   - It has a finite range (`volumetric_fog_length`).
   - Thin fog volumes "may appear to flicker when the camera moves".
   - With temporal reprojection on, moving lights and FogVolumes "ghost and leave a trail". The docs say short-lived lights (muzzle flashes, explosions) should use `volumetric_fog_energy = 0` (same page).
   - The froxel grid defaults to 64 x 64 x 64 slices (https://docs.godotengine.org/en/stable/classes/class_projectsettings.html). That grid is coarse compared with a thin helicopter beam.
   - The proven workaround is a **fake cone mesh**. It uses a depth-texture proximity fade and a vertical falloff, and gives "a much sharper silhouette than ... godot's real volumetric fog for almost no performance cost" (passivestar, https://passivestar.xyz/posts/light-beam-shader-in-godot/).
   - The cone shader reads `hint_depth_texture`, and the renderer table lists "depth texture" as supported in Compatibility, so it should work there (https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html). Needs a Compatibility capture to confirm.

7. **Haze and atmospheric perspective work in both renderers through ordinary fog, and that is the cheapest way to show scale.**
   - Depth fog and height fog are supported in all renderers.
   - **Sun Scatter** tints the fog with the DirectionalLight3D's colour when looking toward the light.
   - **Aerial Perspective** blends the fog toward the sky colour (https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html, https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html).
   - A kaiju lit from behind by a low sun or moon, with sun-scatter fog behind it, shows as a bright rim against a hazy skyline. That costs no extra light.

8. **Tonemapping and glow: AgX is the right tonemapper; Compatibility glow is simplified.**
   - AgX arrived in 4.4: "capable of handling very bright scenes better than our other available options" (https://godotengine.org/releases/4.4/).
   - 4.6 exposed `agx_white` and `agx_contrast` (https://godotengine.org/releases/4.6/). Contrast can now be tuned on AgX itself instead of through Adjustments.
   - In Compatibility, glow uses a different implementation that hides Levels, Normalized, Strength, Blend Mode, Mix and Map (https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html).
   - Glow picks up any pixel above the HDR threshold, so emissive materials glow without a light. That makes emissive windows and embers a free way to show a light source.
   - Auto exposure, SSR, SSIL, volumetric fog, decals, light projectors, depth-of-field blur, TAA and FSR2 are all unavailable in Compatibility (same pages).
   - 4.7 adds HDR output on Windows (https://godotengine.org/releases/4.7/). That is relevant to the director's 4K TV; which renderers support it is not stated.

9. **Film craft: hide and reveal with smoke and fire, rim-light against haze, and set warm fire against cool sky.**
   - Seamus McGarvey, DP on *Godzilla* (2014): "For the night photography, we actively employed fuse and smoke, lighting effects, fire, so that Godzilla was revealed elliptically and sporadically" (https://www.iftn.ie/news/featureinterviews/?act1=record&only=1&aid=73&rid=4287169&tpl=archnews&force=1).
   - The *Pacific Rim* title designer "rim-lit [the ILM models] ... with softboxes and bounce cards to create a dark, monolithic look" (https://www.artofthetitle.com/title/pacific-rim/).
   - del Toro had ILM not match lighting from shot to shot, choosing expressive lighting over continuity (https://en.wikipedia.org/wiki/Pacific_Rim_(film)).
   - Applied to our game: give the kaiju its own rim light, hide parts of it in smoke, let fires light it from below in warm colour, and keep the sky and moon light cool. That is the night-and-smoke look on a budget.

10. **4.7 adds AreaLight3D (rectangular lights with soft shadows) (https://godotengine.org/releases/4.7/).**
    - The docs warn that in Forward+, "as soon as one area light is visible, it incurs an additional performance cost on all rendered objects". Textured area lights are not supported in Compatibility (https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html).
    - Not worth adding for a rampage scene.

## Renderer comparison

| Feature | Forward+ | gl_compatibility |
|---|---|---|
| Omni/spot lights | 512 clustered elements per view (omni + spot + decal + probe), can be raised | 8 omni + 8 spot per mesh; **32 positional lights per frame** by default, extras ignored |
| Directional lights | 8 visible | 8 visible |
| Shadowed omni/spot | Positional atlas: 4096 px, 88 slots by default (4/4/16/64) | Supported, but multi-pass and blended in sRGB, so it looks different from unshadowed lights |
| Directional shadow | PSSM 2/4 splits, blend splits, PCSS via angular distance | Supported; no PCSS on directional |
| SDFGI | Yes. Updates at runtime; dynamic objects receive GI but do not contribute; stutters on change | No |
| VoxelGI / LightmapGI | Yes, but baked, so unsuitable for carving | VoxelGI no; LightmapGI can be rendered but is baked |
| SSIL | Yes, half resolution, works with dynamic geometry | No |
| SSAO | Yes, full controls | Yes since 4.6, Radius and Intensity only |
| Volumetric fog / FogVolume | Yes (finite range, ghosting, 64^3 froxels) | No |
| Depth/height fog, sun scatter, aerial perspective | Yes | Yes |
| Glow | Full (blend modes, levels, map) | Simplified, several properties hidden |
| Tonemap AgX | Yes, with agx_white / agx_contrast (4.6) | Yes |
| Decals (light pools) | Yes (count toward the 512) | No |
| Light projectors (gobos) | Yes | No |
| Auto exposure, SSR, TAA, FSR2, DoF blur | Yes | No |
| Fake beam cone (depth-fade shader) | Yes | Should work (depth texture listed as supported); untested here |

Sources for the table: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html, https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html, https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html, https://docs.godotengine.org/en/stable/classes/class_projectsettings.html

## Sources

- Godot docs, 3D lights and shadows: https://docs.godotengine.org/en/stable/tutorials/3d/lights_and_shadows.html
- Godot docs, Overview of renderers: https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot docs, Volumetric fog and fog volumes: https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html
- Godot docs, Introduction to global illumination: https://docs.godotengine.org/en/stable/tutorials/3d/global_illumination/introduction_to_global_illumination.html
- Godot docs, Environment and post-processing: https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html
- Godot docs, ProjectSettings: https://docs.godotengine.org/en/stable/classes/class_projectsettings.html
- Godot 4.4 release (AgX): https://godotengine.org/releases/4.4/
- Godot 4.5 release: https://godotengine.org/releases/4.5/
- Godot 4.6 release (AgX parameters): https://godotengine.org/releases/4.6/
- Godot 4.7 release (AreaLight3D, HDR output): https://godotengine.org/releases/4.7/
- HDDAGI PR #86267 (reduz, draft): https://github.com/godotengine/godot/pull/86267
- HDDAGI rebase PR #119869 (open, 2026): https://github.com/godotengine/godot/pull/119869
- passivestar, light beam shader in Godot: https://passivestar.xyz/posts/light-beam-shader-in-godot/
- Fake god rays (cone mesh + SpotLight3D): https://godotshaders.com/shader/fake-godrays-godot-4-2/
- Seamus McGarvey interview (Godzilla 2014): https://www.iftn.ie/news/featureinterviews/?act1=record&only=1&aid=73&rid=4287169&tpl=archnews&force=1
- Art of the Title, Pacific Rim: https://www.artofthetitle.com/title/pacific-rim/
- Wikipedia, Pacific Rim (film), production and VFX: https://en.wikipedia.org/wiki/Pacific_Rim_(film)

## For Kaiju Incremental

### What the repo does today

- **`scenes/city_view.gd`:**
  - Builds one shadowed sun (`directional_shadow_max_distance = 160`, `shadow_blur 1.5`, `light_angular_distance 1.0`).
  - Environment: AgX, SSAO, SSIL (a comment notes SDFGI was rejected at "~a tenth of the frame"), depth fog, glow and Adjustments.
  - No volumetric fog.
  - `project.godot` sets no `rendering_method`, so the game runs Forward+ by default.
- **`scenes/kaiju_model.gd`:** already has a cool, unshadowed DirectionalLight3D rim light, culled to the kaiju's layer 2. This is the right craft choice.
- **Lights per lamp, fire and police car:**
  - `city_decor.gd` makes one OmniLight3D per street lamp (range 6).
  - `fire.gd` makes one per fire.
  - `police.gd` makes one per car beacon.
  - None uses `distance_fade_enabled`.

### Recommendations, ranked (simplest viable first)

1. **Turn on distance fade for every lamp, fire and beacon light.**
   - Cost: one line per light type, nearly zero.
   - It culls far lights before they reach the shader. That protects Forward+'s 512 budget and is the docs' own fix for pop-in.
   - Pair it with shadow off (already the default) on all small fires.
2. **Pool positional lights so they fit gl_compatibility's 32-per-frame cap.**
   - Cost: a small script, about half a day.
   - Keep, for example, the 24 nearest-to-camera fires and lamps as real lights. Every other lamp and fire becomes emissive voxels plus glow (free in both renderers).
   - Without this, Compatibility drops lights arbitrarily once more than 32 are on screen.
   - Optionally raise `max_renderable_lights` in Compatibility and measure the cost.
3. **Tune the sun for drama: low pitch at dusk and night, and point the camera toward it.**
   - Cost: data values in the look tables only.
   - A low sun or moon behind the kaiju gives long shadows and a silhouette.
   - Turn on fog sun scatter and aerial perspective so the skyline fades into haze behind the giant. Both renderers support this.
   - Raise **normal bias** (not bias) until voxel faces show no acne.
   - Keep Max Distance near the play radius and set Fade Start to 1.0 if the area is covered.
   - Try PSSM 2 splits if the sun shadow shows up in the profile.
4. **Keep the kaiju-only rim light and add a warm under-fill.**
   - Cost: a few lines.
   - At night, drive the rim colour from the time of day: cool blue moonlight from behind.
   - Add one unshadowed warm omni or directional light below the kaiju, culled to layer 2, pulsing with the nearest fire. That is the Godzilla look of fire light from below, set against cool sky.
   - It costs one light, not N.
5. **Searchlight beams as fake cones in both renderers (passivestar-style depth-fade shader on a cone mesh, plus a SpotLight3D for the ground pool).**
   - Cost: one shader and one scene, about a day.
   - Shadow only the 1-2 nearest searchlights: a spot shadow is cheap. Leave the rest unshadowed.
   - Volumetric fog stays an optional Forward+-only extra. If used, set `volumetric_fog_energy = 0` on muzzle flashes and explosions to avoid ghost trails.
6. **GI: keep SSIL + SSAO in Forward+ and SSAO only in Compatibility. Do not adopt SDFGI, VoxelGI or LightmapGI for the carved city.**
   - Cost: none (it is the current setup).
   - Recheck HDDAGI only once #119869 merges.
7. **Explosion and muzzle-flash lights: a short-lived, unshadowed omni light that is pooled and reused (never one new node per shot), plus a glow spike from emissive particles.**
   - Cost: small.
   - In Compatibility these share the 32-light cap with item 2's pool.
8. **Later, and only if needed: decal light pools under lamps (Forward+ only, they count toward the 512), volumetric FogVolume smoke columns, and 4.7 HDR output for the 4K TV.**
   - Each needs its own capture test.
   - Skip AreaLight3D: it adds a cost to every object rendered.

**Evidence gaps:**
- I found no published benchmark of shadowed or unshadowed light counts at 4K/60 in Godot 4.7, so frame budgets have to be measured on the director's GPU.
- Whether the fake beam shader works in Compatibility is inferred from the docs listing depth-texture support, not tested.
- Whether 4.7 HDR output works in each renderer is not stated on the release page.
- I found no detailed source on *Pacific Rim*'s neon and rain lighting beyond general production notes.
- Whether Compatibility's "8 per mesh" applies per surface (the ProjectSettings text says "each surface") or per mesh resource is worded inconsistently across the docs pages.
