# Free, commercially usable assets for Kaiju Incremental (voxel kaiju city destruction), October 2026

Research only: no downloads, no sign-ups, no spend. "Verified" = licence read on the item's own page this session (2026-10-21). "Known, verify" = from prior knowledge or a secondary source; re-read the page before clearing it. Every item must be entered in `docs/LICENSING_REGISTER.md` as CLEARED before it enters `assets/` or `tools/` (CLAUDE.md hard rule 5).

## Key findings

1. **The CityV voxel look has only thin CC0 support; the strongest free voxel sources are padadu and Kytric on itch.io.** padadu's packs are CC0 `.vox` at a 32-voxel scale: urban street props (https://padadu.itch.io/voxel-pack-05-urban-city-assets) and modern warfare (tank, light tank, helicopter, jet, boat, submarine, trucks, jeep, ambulance; https://padadu.itch.io/voxel-pack-15-modern-warfare). Kytric's Voxel Vehicles is CC0 with 277 models in VOX/OBJ/glTF plus Godot demo scenes (https://kytric.itch.io/voxel-vehicles).
2. **No verified CC0 voxel citizen or crowd pack exists.** The best free one, kbrody's MEGA Voxel People Pack (20 characters, VOX/OBJ, "No generative AI was used"), states **no licence**, so it cannot be cleared as it stands (https://kbrody.itch.io/mega-voxel-people-pack-20-vox-style-3d-models). The one CC0 voxel figure found is a single soldier (https://opengameart.org/content/voxel-shock-trooper).
3. **maxparata (monogon) voxel packs are a trap.** Voxel Roads, Voxel Noir, Cyberpunk City and Dystopian Characters are CC BY-ND 4.0. Commercial use is allowed, but NoDerivatives bans modified versions, and recolouring, re-voxelising or splitting models into carve cells for destruction is modification (https://maxparata.itch.io/voxelroads, https://maxparata.itch.io/voxel-dystopian-characters).
4. **Kenney is CC0 for everything: "public domain licensed (CC0)… even in commercial projects… Attribution is not required"** (https://kenney.nl/support). But the City Kits, Car Kit and Blocky/Mini Characters are smooth low-poly, not voxel (https://kenney-assets.itch.io/car-kit). Next to voxel buildings they would read as mixed styles, which the director fails automatically.
5. **The Sonniss GDC bundle is the best big, layered destruction-SFX source under truly commercial terms.** Licence v2.0, effective 27 Aug 2026: commercial use with no attribution, unlimited projects. Bans: redistributing the files "as sound effects", reselling them as-is, and **any AI training** (https://sonniss.com/gdc-bundle-license/).
6. **godotshaders.com shaders are CC0, MIT or GPL-3.0, the author's choice** (https://godotshaders.com/license/). GPL-3.0 is a trap for a closed-source commercial game; take only CC0 or MIT entries.
7. **Kevin MacLeod (incompetech) music is free only with credit, and an attribution-free licence costs money** (https://incompetech.com/music/royalty-free/licenses/). The licence page did not show the CC version this session (known to be CC BY 4.0; verify).
8. **No free stems were found.** CC0 action/battle loops exist on OpenGameArt, e.g. "Determined Pursuit" (https://opengameart.org/content/determined-pursuit-epic-orchestra-loop), and some ship LMMS project files that could be split into layers.
9. **Godot 4 addons for juice are MIT.** Shaker (https://github.com/Eneskp3441/Shaker), Wallop Lite camera shake plus hit-stop (https://godotengine.org/asset-library/asset/edit/24609), Phantom Camera (https://github.com/ramokz/phantom-camera) and Resonate audio manager v2.4.1 by WidgitLabs (https://godotengine.org/asset-library/asset/4673). The original HugeMenace Resonate is deprecated.

## Category tables

Legend: Comm = commercial use OK; Attr = attribution required. Verified = read on the page this session.

### 1. Voxel city kits, props, buildings (style match first)

| Name | URL | Licence | Comm | Attr | Fit note |
|---|---|---|---|---|---|
| padadu Voxel pack 05: urban city assets | https://padadu.itch.io/voxel-pack-05-urban-city-assets | CC0 1.0 (verified) | yes | no | Benches, bins, traffic lights, cameras, road signs as true voxels. Best street-furniture match. Formats not listed (zip, 231 kB). |
| padadu Voxel Pack 14: 90s | https://padadu.itch.io/voxel-pack-14-90s | Unconfirmed (padadu packs are usually CC0; verify) | verify | verify | Possible extra street and household props, same voxel scale as 05. |
| padadu Voxel Pack 02: Nature | https://padadu.itch.io/voxel-pack-02-nature | Unconfirmed (verify) | verify | verify | Trees and animals for parks and edges, so no area is empty (director's no-empty-space rule). |
| Kenney Voxel Pack | https://kenney.nl/assets/voxel-pack | CC0 1.0 (Kenney-wide, verified on support page) | yes | no | Block textures and tiles. Useful as a palette or texture reference for voxel cells, not as buildings. |
| mehrasaur Voxel Buildings | https://mehrasaur.itch.io/voxel-buildings | **No licence stated** (commenter's question unanswered) | unknown | unknown | Right look (.vox/.obj buildings) but cannot be cleared without the author's written terms. |
| sermarsh Voxel Simple Modular City Models (80+) | https://sermarsh.itch.io/modularcitymodelsvoxel | Not seen (verify) | verify | verify | Modular voxel city. Check the licence before considering it. |
| PabloGameDev Isometric City Builder | https://pablogamedev.itch.io/isometric-voxel-city-builder | Custom: personal and commercial use, no redistribution (per search snippet; verify) | yes (verify) | verify | Voxel isometric buildings. Custom terms need a careful read before clearing. |
| Kenney City Kit (Commercial / Roads / Suburban / Industrial) | https://kenney.nl/assets/city-kit-commercial , https://kenney.nl/assets/city-kit-roads , https://kenney.nl/assets/city-kit-suburban , https://kenney.nl/assets/city-kit-industrial | CC0 1.0 | yes | no | **Style clash: smooth low-poly.** Use only as layout and blockout reference, or re-voxelise into game cells. |
| KayKit City Builder Bits (Kay Lousberg) | https://kaylousberg.com/game-assets | CC0 1.0 (known, verify per pack) | yes | no | **Style clash: low-poly toy look.** Reference only. |
| Quaternius city/building packs | https://quaternius.com | CC0 1.0 (known, verify per pack) | yes | no | **Style clash: low-poly.** Reference only. |

### 2. Vehicles (cars, tanks, helicopters, boats)

| Name | URL | Licence | Comm | Attr | Fit note |
|---|---|---|---|---|---|
| padadu Voxel Pack 15: modern warfare | https://padadu.itch.io/voxel-pack-15-modern-warfare | CC0 (verified: "100% free CC0"; "No credit needed") | yes | no | 11 `.vox`: tank, light tank, heli, jet, plane, boat, submarine, 2 trucks, jeep, ambulance. Covers the military response tier in one pack. |
| Kytric Voxel Vehicles | https://kytric.itch.io/voxel-vehicles | CC0 1.0 (verified) | yes | no | 277 buses, cars, racers, trains, trucks, trailers in VOX/OBJ/glTF with Godot demo scenes. Best civilian traffic match. |
| padadu Voxel pack 12: WWII tanks | https://padadu.itch.io/voxel-pack-12-wwii-tanks | CC0 (per description) | yes | no | Extra tank silhouettes. A WWII look may clash with a modern city; optional. |
| Odd1In Simple Voxel Art Vehicles | https://theodd1in.itch.io/vehicles | CC BY-SA 4.0 (per search snippet; verify) | yes | yes | Voxel road vehicles. ShareAlike makes edited versions carry BY-SA; acceptable but more paperwork than CC0. |
| OpenGameArt "3D vehicles under CC0" | https://opengameart.org/content/3d-vehicles-under-cc0 | CC0 (per title; verify) | yes | no | Unknown style. Check the look before considering it. |
| Kenney Car Kit | https://kenney-assets.itch.io/car-kit | CC0 1.0 | yes | no | 40+ cars, trucks, vans (OBJ/FBX/glTF). **Style clash: low-poly**; reference only. |
| maxparata Voxel Plane / Voxel Roads | https://maxparata.itch.io/voxel-plane , https://maxparata.itch.io/voxelroads | CC BY-ND 4.0 | yes | credit requested | **Trap (ND):** cannot be modified or carved. |
| Mo Enen Voxel Vehicle Collection Vol 5 | https://m-oenen.itch.io/voxel-vehicle-models-enen-collection-vol5 | Paid ($9.99) | n/a | n/a | Not free. Excluded (spend needs the director's yes). |

### 3. People (tiny crowd figures)

| Name | URL | Licence | Comm | Attr | Fit note |
|---|---|---|---|---|---|
| Voxel Shock Trooper (OGA) | https://opengameart.org/content/voxel-shock-trooper | CC0 (per snippet; verify) | yes | no | Single soldier with .vox, usable for the army tier only. |
| kbrody MEGA Voxel People Pack (20) | https://kbrody.itch.io/mega-voxel-people-pack-20-vox-style-3d-models | **No licence stated** (verified) | unknown | unknown | Ideal look (VOX/OBJ/BLEND, no AI). Cannot be cleared unless the author publishes CC0 or similar. |
| a7nawy 5 Voxel People Pack | https://a7nawy.itch.io/5-voxel-people-pack | Not seen (verify) | verify | verify | Only 5 figures. Check the licence. |
| Kenney Mini Characters / Blocky Characters | https://kenney.nl/assets/mini-characters , https://opengameart.org/content/blocky-characters | CC0 1.0 | yes | no | Rigged blocky low-poly with 27 animations. Mixed-style risk next to voxels; at crowd scale (a few px tall) it may pass. Needs a critic check. |
| maxparata Voxel Dystopian Characters | https://maxparata.itch.io/voxel-dystopian-characters | CC BY-ND 4.0 | yes | yes | **Trap (ND).** |
| netovoxel VOXEL WORKERS | https://netovoxel.itch.io/voxelworkers | Paid; PNGs "generated using cutting-edge AI" (per snippet) | n/a | n/a | **Trap:** AI provenance, 2D PNG, paid. |

### 4. SFX (explosions, concrete, glass, metal, screams, sirens, roars, footsteps, water)

| Name | URL | Licence | Comm | Attr | Fit note |
|---|---|---|---|---|---|
| Sonniss GDC Game Audio Bundle (all years) | https://gdc.sonniss.com , terms https://sonniss.com/gdc-bundle-license/ | Sonniss royalty-free "Unlimited User License" v2.0 (verified) | yes | no | Tens of GB of pro destruction, debris, glass, metal, vehicle, crowd and creature layers. **No redistribution as SFX, no resale as-is, no AI training.** Fine inside a shipped game. Licence version = the one in force on the download date. |
| Kenney Impact Sounds | https://kenney.nl/assets/impact-sounds | CC0 1.0 | yes | no | Short hits and thuds for small debris and UI. Too light for building collapse on its own. |
| Kenney Sci-Fi Sounds | https://opengameart.org/content/sci-fi-sounds | CC0 1.0 | yes | no | 70 OGG with explosions and engines. Useful layers for the kaiju's beam or ability. |
| Freesound (per sound) | https://freesound.org | Per sound: CC0, CC BY 4.0, or **CC BY-NC 4.0 (banned)** | CC0/BY yes; NC no | BY: yes | Best source for sirens, crowd screams, roars, water. Filter each sound to CC0, log every sound's ID and licence; never take NC. |
| OpenGameArt sound effects | https://opengameart.org/art-search-advanced?field_art_type_tid%5B%5D=13 | Per item (CC0, CC-BY, GPL, NC appear) | per item | per item | Check each item. A CC0 destruction pack was not found in this pass. |
| 50 CC0 sci-fi SFX (OGA) | https://opengameart.org/content/50-cc0-sci-fi-sfx | CC0 (per title; verify) | yes | no | Extra power or ability layers. |

### 5. Music (action, adaptive, stems)

| Name | URL | Licence | Comm | Attr | Fit note |
|---|---|---|---|---|---|
| "Determined Pursuit" (Emma_MA) | https://opengameart.org/content/determined-pursuit-epic-orchestra-loop | CC0 (per page, public domain) | yes | no | Loopable epic orchestral battle loop; suits a rampage climax. |
| "Fast fight / battle music" (Ville Nousiainen) | https://opengameart.org/content/fast-fight-battle-music | CC0 (per snippet; verify) | yes | no (optional credit asked) | Fast, driving combat track. |
| drakzlin simple game loops (action / battle zips) | https://opengameart.org/node/83163 | CC0 (per snippet; verify which node) | yes | no | Short loops for wave intensity layers. |
| "Short Battle Loop" (Some Weirdo) | https://opengameart.org/node/184242 | CC0 (per snippet; verify node) | yes | no | Includes the LMMS project, so stems could be exported from the project file. |
| Kevin MacLeod / incompetech | https://incompetech.com/music/royalty-free/licenses/ | CC BY (version known as 4.0; verify) | yes | **yes** (generated credit) | Large action catalogue. Credits screen needed; an attribution-free licence is paid (excluded). |
| Juhani Junkala chiptune/action packs (OGA) | https://opengameart.org/users/juhani-junkala | CC0 (known, verify) | yes | no | Chiptune; may clash with a cinematic destruction tone. Optional. |

### 6. Fonts (bold UI, readable at 24 px base on a 4K TV)

| Name | URL | Licence | Comm | Attr | Fit note |
|---|---|---|---|---|---|
| Bungee | https://fonts.google.com/specimen/Bungee | OFL 1.1 (known, verify) | yes | no (keep OFL text with the font) | Chunky blocky display face that echoes voxels. Headlines, damage counters. |
| Lilita One | https://fonts.google.com/specimen/Lilita+One | OFL 1.1 (known, verify) | yes | no | Rounded heavy arcade face. Big numbers. |
| Russo One | https://fonts.google.com/specimen/Russo+One | OFL 1.1 (known, verify) | yes | no | Squared military-tech look; fits the army-response HUD. |
| Black Ops One | https://fonts.google.com/specimen/Black+Ops+One | OFL 1.1 (known, verify) | yes | no | Stencil impact face. Use sparingly for titles. |
| Anton | https://fonts.google.com/specimen/Anton | OFL 1.1 (known, verify) | yes | no | Condensed impact headline, "RAMPAGE!" banners. |
| Bebas Neue | https://fonts.google.com/specimen/Bebas+Neue | OFL 1.1 (known, verify) | yes | no | Clean condensed caps; all-caps only, weak for body text. |
| Barlow / Barlow Semi Condensed | https://fonts.google.com/specimen/Barlow | OFL 1.1 (known, verify) | yes | no | Highly readable body and UI text at 24 px; pairs with any display face above. |
| Luckiest Guy | https://fonts.google.com/specimen/Luckiest+Guy | Apache 2.0 (known, verify) | yes | no (keep licence) | Comic-book punch for "SMASH" pops. |
| Kenney Fonts | https://kenney.nl/assets/kenney-fonts | CC0 1.0 | yes | no | Blocky pixel-ish faces. Small UI only; check at 4K. |

### 7. Shaders

| Name | URL | Licence | Comm | Attr | Fit note |
|---|---|---|---|---|---|
| Godot built-ins (toon diffuse/specular modes, next_pass outline, fog, glow, SSAO, decals, GPUParticles3D) | https://docs.godotengine.org/en/stable/tutorials/3d/standard_material_3d.html | MIT (engine) | yes | engine notice in credits | Simplest viable option: toon shading plus a grow-outline next_pass covers most of the look with no third-party file. |
| godotshaders.com outline shaders | https://godotshaders.com/shader-tag/outline/ | CC0 / MIT / **GPL-3.0** per shader (verified site policy) | CC0/MIT yes; GPL avoid | MIT: keep notice | Pick CC0 or MIT entries only and record each shader's own licence. |
| godotshaders.com toon shaders | https://godotshaders.com/shader-tag/toon/ | as above | as above | as above | Cel bands for voxel faces. Check each works in gl_compatibility. |
| godotshaders.com water shaders | https://godotshaders.com/shader-tag/water/ | as above | as above | as above | Harbour and the kaiju's water entry (the kaiju now rises from water, #113). Stylised, not realistic. |
| godotshaders.com post-process (vignette, chromatic, screen shake distortion) | https://godotshaders.com/shader-tag/post-processing/ | as above | as above | as above | Impact frames. Keep subtle at 4K. |
| Kenney Particle Pack | https://kenney.nl/assets/particle-pack | CC0 1.0 | yes | no | Smoke, dust, spark and flash sprites for dust/smoke billboards. |
| OGA small explosion sets | https://opengameart.org/content/small-explosion-set-exload0110png | CC0 (per snippet) | yes | no | Flash billboards for explosions. |
| ambientCG | https://ambientcg.com | CC0 1.0 (known, verify) | yes | no | Concrete, asphalt, glass textures. Mostly irrelevant to flat voxel colours; ground or water normal maps only. |
| Poly Haven | https://polyhaven.com/license | CC0 1.0 (known, verify) | yes | no | HDRIs for sky lighting; textures as above. |

### 8. Godot 4 addons

| Name | URL | Licence | Comm | Attr | Fit note |
|---|---|---|---|---|---|
| Shaker (Eneskp3441) | https://github.com/Eneskp3441/Shaker | MIT (asset library listing) | yes | keep MIT notice | Shakes any node (camera, UI, buildings). Listing targets 4.2; test on 4.7.2. |
| Wallop Lite: camera shake and hit-stop | https://godotengine.org/asset-library/asset/edit/24609 | MIT (listing) | yes | keep MIT notice | Trauma-based shake plus hit-stop, listed as tested on 4.7.1. Closest to our engine; repo URL not seen. |
| Camera Shake 3D (JoeDigital9) | https://github.com/JoeDigital9/CameraShake3D | MIT (listing) | yes | keep MIT notice | Tiny 3D-only shake; easy to read and vendor. |
| Phantom Camera | https://github.com/ramokz/phantom-camera | MIT (listing) | yes | keep MIT notice | Camera framing and follow; noise/shake support known, verify. Larger dependency. |
| Resonate (WidgitLabs) | https://godotengine.org/asset-library/asset/4673 | MIT (listing) | yes | keep MIT notice | Pooled SFX players, polyphony, stemmed music, crossfades. The HugeMenace original is deprecated. |
| Godot Sound Manager (Nathan Hoad) | https://github.com/nathanhoad/godot_sound_manager | MIT (known, verify) | yes | keep MIT notice | Simpler autoload for SFX and music. Counts against the fixed autoload list (game-architecture). |
| godot_voxel (Zylann) | https://github.com/Zylann/godot_voxel | MIT (known, verify) | yes | keep MIT notice | Full voxel engine. Likely redundant with our own D-094 carving; reference only. |

## Traps to avoid

- **CC BY-ND (maxparata/monogon):** commercial OK but no derivatives, which conflicts with carving, recolouring and re-voxelising (https://maxparata.itch.io/voxelroads).
- **"Free" with no licence (kbrody, mehrasaur, many itch "name your price" pages):** no licence means no permission. Only an explicit CC0, CC-BY or MIT clause clears an item (https://kbrody.itch.io/mega-voxel-people-pack-20-vox-style-3d-models).
- **GPL-3.0 shaders on godotshaders.com:** viral copyleft on a commercial closed game (https://godotshaders.com/license/).
- **Freesound CC BY-NC sounds** sit next to CC0 ones in the same search results; filter every sound (https://freesound.org).
- **Sonniss terms change by version:** v2.0 (27 Aug 2026) adds an AI-training ban and no redistribution as SFX. Never commit raw Sonniss files to a public repo, since that counts as redistribution (https://sonniss.com/gdc-bundle-license/).
- **AI-generated "voxel" packs** (e.g. netovoxel VOXEL WORKERS, "generated using cutting-edge AI") have unclear provenance and are often 2D PNG (https://netovoxel.itch.io/voxelworkers).
- **Paid-attribution-removal music** (incompetech): free means credit is mandatory, and the paid route needs the director's yes (https://incompetech.com/music/royalty-free/licenses/).
- **Known from prior knowledge, verify:** BBC Sound Effects (RemArc) is non-commercial only, so banned. Pixabay and Zapsplat "free" tiers carry custom terms (Zapsplat's free tier needs attribution; both bar standalone redistribution) and have mixed uploader provenance; treat as not cleared without a full read.
- **Low-poly kits (Kenney City/Car Kit, KayKit, Quaternius)** are licence-safe but **style-unsafe**: smooth low-poly beside voxel buildings is the 3D equivalent of mixels.
- **Voxel density mismatch:** padadu (about 32-voxel models) and Kytric vehicles are built at different voxel sizes. Mixing them unscaled gives two voxel grids in one frame, which is also a mixel failure. Re-voxelise everything to the game's cell size.

## Sources

- https://kenney.nl/support (Kenney CC0 wording)
- https://kenney-assets.itch.io/car-kit
- https://opengameart.org/content/blocky-characters
- https://padadu.itch.io (pack index)
- https://padadu.itch.io/voxel-pack-05-urban-city-assets
- https://padadu.itch.io/voxel-pack-15-modern-warfare
- https://padadu.itch.io/voxel-pack-12-wwii-tanks
- https://kytric.itch.io/voxel-vehicles
- https://kbrody.itch.io/mega-voxel-people-pack-20-vox-style-3d-models
- https://maxparata.itch.io/voxelroads , https://maxparata.itch.io/voxel-dystopian-characters
- https://theodd1in.itch.io/vehicles
- https://opengameart.org/content/voxel-shock-trooper
- https://netovoxel.itch.io/voxelworkers
- https://sonniss.com/gdc-bundle-license/
- https://opengameart.org/content/sci-fi-sounds
- https://incompetech.com/music/royalty-free/licenses/
- https://opengameart.org/content/determined-pursuit-epic-orchestra-loop , https://opengameart.org/content/fast-fight-battle-music
- https://godotshaders.com/license/
- https://github.com/Eneskp3441/Shaker , https://godotengine.org/asset-library/asset/edit/24609 , https://github.com/JoeDigital9/CameraShake3D
- https://github.com/ramokz/phantom-camera
- https://godotengine.org/asset-library/asset/4673 (Resonate, WidgitLabs)

## For Kaiju Incremental: ranked recommendations (simplest viable first)

Each item enters `docs/LICENSING_REGISTER.md` as CLEARED (name, URL, exact licence, download date, attribution text if any) before it touches `assets/` or `tools/`. All cost $0; the costs below are effort and risk.

1. **Godot built-in toon shading plus a next_pass outline, and Kenney Particle Pack for dust and smoke.** Cost: about half a day; no new dependency; CC0/MIT. Gives the arcade look before any third-party shader.
2. **One shake and hit-stop addon: Wallop Lite (tested on 4.7.1), or vendor the tiny Camera Shake 3D.** Cost: under an hour plus an MIT notice in credits. Alternative: write about 40 lines of trauma shake ourselves, which has zero licence cost and suits our "fewer files" rule.
3. **Sonniss GDC bundle as the destruction SFX base, with Freesound CC0 for sirens, screams and roar layers.** Cost: hours of curating; large local files kept out of any public repo; register each file used. Strongest commercially clean audio found. Kenney Impact/Sci-Fi Sounds (CC0) fill small hits.
4. **Fonts: Bungee or Lilita One for display, Barlow for body (OFL 1.1).** Cost: minutes; ship the OFL.txt beside each font; capture at 4K with a 24 px base before the director sees it.
5. **Vehicles: padadu Pack 15 (military, CC0) plus Kytric Voxel Vehicles (civilian, CC0), re-voxelised to the game's cell size.** Cost: about a day of import and scale normalising; needs a critic pass for voxel-density mixels. Ask the director only for taste once it is defect-free.
6. **Street props: padadu Pack 05 (CC0), re-voxelised the same way.** Cost: a few hours. Fills streets so there is no empty space.
7. **People: make a tiny crowd set ourselves in MagicaVoxel (6-10 figures, 2-4 colours), or ask kbrody for a CC0 statement in writing.** Cost: about a day in-house; there is no cleared free voxel crowd. Kenney Blocky Characters (CC0) are a fallback only if a critic passes them at crowd scale.
8. **Music: CC0 OGA loops ("Determined Pursuit", "Fast fight"), layered by intensity with Resonate's stem and crossfade support.** Cost: hours. Kevin MacLeod only if a credits line is acceptable. True free stems were not found, so adaptive music means exporting layers from LMMS projects or commissioning later (spend: director's yes).
9. **Buildings: keep procedural voxel buildings from our own carving system (D-094).** No free voxel building kit cleared. Use Kenney City Kits only as layout reference, never as in-game meshes.

**Evidence gaps:** Not re-verified on their pages this session: Google Fonts licences, ambientCG and Poly Haven terms, Kevin MacLeod's CC version, Kenney Mini Characters and Particle Pack pages, Nathan Hoad's Sound Manager, godot_voxel, MagicaVoxel's tool licence, BBC/Pixabay/Zapsplat terms, and padadu packs 02 and 14. Specific godotshaders entries were not opened, so each shader's own licence is unchecked. Wallop Lite's repo URL was not seen. No CC0 voxel crowd pack or free music stems were found.
