# Hot-lightning breath at kaiju scale, built in Godot 4.7.2 (Forward+ and gl_compatibility)

Researched 2026-10-21. Repo read only (branch `claude/phase-b-boards`, nothing edited): `sim/breath_cone.gd`, `sim/rampage_sim.gd` (`_signature`), `scenes/breath_beam.gd`, `scenes/ability_fx.gd`, `scenes/beam.gdshader`, `scenes/rampage.gd` (`_ability_fx`, RNG setup), `scenes/city_view.gd` (`flash`, glow env), `scenes/sfx.gd`, `scenes/fx_decals.gd`, `sim/seeds.gd`, `data/tuning.json` fx block, `data/looks.json` glow. Built on `12-lighting.md` (light caps, Compatibility glow) and `08-soundscape.md` (bus plan, presentation RNG). "Inference" marks my own reasoning where no source states it.

What the code does today (the base to build on):
- **Sim.** `RampageSim._signature()` fires the cone breath as one instant hit. `BreathCone.of(sim)` gives origin (the snout), dir, reach and half_angle. The event is `{"type": "ability", "kind": "cone", "reach", "from"}`. It carries no per-breath index or seed.
- **FX.** `AbilityFx.breath()` drives `BreathBeam`, one pooled set of parts: a straight `CylinderMesh` core with `beam.gdshader` (additive, unshaded, value noise scrolling), a flame curtain on the cone's far arc, muzzle and strike flare quads, and **one pooled OmniLight3D at the strike**. It also fires a GPUParticles3D spark burst and a WEDGE `Decal` scorch. Everything runs for `fx.beam_seconds` 0.9 s with `breath_fade_in` 0.12 s.
- **Lights.** `CityView.flash()` creates a *new* OmniLight3D on every call; it is not pooled. **This branch has no 24-light pool in code yet.** It is recommendation #2 in 12-lighting.md, so treat the 24 as the planned budget.
- **RNG.** `rampage.gd` already keeps presentation RNGs apart from the sim: `_fx_rng = Seeds.make("fx", run_index)` (shared with camera shake), and Sfx has its own.
- **Sound.** Sfx plays a single one-shot, `breath.ogg`, on the "SFX" bus and ducks the crowd.

## Key findings

1. **Real lightning has a fixed timing grammar, and copying it is what makes a bolt read as lightning rather than a laser.**
   - First a dim stepped leader feels its way out. Then the bright return stroke follows the same channel; the return stroke "is the bright part we see as lightning" ([NOAA](https://noaa.gov/node/10764)).
   - Later dart leaders reuse the established channel "and give lightning its flickering appearance" (same page). So **the main channel stays put while it flickers**. Only the branches change between strokes.
   - Numbers:
     - Inter-stroke gaps average 40-50 ms in multi-ground-contact flashes ([Gin, ICAE 2014, NSSL-hosted preprint](https://www.nssl.noaa.gov/users/mansell/icae2014/preprints/Gin_94.pdf)).
     - A flash lasts about 200 ms, with an average of 4 strokes and a range of 1 to 26 ([Stormscope patent US4023408](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/4023408)).
     - 94% of those flashes showed a branched stepped leader (Gin, above).
   - Recipe consequence: a short dim "feeler" phase, then 3-4 bright strokes down one stable main channel, with the branches re-rolled on each stroke and never per frame.

2. **Bolt shape: midpoint displacement plus dim side branches is the standard game method and is cheap. Physically based lightning is overkill.**
   - The method: recursively split each segment at a midpoint pushed sideways along the normal, halving the offset range each generation. Occasionally add a third segment that heads roughly forward as a branch, and draw branches dimmer, because only the main bolt connects to the target ([GameDev.net "Lightning Bolts"](https://gamedev.net/blogs/entry/1901925-lightning-bolts); the page returned 403 to my fetch, so this is from the search summary).
   - The Tuts+ version (C#/XNA) gives concrete numbers:
     - one random point per 4 px of length, sorted
     - sway ±80 with an envelope that pins the end on target past 95% of the length
     - 3-5 branches at alternating ±30°
     - additive blending, so overlaps add up, and glow baked into a stretched segment texture with end caps
     - fade over about 30 frames, alpha −0.03 per frame
     - [Tuts+ "Shockingly Good 2D Lightning"](https://code.tutsplus.com/so-erzeugen-sie-schockierend-gute-2d-blitzeffekte--gamedev-2681t)
   - **That page states no code licence (Envato). Reimplement it; never copy it.**
   - Kim & Lin's physically based dielectric-breakdown model solves a large Poisson problem and is "slow, particularly in 3D". It is a research renderer, not a game FX ([UNC project page](https://gamma.cs.unc.edu/FAST_LIGHTNING/index.html)).

3. **Colour: a white core with a coloured halo is how real lightning and every VFX tool frame it. The "hot" read has to come from the halo and the impact, not the core.**
   - Lightning's colour mixes incandescence of superheated air with luminescence of excited nitrogen ([Science Learning Hub](https://www.sciencelearn.org.nz/resources/239-lightning-explained)). Accounts put the intrinsic colour at violet-blue, from a continuum near 20,000 K (forum-grade source, low weight: [weerwoord.be thread](https://www.weerwoord.be/m/195924)).
   - VFX tools expose the same split as parameters:
     - core radius and glow radius ([Softimage presets](https://download.autodesk.com/global/docs/softimage2014/en_us/files/fxpresets157.htm))
     - separate core and glow colours and sizes ([Vizrt pxLensEnergyBolt](https://docs.vizrt.com/plugins-user-guide/5.5/pxLensEnergyBolt.html))
     - an intense inner glow close to the core and a wider, dimmer outer glow ([HitFilm Lightsword](https://www.manula.com/manuals/fxhome/hitfilm-pro/7/en/topic/lightsword))
   - Inference for originality: Godzilla's atomic breath is a straight, continuous blue beam, and Ghidorah's gravity beams are gold zig-zags from several heads. A **white bolt with a hot amber halo that forks across a fan**, leaving molten glowing voxels behind, is neither.

4. **Flicker vs photosensitivity: a full-screen strobe at real lightning rates fails the flash rule. Flicker the brightness; do not black-out strobe.**
   - WCAG 2.3.1: nothing may flash more than three times in any one-second period unless it stays below the general and red flash thresholds, or the flashing area is small (21,824 px²) ([DAISY KB](https://kb.daisy.org/publishing/docs/wcag/three-flashes-or-below-threshold.html)).
   - Red flashes are the worse case ([W3C WCAG 2.0 draft, 2005](https://www.w3.org/TR/2005/WD-WCAG20-GENERAL-20050630/flicker-rate-and-warning.html)).
   - At kaiju scale on a 4K TV the bolt and its light cover far more than 21,824 px². Real 40-50 ms strokes are about 20-25 Hz.
   - Inference:
     - Keep at most **3 full-contrast light peaks per second**, so 2-3 strokes in the 0.9 s breath.
     - Make the fast flicker a shallow brightness wobble on the ribbon (stays bright, never drops near black).
     - Avoid saturated red in anything that flashes.
     - Add a "reduce flashing" option later.
   - These are web rules; no game-specific rule was fetched.

5. **gl_compatibility has no HDR, so "HDR > 1 for bloom" only works in Forward+. In Compatibility the halo must be real geometry.**
   - The Godot 4.7 renderers page gives Compatibility colour as "RGBA8. Low dynamic range" against Forward+ "RGBA16F. High dynamic range". Glow is supported in all renderers. HDR output is not supported in Compatibility ([Godot renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)).
   - The internal-architecture page instead says R10G10B10A2 UNORM, "tonemapped and stored in sRGB… no HDR support" ([internal rendering architecture](https://docs.godotengine.org/de/4.5/engine_details/architecture/internal_rendering_architecture.html)). The two docs pages conflict on the format, but both say LDR.
   - Compatibility glow is a separate, simplified implementation that hides Levels, Strength, Blend Mode, Mix and Map ([environment and post-processing](https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html)).
   - `looks.json` sets glow 1.0 with threshold 0.9. So in Compatibility only near-white pixels glow, and the amber halo will not bloom.
   - Bake the halo into an additive wide ribbon, as Tuts+ does with its baked-glow texture (finding 2).

6. **Geometry: a camera-facing ribbon that is rebuilt only on each stroke is the right primitive.** ImmediateMesh is fine at this size.
   - ImmediateMesh is "designed to generate simple geometry that changes often". Complex geometry (several thousand vertices) is "highly inefficient" ([ImmediateMesh class](https://docs.godotengine.org/en/stable/classes/class_immediatemesh.html)).
   - The docs pattern is `clear_surfaces()`, then `surface_begin()` each rebuild. They add it "may even be a little faster than generating an ArrayMesh every frame" ([procedural geometry docs](https://docs.godotengine.org/en/4.2/tutorials/3d/procedural_geometry/immediatemesh.html)).
   - A bolt of about 48 main points plus 4 branches of about 16, at 2 vertices per point and 2 layers, is about 450 vertices: trivial (inference).
   - Do the camera facing in the vertex shader: store each point's tangent in NORMAL and expand by `cross(tangent, view)`. A rebuild is then needed only per stroke, about 4 per breath, not per frame (inference; standard spatial shader, works in both renderers).

7. **Particles: GPUParticles3D works in Compatibility, minus trails and SDF collision.**
   - The 4.7 renderers table lists "Particle trails" and "Particle SDF collision" as unsupported in Compatibility, and states that unlisted features work in all renderers ([Godot renderers](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html)).
   - Godot says both its Vulkan and GLES3 renderers support GPU particles, and recommends GPUParticles over CPUParticles ([Godot, state of particles](https://godotengine.org/article/progress-report-state-of-particles/)).
   - Particle collision works only with GPUParticles3D, through box, sphere, SDF or heightfield colliders ([particle collision docs](https://docs.godotengine.org/en/4.2/tutorials/3d/particles/collision.html)).
   - So the existing spark bursts are fine. **Never draw the bolt with particle trails**; they vanish in Compatibility.

8. **Light: a few big lights strobed on the stroke schedule beat many small ones. Sucker Punch said so of inFAMOUS Second Son's neon.**
   - Matt Vainio (fxguide): neon "cast a ton more light"; "not every particle does cast light because it doesn't really give us the right look"; and fewer, larger lights gave the aggregate look more cheaply ([fxguide](https://www.fxguide.com/?p=49954); the talk itself is [GDC Vault 1020158](https://gdcvault.com/play/1020158/The-Visual-Effects-of-inFAMOUS), behind a login).
   - Our caps, from 12-lighting.md:
     - Compatibility: 32 positional lights per frame and 8 omni per mesh
     - Forward+: 512 clustered elements, with decals counting too
   - So the breath gets **2 lights: mouth and impact**, set to new energies on stroke events, not every frame.
   - **Decals do not render in Compatibility** (12-lighting.md table). The WEDGE scorch disappears there, so the impact glow also needs additive quads or emissive debris.

9. **Ready-made Godot lightning shaders exist but are 2D canvas shaders, and their licences vary per post.**
   - godotshaders.com code is free for commercial use under each post's chosen licence. Screenshots and videos are excluded ([godotshaders licence](https://godotshaders.com/license/)).
   - Posts checked:
     - "2D lightning": MIT ([post](https://godotshaders.com/shader/2d-lightning/))
     - "Random 2D Lightning Strikes": CC0 ([post](https://godotshaders.com/shader/random-2d-lightning-strikes/))
     - "Transparent Lightning": CC0, but it credits a Reddit original, so its provenance is unclear ([post](https://godotshaders.com/shader/transparent-lightning/))
   - Inference: these are useful as references for the ribbon's fragment falloff. A geometric bolt is simpler for a 3D fan than porting a 2D procedural shader, and anything copied needs a LICENSING_REGISTER row first (hard rule 5).

10. **Sound: crackle plus zap plus thunder is the expected read. No sourced timing exists for electric breath audio.**
    - Sucker Punch's sound team struggled early to make neon sound "neon" and not "laser" ([Game Developer, neon sound design](https://gamedeveloper.com/audio/the-sound-design-of-infamous-second-son-neon-power), from the search summary, not fetched in full).
    - 08-soundscape.md's plan applies:
      - a Hero bus that ducks the Bed bus
      - pitch randomness from a presentation RNG
      - distance delay of distance ÷ 343 m/s, only beyond about 150 m, and "prove it with a clip"
    - Inference: tie the zap one-shots to the same stroke schedule as the light. Put a low thunder layer under the return stroke for scale, plus a crackle loop for the 0.9 s.

## Recipe

All presentation. The stroke schedule is computed once per breath from a presentation seed (below) and drives ribbon, lights and sound together. Times are from fire (t = 0), within the existing 0.9 s `beam_seconds`.

| Layer | What | Timing | Colour | Godot node | Renderer notes |
|---|---|---|---|---|---|
| 1. Charge | Jaw and throat glow; 2-3 short dim feeler forks crawl 10-30% out from the mouth across the cone (the stepped leader) | 0-0.12 s (the existing `breath_fade_in`); the feelers step every ~40 ms | Halo colour at 30-40% | Same ribbon mesh, feeler pass; muzzle flare quad (exists) | Both. Dim, so no flash concern |
| 2. Main channel | One jagged bolt from mouth to the first-hit point (`_first_hit` exists). Midpoint displacement with the end pinned on target. **Shape fixed for the whole breath** | Return stroke at 0.12 s, re-strokes at ~0.40 and ~0.70 s (≤3 bright peaks a second); between strokes it holds at 70-85% with a shallow 20-25 Hz wobble | Core (1.0, 0.97, 0.92); Forward+ ×3-6 to bloom, Compatibility clamp to 1.0 so it passes the 0.9 glow threshold | ImmediateMesh ribbon, 2 surfaces (core strip ~0.25 u, halo strip ~1.5-2 u × body_scale), unshaded `blend_add`, `depth_draw_never`; camera facing in the vertex shader | Both. Compatibility gets glow only on the white core; the halo strip is the "bloom" |
| 3. Branch fan | 3-5 branches off the main channel, ending at points spread across ±`half_angle` inside the sim cone, dimmer (50-60%) | **Re-rolled at each stroke** (3-4 shapes per breath); each fades over ~60 ms after its stroke | Halo colour, hot amber (e.g. ~ff9a3c), tips toward the species tint | Same ImmediateMesh, extra strips | Both. This fan is what makes the cone read (and what makes it not a beam) |
| 4. Mouth light | OmniLight3D at the jaw, unshadowed | Peaks on each stroke, decays ~80 ms; never per frame | Warm white (current `HOT`) | Pooled; BreathBeam already owns one strike light, so add one | Counts toward the Compatibility 32/frame and 8/mesh caps; no shadows (Compatibility shadowed lights render in sRGB, per 12-lighting) |
| 5. Impact | Strike flare (exists), sparks (exists, GPUParticles3D), small glowing molten voxels at branch ends, the existing WEDGE scorch | Flare and sparks on the return stroke; extra spark puffs on re-strokes; scorch glow per existing tune | Molten `ff7a2a` → soot | Flare quad, GPUParticles3D, Decal | The Decal is Forward+ only; Compatibility relies on the flare and glowing debris. No particle trails (Compatibility) |
| 6. Secondary arcs | Short bolts jumping to 1-3 vehicles or props **the sim hit inside the cone** | On re-strokes only, 1 per stroke | Halo colour, thinner | Same ribbon builder | Must never touch anything outside the cone (the BreathBeam comment: "never promises more reach") |
| 7. Sound | Crackle loop under the whole breath; zap one-shot per stroke; low thunder under the return stroke; existing crowd duck | Zaps on the stroke times; thunder at 0.12 s, an optional delayed far copy | n/a | AudioStreamPlayer on "SFX" (later the Hero bus); AudioStreamRandomizer for the zaps | Pitch randomness from Sfx's own RNG |

Seed and sync: the sim event is instant and carries no seed. Derive one per breath in presentation, e.g. `Seeds.make("breath_bolt", run_index * 4096 + breath_count)`, where `breath_count` is a counter in AbilityFx. Never use `sim._rng`. Avoid `_fx_rng` as well: camera shake drains it every frame, so bolt shapes would vary with frame rate and captures would not repeat (inference from `rampage.gd:390`). The bolt endpoints come only from `BreathCone.of(sim)`, `_first_hit()` and sim-hit targets, so the picture never shows reach the sim did not apply.

## Sources

- NOAA, how lightning works (return stroke, dart leader flicker): https://noaa.gov/node/10764
- Gin, ICAE 2014 preprint, multi-stroke statistics (NSSL host): https://www.nssl.noaa.gov/users/mansell/icae2014/preprints/Gin_94.pdf
- Stormscope patent US4023408 (40 ms, 200 ms, 4 strokes): https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/4023408
- Science Learning Hub, lightning colour: https://www.sciencelearn.org.nz/resources/239-lightning-explained
- weerwoord.be thread (blackbody ~20,000 K, low weight): https://www.weerwoord.be/m/195924
- GameDev.net, Lightning Bolts (midpoint and branches; 403 on fetch): https://gamedev.net/blogs/entry/1901925-lightning-bolts
- Tuts+, 2D lightning (numbers; no stated licence): https://code.tutsplus.com/so-erzeugen-sie-schockierend-gute-2d-blitzeffekte--gamedev-2681t
- Kim & Lin, Fast Animation of Lightning Using an Adaptive Mesh: https://gamma.cs.unc.edu/FAST_LIGHTNING/index.html
- Softimage core and glow presets: https://download.autodesk.com/global/docs/softimage2014/en_us/files/fxpresets157.htm
- Vizrt pxLensEnergyBolt: https://docs.vizrt.com/plugins-user-guide/5.5/pxLensEnergyBolt.html
- HitFilm Lightsword (inner and outer glow, seeded flicker): https://www.manula.com/manuals/fxhome/hitfilm-pro/7/en/topic/lightsword
- 80.lv fire lightning spell breakdown (beam plus sparks, smoke, hit mark, debris): https://80.lv/articles/vfx-breakdown-fire-lightning-spell-in-ue4
- fxguide, Vainio on inFAMOUS Second Son: https://www.fxguide.com/?p=49954
- GDC Vault, The Visual Effects of inFAMOUS: Second Son: https://gdcvault.com/play/1020158/The-Visual-Effects-of-inFAMOUS
- Game Developer, neon power sound design: https://gamedeveloper.com/audio/the-sound-design-of-infamous-second-son-neon-power
- DAISY KB, WCAG 2.3.1: https://kb.daisy.org/publishing/docs/wcag/three-flashes-or-below-threshold.html
- W3C WCAG 2.0 draft, red flash: https://www.w3.org/TR/2005/WD-WCAG20-GENERAL-20050630/flicker-rate-and-warning.html
- Godot renderers (4.7): https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Godot internal rendering architecture: https://docs.godotengine.org/de/4.5/engine_details/architecture/internal_rendering_architecture.html
- Godot environment and post-processing (glow): https://docs.godotengine.org/en/stable/tutorials/3d/environment_and_post_processing.html
- Godot ImmediateMesh class: https://docs.godotengine.org/en/stable/classes/class_immediatemesh.html
- Godot ImmediateMesh tutorial: https://docs.godotengine.org/en/4.2/tutorials/3d/procedural_geometry/immediatemesh.html
- Godot particle collision: https://docs.godotengine.org/en/4.2/tutorials/3d/particles/collision.html
- Godot, state of particles: https://godotengine.org/article/progress-report-state-of-particles/
- godotshaders licence and posts: https://godotshaders.com/license/ , https://godotshaders.com/shader/2d-lightning/ , https://godotshaders.com/shader/random-2d-lightning-strikes/ , https://godotshaders.com/shader/transparent-lightning/

## For Kaiju Incremental (ranked, simplest viable first)

1. **Bolt-fan ribbon in place of the straight core: the main deliverable.**
   - What: a new presentation script (e.g. `scenes/breath_bolt.gd`, about 150-200 lines) beside a new `bolt.gdshader` (about 40 lines). It replaces BreathBeam's `CylinderMesh` core and the flame curtain with one ImmediateMesh ribbon:
     - main channel from the jaw to `_first_hit`, shape fixed for the breath
     - 3-5 branches fanning to ±`half_angle` inside `BreathCone`
     - two strips each: core and halo
   - Rebuilt on 3-4 stroke times; camera facing in the vertex shader.
   - Keep `_first_hit`, the flares, sparks and scorch as they are.
   - Cost: about a day. Under 500 vertices, about 4 rebuilds per breath, 2 additive layers (inference: negligible at 4K).
   - Proof:
     - flow-suite check that `played` still records "breath"
     - one seeded test: the same seed gives the same points, and every branch end lies inside `BreathCone.cover()`
     - a 4K clip in both renderers through `ci_capture.sh`
   - Tunables (stroke times, widths, branch count, sway) go in `data/tuning.json` fx, not code (hard rule 4).
2. **Stroke schedule drives light and sound (one source of timing).**
   - What:
     - a pure function `strokes(seed, seconds) -> Array[float]`: 2-3 bright peaks, ≤3 a second, plus a shallow wobble
     - BreathBeam's existing strike OmniLight3D plus one pooled mouth light, stepped on strokes
     - Sfx gets `play_strokes(times)`: a zap per stroke, thunder on the first, a crackle loop for `beam_seconds`
   - Switch `CityView.flash()` to the planned light pool (12-lighting rec #2) at the same time, because it allocates a light per call.
   - Cost: half a day of code, plus 3 audio layers (zap, crackle, thunder) that must be licence-cleared (Kenney CC0 or in-house synth, the way `tools/sfx/build_sfx.py` already builds them; no spend).
3. **Per-breath presentation seed.**
   - What: `Seeds.make("breath_bolt", run_index * 4096 + breath_count)` inside AbilityFx; never `sim._rng`, never the frame-dependent `_fx_rng`.
   - Cost: about 10 lines.
   - Payoff: replays and captures show the same bolt, which makes critic reviews comparable.
4. **Compatibility path check.**
   - What:
     - clamp the core to ≤1.0 under Compatibility so it crosses the 0.9 glow threshold without clipping hue
     - make the halo strip carry the glow
     - add glowing molten voxel puffs at branch ends, because the Decal scorch does not exist there
   - Cost: a few hours plus a gl_compatibility CI capture.
5. **Secondary arcs to struck vehicles (later, only if the fan alone does not read "electric").**
   - What: 1 arc per re-stroke to a vehicle the sim damaged inside the cone. Needs the hit list from the sim event, or a presentation re-query of the cone.
   - Cost: about half a day, plus a small sim-event field if the event is used (a sim review is needed if the event schema changes).
6. **Director decision before building colour:** the halo colour (hot amber, species-eye tint, or white with a thin violet fringe).
   - Show 3 labelled 4K stills through `ask-the-director` after an art-qa-critic pass.
   - Do not decide this by agent taste.
7. **Do not:**
   - use particle trails (Compatibility)
   - use the Kim & Lin physical model (cost)
   - strobe the light per frame or more than 3 full peaks a second (flash safety)
   - flash saturated red
   - copy the Tuts+ code (no licence)

Evidence gaps:
- No Pacific Rim, Shin Godzilla, MK Raiden, Warframe, Overwatch, Control, Borderlands, Diablo, Ghostbusters or Tesla-photography sources were fetched. The originality contrast with Godzilla and Ghidorah is my inference, not sourced.
- No sourced cost numbers for additive overdraw at 4K in Godot.
- The Compatibility buffer format conflicts between two Godot docs pages (RGBA8 vs RGB10A2); both say LDR.
- The WCAG luminance thresholds for a "flash" were not fetched, and no game-specific flash guideline was checked.
- The GameDev.net page and the Sucker Punch sound article were not read in full.
- That GPUParticles3D works in Compatibility is inferred from the renderers table's "unlisted = supported" rule and the GLES3 statement, not from an explicit line.
