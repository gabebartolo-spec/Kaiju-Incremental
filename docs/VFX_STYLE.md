# Kaiju Evolution: VFX look sheet

Cap: 200 lines. Owner: the VFX lead (D-TBD-vfx-lead, 2026-10-23); changed by PR, reviewed by the lead.
The one canonical look for every effect family: what material, texture and particle setup defines it, its colour
ramp, its scale rules and the files that own it. Evidence: `docs/captures/2026-10-23-vfx/vfx_families.png` (every
family at the game camera, night and noon, from `tools/capture/capture_vfx_sheet.gd` + `vfx_sheet.py`).

## The rule above all
Director, 2026-10-22, on a fireball of opaque orange cubes that met every metric: "looks like minecraft fire...
and doesnt match the fire we use the rest of the time, consistency is absolutely key to avoid slop accusations".
- **One look per kind of thing.** Anything that burns is the game's Fire; anything that billows is the smoke
  shader; anything that sparks is the ember glow cube. A new effect reuses its family's owner (instance it, or call
  its recipe); it never writes a second shader, material or ramp for the same kind of thing.
- **Side by side before review.** Every new or changed effect is captured beside the existing member of its family,
  same camera, same zoom, night and noon (`capture_vfx_sheet.gd` plays every family at the game camera; add a shot
  for yours). No side-by-side, no review. The VFX lead reviews every effect before the lead sees it.
- **The read beats the metric.** Size, growth and fade numbers are necessary, never sufficient (rulebook: Art QC).

## Rules every family shares
- **Light:** Shader Cinematic (D-104): AgX tonemap, glow 1.0 with HDR threshold 0.9 (`data/looks.json`). Only
  things that give off light go above 0.9: flames, embers, sparks, flashes, beams, lit windows, lamps. Dust,
  smoke, debris and marks stay below it (they never bloom).
- **Never hide the kaiju (D-025):** glows are additive and thin; smoke clears near the camera, over the screen
  centre and in front of the kaiju (`smoke.gdshader`, D-018); nothing opaque stands between camera and body.
- **Voxel scale:** a family's voxels have ONE world size; a bigger effect has more voxels, never bigger ones
  (mixed voxel sizes are mixels: rulebook, automatic fail). Flame voxel 0.18 m drawn at 0.5-1.2x; ember 0.1 m;
  spark glow cube 0.12-0.22 m. The only exception is a fire seen from far off (the title), zoomed as a whole.
- **No UI colours in the world:** hazard yellow, alert red and UI near-black (`UiKit`) belong to the HUD and menus.
- **Numbers in data:** sizes, timings, colours and alphas live in `data/tuning.json` (hard rule 4); code holds a
  family's fixed identity (its ramp and shader) as named constants in the owner file, so consumers read them.
- **Presentation only:** effects read sim events and never decide outcomes (hard rule 3).

## The families

### 1. Fire: `scenes/fire.gd` (class Fire)
- **Defined by:** three GPUParticles3D systems and one flickering light. Flames: `BoxMesh` 0.18 m with
  `ember.gdshader` (unshaded, colour x heat 1.4 so the bloom catches it), rising (gravity +2.5, speed 0.8-2.0,
  spread 12 deg) from a box `size x 0.6` wide, life 1.0 s, 130 x size of them, scale 0.5-1.2 shrinking to 0.1.
  Embers: 0.1 m cubes, same shader, drifting on the run's wind, life 3.2 s. Smoke: family 2. Light: PooledLight
  `ff9a4a`, energy 2.5 + 1.2 x size with a two-sine flicker.
- **Colour ramp (Fire.FLAME_COLORS):** `fff0b8` at 0 -> `ff9a1e` at 0.1 -> `e04a0c` at 0.55 -> `3a1a10` at 1.0.
  Embers `ffe9a0` -> `ff6a1a`.
- **Scale:** `size` adds flames and light, not voxel size. Tongues rise; a fire never spreads flat.
- **Consumers:** CityView.fire (wrecks, crashes, thrown landings), CityView.burn_chunk (the beam's coat, fire
  spread R 26), the title's FarFire (whole fire zoomed for distance, claude/ui-redesign), the blast's fire
  (claude/city-explosives-v2). Stomp cracks glow `ff7a2a` (MOLTEN) inside the same hue range.
- **Rule:** a new burning thing instances Fire or builds from `Fire.EMBER_SHADER` + `Fire.FLAME_COLORS` at the
  flame voxel size. fire.gd is edited on three branches (fire-spread, ui-redesign, city-explosives-v2): merge one
  at a time and re-check the in-game fire is unchanged (same seed, same frame).

### 2. Smoke and gas: `scenes/smoke.gdshader`
- **Defined by:** camera-facing quads with a noisy round mask, lit dimly by the scene, colour and alpha from the
  particle (COLOR), soft edges; clears near the camera (8-22 m), over the screen centre (keeps 0.3) and in front
  of the kaiju (`smoke_focus`). Fire's column: 70 x size quads 1.0 x 1.7 tall, life 10 s, leaning with the wind.
- **Colour ramp:** charcoal, alpha 0 -> 0.46 at 0.08 -> 0.32 at 0.6 -> 0; rgb 0.05 -> 0.10 -> 0.20 -> 0.22.
- **Gas** (the chem lab's cloud, the Taskforce's blue-black gas, D-143) is smoke: this shader, tinted. Proposal,
  not yet ruled (the chem lab ships green cubes today: see "Two looks").
- **Finding:** at night the charcoal column is invisible against the sky, and faint at noon (sheet, `fire_far_smoke`); the
  director's title ask is "heavy smoke lit from below" (D-141). A fire-lit underside for the shared smoke is a
  follow-up for the lead to brief, not a title-only shader.

### 3. Dust: `scenes/fx.gd` (Fx.dust, footfall, puff, dust_line) on `smoke.gdshader`
- **Defined by:** the smoke shader's puffs in warm grey, one-shot bursts (explosiveness 0.9), growing 0.4 -> 1.6.
  Cloud ramp `(0.22, 0.24, 0.26, 0.47)` -> transparent; a topple passes the concrete's pale tint; footfalls are
  thinner and capped (`fx.footfall_dust`).
- **Rule:** every dust puff, cloud or ring of dust uses these calls. Dust is never solid cubes and never a flat sprite.

### 4. Debris: `scenes/debris_field.gd`, `carve_debris.gd`, `landmark_burst.gd`
- **Defined by:** solid, lit voxel cubes in the broken thing's own colours (carved slabs `8a8780`, D-101), real
  Jolt bodies for cosmetic pieces only (D-094), settling and crumbling away. The one family that is opaque cubes:
  they are pieces of the city.

### 5. Sparks and flashes: `scenes/fx_particles.gd` (FxParticles.sparks, glow_cube), `scenes/flare.gdshader`
- **Sparks:** ember-shader glow cubes, white-hot cooling to a tint, thrown fast (8-16), falling (gravity -18),
  shrinking to nothing; varied lifetimes. Breath strike, armour deflect (`cfe6ff`), leap trail and regen motes use it.
- **Flashes:** `flare.gdshader` (additive camera-facing core + halo + four short rays, `fade` driven) plus a real
  light (CityView.flash). Muzzle, strike, ready eye flare, deflect.

### 6. Electric / thunder: NOT BUILT
- D-108/D-112: the croc's signature is Lightning Breath (forked white-hot lightning, never "atomic"), its
  ultimate the Thunder Beam. Today the breath is still the orange "Atomic" plasma in the species eye colour
  `ff4a14` (`beam.gdshader` cylinder + `breath_curtain.gdshader` flame wall + flares, `breath_beam.gd`), and the
  ultimate is a solid emissive box (PowersView `_box`, `powers_view.gd:120`) that reads as a white slab from the
  side and is hidden behind the head at the game camera (sheet, BREATH, BEAM row).
- **Spec when built (ROADMAP b2-18, research 17):** one additive ribbon shader for every beam in the game: a
  white-hot core, a coloured halo (the halo colour is the director's open question R 17.6), 3-5 branches, at most
  3 flashes a second. The breath, the Thunder Beam and the Taskforce's railgun and gunship lasers all draw with it;
  only the tint differs by owner.

### 7. Ability rings and ground marks: `scenes/shockwave.gdshader`, `scenes/fx_decals.gd`, `claw_slash.gd`
- **Rings:** a soft band of street dust running out and fading (tint `(0.62, 0.58, 0.52)`, peak alpha 0.22, ragged
  front, no glow): "grounded-monster-film dust, not a UI ring" (Fx.shockwave, tuning `fx.shockwave`).
- **Marks:** projected decals (soot + cracks glowing in a tint, cooling over 60% of their life), never on the kaiju.
  Claw marks: additive unshaded streaks fanning along the rake arc (`claw_fx`).
- **Telegraphs:** BreathAim (`breath_aim.gd`): outline + middle line + faint fill (0.12) in the eye tint, gently
  pulsing, drawn over the city. The Taskforce's laser-bomb target rings (D-143) share this drawing in electric blue.

### 8. Taskforce blue energy: NOT BUILT (D-137/139/143/145)
- "Obsidian with Electric Blue highlights". One colour token for every Taskforce glow, defined once in
  `data/tuning.json` when PR 1 lands; nothing else in the game uses it (the kaiju's glows are warm or white).
- Railgun aiming line + hit, gunship laser: the beam ribbon of family 6, blue. Coils, jetpack exhausts and trails:
  family 5 glow cubes, blue. Gas: family 2 tinted blue-black. Frost: an ice crust of lit pale-blue voxels on the
  legs (a body material, cracking off as debris), with family-3 puffs tinted white. Laser-bomb rings: family 7
  telegraph. Bomb and mech blasts: family 9.

### 9. Explosions: base = CityView.flash + debris + Fire (TankFx.wreck); blasts on claude/city-explosives-v2
- **Canonical (being finished, review below):** the instant = family 5 (flare, real light, optional screen flash);
  the fireball = family 1's flame voxels at their own size, shader and heat, thrown up fast from the site and
  rising as tongues; then a real Fire left burning (its smoke); debris = family 4; the ground shock = family 3/7
  (shockwave band + dust puffs); fireworks = family 5 sparks in colours; gas = family 2.

### 10. Post effects (D-142, claude/post-fx, unmerged)
- A CanvasLayer under the HUD: a subtle vignette (red pulse below 25% health) and a 0.2 s colour fringe on the
  biggest hits and every railgun hit. No motion blur, film grain or lens dirt.

## Two looks today (flagged red on the sheet)
| family | canonical | second look | where | fix (owner) |
|---|---|---|---|---|
| dust | smoke-shader puff | flat radial sprite, tan | Fx.tree_puff (`fx.gd:141`) | smoke-shader puff that skips the centre clearing (follow-up) |
| ring | dust band shader | hazard-yellow torus | CityView.ring (tail sweep, ink), `city_view.gd:338` | Fx.shockwave (follow-up) |
| sparks | ember glow cube | plain unshaded cube, no bloom | Fx.sparks (shell hits, beam end) | FxParticles.sparks (follow-up) |
| fire | Fire's rising voxels | additive orange flame wall | breath_curtain.gdshader | goes with the lightning rework (b2-18) |
| beam | (none yet) | solid emissive box | Thunder Beam, `powers_view.gd:120` | ribbon shader (b2-18) |
| fire | Fire's voxels | big flat orange cube spray | blast fireball, city-explosives-v2 r8 | review FIX below |
| dust | smoke-shader puff | pale lit cubes | blast shock ring, city-explosives-v2 | review FIX below |
| gas/smoke | smoke shader | green lit cubes | chem lab cloud, city-explosives-v2 | proposal, lead's call |
| ember shader | `ember.gdshader` | `blast_ember.gdshader` (copy + fog off) | city-explosives-v2 | one shader for both |

## Review checklist (every effect, in writing, pass/fail/n.a.)
1. Which family? Does it reuse that family's owner (no new shader, material or ramp)?
2. Side by side with the existing member, same camera and zoom, night and noon: one look?
3. Voxel size equal to its family's; nothing UI-coloured in the world; bloom only on light sources.
4. Reads in under a second at the game camera (not only at 2x); kaiju never hidden; smoke clears per D-018.
5. Numbers in data; owner file named; shared files (fire.gd, fx.gd, smoke.gdshader) unchanged in-game when a
   consumer adds options (same-seed before/after still).
