# Kaiju Incremental research: top 3 per topic

Synthesis of the 14 topic files (01-14, researched 2026-10-21). Each topic's three items are its own ranked list, simplest viable first. Every item keeps the house rules: the sim decides outcomes, presentation only decorates, assets must be free and commercial-OK and entered in the licensing register, no runtime AI, no spend without the director's written yes. Sources and detail are in the topic files.

## Strongest recommendations overall (ranked)

1. **Measure walk cadence, then lengthen the stride instead of speeding up the legs.** The adult clip likely plays about 2.4x faster than it was authored. Cost: about 2 h to measure plus half a day to re-bake. (11-walk-animation.md)
2. **Make sure the player can afford an upgrade after every rampage.** Use geometric costs in `data/` and a seeded sim test that checks the first hour. Cost: 1-2 days. (01-incremental.md)
3. **Turn the body by stepping, not swivelling.** A planted foot steps once the body has twisted about 25-30 deg past where the foot was planted. Today's swivel looks like a plastic toy. Cost: about 40-60 lines in `gait_biped.gd`, no sim change. (14-turn-with-legs.md)
4. **Stop tail and tentacle joints passing through walls.** Push them out of solid cells inside the existing chain passes, in presentation only. Cost: 0.5-1 day, no determinism risk. (13-body-collision.md)
5. **Add one audio bus layout that ducks the bed under the roar and stomp.** Use a master limiter plus a Hero-to-Bed sidechain duck. Cost: about 1 h, no code. (08-soundscape.md)

## 01 Incremental loop (01-incremental.md)
1. An upgrade is affordable after every rampage and the first purchase comes within about 60 s. Costs grow geometrically (rate about 1.07-1.15), checked by a seeded test. Cost: 1-2 days.
2. A rampage timer that starts at about 45-90 s and grows through upgrades to a 10-15 min ceiling. Cost: about 1 day plus one playtest.
3. The city scales with the kaiju (taller blocks, more tanks and helicopters; prestige brings harder enemies and bigger rewards) so the late game never goes AFK. Cost: 3-5 days; balance risk.

## 02 Kaiju lore and scale (02-kaiju-lore.md)
1. Each stage feels heavier: slower turns and acceleration and longer camera shake, all per stage in data. Cost: about half a day plus one fixture.
2. The camera never shrinks the kaiju. Keep cars, people and bollards near its feet, and pull the camera back less than the kaiju grows. Cost: one tunable per stage plus one capture per stage.
3. Each stage's footsteps are longer and lower, with a falling-debris layer, and the roar is pitched down per stage. Cost: data tunables plus CC0 layers; no spend.

## 03 AI animation (03-ai-animation.md)
1. Tanks and helicopters use no rig and no AI: turret, barrel and rotor transforms are driven by sim events. Cost: free, a few hours.
2. Kaiju get procedural motion plus 3-6 hand-keyed Blender clips per stage (Rigify meta-rigs, exported as GLB, no retargeting). Keep IK presentation-only and deterministic. Cost: free; Blender time per stage.
3. The crowd uses 3-4 Mixamo clips on one shared humanoid skeleton. Never ship the raw Mixamo files. Cost: free.

## 04 Blender AI modelling (04-blender-ai-modelling.md)
1. An LLM-written, data-driven grid generator builds hard-surface props (buildings, tanks, helicopters, cars). It runs headless or through the official Blender MCP and renders five views on every run. Cost: free, time only.
2. Kaiju and small people are drafted as `.vox` files and imported with the free VOX importer. Clear MagicaVoxel's licence first. Cost: free.
3. Organic stages come from image-to-3D, then get voxelized and cleaned up by hand. Use TripoSG (MIT, 8 GB) first, and TRELLIS.2 only with 24 GB of VRAM and cleared dependencies. Cost: free locally; Tripo only from existing credits.

## 05 Godot modelling (05-godot-ai-modelling.md)
1. Voxel models live in `data/` as a palette plus named part grids. One GDScript culled mesher builds an ArrayMesh per rigid part, baked or cached, with a vertex-count test. Cost: 1-2 builder days.
2. Author in MagicaVoxel and convert `.vox` to the data format with an offline tool, or use the MIT importer pinned as editor-only tooling. Cost: half a day plus artist time; clear the licence first.
3. Add greedy meshing only if triangle counts measure too high. Use the crack-free "polygon" variant (MIT) inside the existing carve GDExtension. Cost: 1-3 days of C++.

## 06 City generation (06-city-generation.md)
1. Make "no empty space" a test. For pinned seeds at every stage, check a minimum built footprint per district, no built block with zero lots, a maximum gap along streets, and a timing line. Cost: one suite.
2. One seeded density field per block drives height, lot size and tower chance, and each stage raises and spreads it. Cost: a small function plus a tuning table.
3. Label each block's district type by simple rules (downtown, residential, industrial, docks), with no Voronoi. Cost: a lookup plus a style table in `data/`.

## 07 Free assets (07-free-assets.md)
1. Godot's built-in toon shading with a next_pass outline, plus the CC0 Kenney Particle Pack for dust and smoke. Cost: about half a day.
2. One shake and hit-stop addon (Wallop Lite, MIT), or about 40 lines of our own trauma shake. Cost: under an hour.
3. The Sonniss GDC bundle as the destruction sound base (no redistribution, no AI training, keep out of public repos), plus CC0-only Freesound for sirens, screams and roars. Cost: hours of curating.

## 08 Soundscape (08-soundscape.md)
1. A bus layout with a master HardLimiter and one Hero-to-Bed sidechain duck. Cost: about 1 h, no code.
2. A pooled SFX manager with per-category voice caps from data. Hero voices are reserved, the quietest or farthest voice is stolen, and a 500-event test proves the caps hold. Cost: about 150-250 lines plus a test.
3. The sim emits size-bucketed break events (energy against per-material thresholds), with one randomizer per bucket and a presentation-only RNG. Cost: one event field plus about 30 cleared samples.

## 09 Tentacles (09-tentacles.md)
1. Step the existing Verlet chains at a fixed 1/60 s (at most 4 substeps a frame) and move their tunables into `data/`. Cost: about 15 lines.
2. Make each reach a bend that travels from base to tip with an ease-in-out curve, pinning the tip only at the end. Cost: about 40-60 lines.
3. The arm hauls back as a stiff three-segment jointed fetch while dragging a grabbed object. Cost: about 30 lines.

## 10 Destruction and physics (10-destruction.md)
1. Keep destruction in the sim. Toppling is a seeded hinge fall in the existing C++ carve library, and Jolt never decides outcomes, because it is not replayable through Godot. Cost: moderate C++; no physics budget.
2. Find floating islands with a bounded flood fill on a coarse brick graph after each batch of carves. Cost: small to moderate C++.
3. Debris is presentation-only: a MultiMesh with shader ballistics, seeded from the sim event, that settles into rubble. Cost: one shader plus one pool class; works in both renderers.

## 11 Walk animation (11-walk-animation.md)
1. Measure cadence per stage: footfalls per second, playback rate against the authored rate, and duty factor. The pass bar is adult playback at 0.8-1.2x authored. Cost: about 2 h.
2. Lengthen the stride, not the cadence: re-bake per stage, with duty factor 0.62 raised to about 0.70 for adolescent and adult. If that stride is out of reach, the director chooses between two clips. Cost: about half a day.
3. Every footfall gets an impact: a pelvis compression, a small tail or jaw kick, and a strength factor per life stage. Cost: about 2-3 h.

## 12 Lighting (12-lighting.md)
1. Turn on distance fade for every lamp, fire and beacon light. Cost: about one line per light type.
2. Pool positional lights so about 24 are real and the rest are emissive with glow, which fits gl_compatibility's cap of 32 lights per frame. Cost: about half a day.
3. Put a low sun or moon behind the kaiju, add fog sun scatter and aerial perspective, and raise normal bias rather than bias. Cost: data values only.

## 13 Body collision (13-body-collision.md)
1. Push tail and tentacle joints out of solid cells (position-based dynamics), inside the existing constraint passes, in presentation only. Cost: 0.5-1 day.
2. Feet and grips rest on the height sampled under each foot instead of a flat plane, with a stretch cap. Cost: about half a day.
3. The sim decides between blocking and carving with one rule (attack, dash or speed above a threshold; tail discs carve only on a fast turn). This is the director's call. Cost: about 1 day plus a seeded test and a sim-review packet.

## 14 Turning with legs (14-turn-with-legs.md)
1. Add a twist trigger: a planted foot steps at about 25-30 deg of twist. The outside foot goes first and the inside foot pivots. Cost: about 40-60 lines.
2. Gate body yaw on foot phase: full turn rate while a foot swings and about a 0.15-0.25 share when both feet are down. The head and neck take the rest, and the lag is capped at about 30-40 deg. Cost: about 20 lines.
3. Lead order through the body: the head turns at once (clamped), the chest takes about half, the hips take what the feet allow, and the tail counter-swings. Cost: about 30 lines.

## 15. Minimal in-run HUD (15-minimal-hud.md)
1. Strip the HUD to the rulings. Delete the controls hint, the HP plate and the dark plates, and keep the timer as it is. Biomass becomes one boxless, outlined label bottom right at 36-72 px. No HUD text is below 24 px, and the margins move out to the TV title-safe area (about 96 px at the sides and 54 px top and bottom, at 1080p). Cost: about 2-3 h, HUD script only.
2. The breath shows as an icon with a ring drawn round it (`draw_arc` from the sim's cooldown, no texture assets), with a pulse and a sound when it is ready. It sits bottom centre, in the old health bar's space. Whether dash and the ultimate get the same ring is the director's call. Cost: about 2-3 h plus one icon.
3. Show health as a red edge vignette whose width grows, plus a heartbeat below about 30% and a flash on the kaiju when hit, so it never relies on colour alone. Test it over the brightest fire. A thin bar that appears only when hit is the "repurposed" alternative, and the choice is his. Cost: about half a day.

## 16. Upgrade tree look, pathing and cadence (16-upgrade-tree.md)
1. Write the 2-3x tree (b2-28) as rings per stage that grow larger outward. Today's tree thins from 11 to 6 to 5 to 1 nodes per stage, and it should grow instead. About 1 node in 4 is a verb, each evolution opens with a cheap burst of new nodes, and the pacing bot asserts 1-4 buys per visit and no more than 5 runs between verbs. Cost: 1-2 days of data plus half a day of bot checks.
2. Make buying an event, in presentation only: the node pops, the line lights up as it travels to newly opened nodes, they fade in, and the pitch rises per level. An evolution gets a flash and then the existing reveal. Cost: about 1 day.
3. Show the next step in full, nodes further out as silhouettes, and the next evolution as a landmark always in view. Drop the "branch" band and the role text (b2-24, b2-27). Cost: about half a day.

## 17. Lightning breath (17-lightning-breath.md)
1. Replace the straight core and curtain in `scenes/breath_beam.gd` with a forked bolt fan: one main channel that keeps its shape and side branches that re-randomise on each stroke, spread across the sim's BreathCone, all in one mesh rebuilt per stroke. Cost: about 1 day, under 500 vertices.
2. One stroke schedule (a dim feeler, then 2-3 bright strokes about 40-50 ms apart) drives the mouth light, the strike light and the zap, crackle and thunder sounds. `CityView.flash()` moves onto the light pool, which this branch does not have yet. Keep flashes under 3 a second and avoid saturated red. Cost: half a day plus 3 cleared sounds.
3. Each breath gets its own seed (`Seeds.make("breath_bolt", ...)`), never the sim RNG, so replays and captures repeat exactly. Cost: about 10 lines.

## 18. Graphics presets (18-graphics-presets.md)
1. Grow the existing `display.graphics` (`high`/`balanced` in `data/tuning.json`) to Potato/Low/Medium/High/Max, and give Medium 2x MSAA with FSR1 (today's `balanced` turns MSAA off under FSR1, which the docs advise against). Cost: data and schema only, under an hour.
2. Add shadow and effect settings to `PlayerSettings.apply_graphics`, all applied live: sun splits, shadow distance and size, PCSS off below High, SSAO/SSIL tiers, glow filter. Switching renderer needs a restart. Cost: about half a day plus captures.
3. Move the hard-coded caps (`MAX_DEBRIS`, `MAX_FIRES`, Jolt `live_cap`, crowd counts, particle ratio) into the preset rows, presentation only, so the sim never changes. Pick the default from GPU type plus a 4 s frame-time sample. Cost: about 1.5 days.

## 19. Camera per stage (19-camera.md)
The rest angle is already decided (D-105: framing C, offset (0, 16, 30), FOV 60). These cover what D-105 left open.
1. Move the zoom curve (`0.75 + 0.4 x scale`, hard-coded in `_place_camera`) into `data/tuning.json`, with a test that the kaiju's screen share rises each stage and stays at or under 35%. Cost: about 2 h.
2. Rebuild shake as trauma squared on smooth noise, rotation only with no roll, capped at 2-3 deg and scaled by stage, plus one "camera motion 0-100%" setting covering shake, the footstep dip and the breath swing. Cost: about half a day plus two clips.
3. Add look-ahead toward the stick direction (about 3 units at baby, 7.5 at adult, eased in after about 0.3 s of input), and start each run at last run's zoom and ease out (the Katamari beat, inside the intro). Cost: about half a day plus a clip. Framings to capture for his pick: A "today plus lead", B "grows on screen", C "low hero at adult".

## 20. Run intro and evolution reveal (20-set-pieces.md)
1. Retune the rise in `data/tuning.json` to end in 3 s or less, with a test that fails above 180 ticks. The rise from #113 runs in the sim and is estimated at 3.5-5.5 s, already over his 3 s. Cost: 1-2 h.
2. Drive the intro camera from the rise's own progress inside the existing `_place_camera`, easing from a low water shot to the play angle, with no Tween or addon. The sim keeps running the rise, which holds the clock, army and input; a skip runs the remaining ticks faster, so replays still match. Cost: about half a day plus one clip.
3. Roar when the head breaks the water, keep presses from the last 0.2 s for the first live tick (today they are dropped), and pace the evolution reveal by fixed ticks (today it counts frames: 3.8 s at 60 Hz, 1.6 s at 144 Hz). Cost: about 3 h.

## 21. Water that reacts to the kaiju (21-water.md)
Today the river is a flat, glossy sheet with no shader; the sim already emits every event the water needs.
1. River shader with up to 64 ripples from sim events and footfalls (vertex ripple field timed on the sim clock, same in both renderers), with a stepped, flat-shaded toon look and a flow scroll. Cost: about 1-1.5 days.
2. The rise and wading: a 19.47 deg wake V, a bulge before the head breaks the surface and foam around the body, all from the existing rise state. Cost: about half a day.
3. Cube-droplet splashes through the existing particle helper (crowns on stomps and impacts, sheets falling off the body during the rise), plus floating rubble bobbing on the same ripples. Cost: about 1 day.

## 22. Flung tanks and vehicles (22-flung-vehicles.md)
Today a throw is a 0.7 s timer with one blast where it lands: no flight-path check (thrown tanks pass through towers), a straight-line view and credit paid at the grab.
1. Arc the existing throw in the view (parabola, spin, squash, skid), sim unchanged. Cost: about half a day.
2. Make the throw a sim ballistic at fixed 60 Hz: swept hits against the voxel grid that carve through the existing code, credit at landing, pinned-seed tests and a sim review. Plain floats are deterministic enough within one build. Cost: about 2-3 days.
3. Turn the ram's instant move into a low launch, then add capped chain hits on tanks and helicopters as the upgrade hook. Jolt only throws the turret, the tracks and the dust, never the hull. Cost: about 2 days.

## Honest gaps
- **01:** No developer postmortems or cost tables. The timing targets come from one AI-assisted blog post, and the review themes from aggregators.
- **02:** These rest on fan wikis or a vendor page, or have no primary source: the Shin Godzilla heights, the GigaBash reasoning, haze as a scale tool and delayed sound. The legal notes are not legal advice.
- **03:** Three licence texts were not read: HY-Motion's, the licence on the UniRig/SkinTokens weights, and Tripo's terms for rig output. No source shows Tripo's creature-rig quality.
- **04:** No 2026 benchmark exists for LLMs modelling organic shapes. These licences were not checked: MagicaVoxel, vengi, nvdiffrast and the official Blender MCP. The local GPU's VRAM was not checked either.
- **05:** No mesher or threading benchmarks. The vertex-colour renderer difference comes from a commit mirror, not the live docs.
- **06:** No published timings for grid generators. No source explains how dense destructible voxel cities, CityV included, are generated.
- **07:** Several licences were not re-verified (Google Fonts, padadu packs 02 and 14, each godotshaders entry). No cleared CC0 voxel crowd pack and no free music stems were found.
- **08:** The voice caps and the dB and millisecond values are unsourced starting points. The "rubble stream" is an inference, not a shipped technique.
- **09:** The timing for a heavy tentacle and the helix wrap are design inferences. The primary papers were read only as abstracts.
- **10:** Jolt body counts come from vendor or anecdotal sources, so measure them on this PC. The incremental flood fill is an inference.
- **11:** The in-game cadence figures are estimates, because the mapping from units to metres was not verified. Item 1 measures them.
- **12:** No benchmark of light counts at 4K. Neither the fake beam in Compatibility nor HDR output per renderer has been tested.
- **13:** No source shows how shipped games handle limbs against buildings. The cell-read budget is arithmetic, not a profile.
- **14:** The twist threshold, the steps per 90 deg and the lag cap are inferences to tune from clips.
- **15:** No primary source for the HUD details of Shadow of the Colossus, Inside, Limbo, Metro or Teardown, nor for the in-run HUDs of Nodebuster, Astro Prospector and Chef Knight. The thesis and the Dead Space talk were read only through summaries. The 4K text height of the caps-only font is unmeasured, and the culprit behind the tooltip widening is inferred from code.
- **16:** No developer source on the tree screens of Nodebuster, Astro Prospector, Chef Knight or Brotato, and no cost tables. The Nodebuster node count (97) is my own count from a removed Steam guide. The tree-juice and fog techniques are design inference. The cadence table and target times are estimates for the pacing bot to verify. The required move from the 8 x 6 grid to a pannable map (50-65 nodes do not fit 48 cells) is a look decision for the director.
- **17:** The film and game examples were not sourced, and there are no 4K overdraw numbers. The halo colour is the director's call (3 labelled stills). Decal scorch marks do not render in gl_compatibility, which has no HDR glow, so the coloured halo must be geometry.
- **18:** No published per-setting millisecond costs for Godot at 4K, so they must be measured on the director's GPU. Godot cannot report total VRAM. `police.gd` was not checked for sim coupling, so police counts stay out of the presets.
- **19:** Eiserloh and Nesky were read second-hand. There are no primary camera specs for GigaBash, War of the Monsters or Godzilla PS4, and all per-stage numbers are estimates. Unchecked: whether a carved building still fades at its original full height.
- **20:** Sources for Hades, Rocket League, Shadow of the Colossus and the cutscene-skip guideline are thin or missing. The intro length is estimated from the tuning values, not measured.
- **21:** Every millisecond cost is an estimate, nothing measured on the director's GPU. Depth foam in gl_compatibility needs a different depth formula and is untested in the repo.
- **22:** The 50-unit cost is an unmeasured estimate and needs a fixed building lookup grid. Unconfirmed: whether `Engine.time_scale` changes the sim step, whether the ram can leave a tank inside a building, and the Rocket League claims (from a talk summary).
- **Where the files disagree:**
  - 03 leans on Godot's Skeleton3D IK nodes, but 09, 13 and 14 found the repo's rig has one node per bone, so those nodes would need a rig migration.
  - 14's fixes target `gait_biped.gd`, but 11 found that the reptilian walks on ClipGait. Check which code path runs before tuning.
