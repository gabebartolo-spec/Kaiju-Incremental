# Kaiju Evolution: VFX look sheet

Cap: 200 lines. Owner: the VFX lead (director 2026-10-23; rulings D-151); changed by PR, reviewed by the lead.
The one canonical look for every effect family: what material, texture and particle setup defines it, its colour
ramp, its scale rules and the files that own it. Evidence: `docs/captures/2026-10-23-vfx/vfx_families.png` (every
family at the game camera, night and noon, from `tools/capture/capture_vfx_sheet.gd` + `vfx_sheet.py`).

## Three equal pillars (every effect passes all three, or it fails)
Director 2026-10-23: "for the game, 'good enough' isnt good enough, I have to love it". A SHIP from the VFX lead
means he will love it on all three; anything merely acceptable fails, with what would make it great.
1. **BEAUTY.** Genuinely gorgeous at game zoom on a 4K TV: rich colour, real light, motion and spectacle that makes
   the player want to cause more ("visual beauty is equally important"). A consistent but dull effect fails.
   Where the canonical effect is the weak one, raise the whole family together; never copy a weak look.
2. **CONSISTENCY.** One look per kind of thing ("consistency is absolutely key to avoid slop accusations", on a
   fireball of opaque orange cubes that met every metric). Anything that burns is the game's Fire, anything that
   billows the smoke shader, anything that sparks the ember glow cube. A new effect reuses its family's owner
   (instance it, or call its recipe); it never writes a second shader, material or ramp for the same thing. A
   beautiful effect in a clashing style fails.
3. **SCALE AND POWER.** "All the visual effects must make you feel like the Apex Predator, King of Monsters,
   Godkiller, Planetbreaker." Does it sell overwhelming size and force? Huge slow-rolling fireballs and dust walls,
   shockwaves rippling through whole blocks, debris raining for seconds, light flooding the city, the camera and
   audio answering every step, enemies tiny and doomed. Small, quick or polite fails.
   - **Enemies are prey** ("our enemies are many, but they ultimately are our prey"): Taskforce railguns, frost,
     gas, mechs, gunships and tanks read as a real threat that is small next to the kaiju: thin beams, tiny muzzle
     flashes, swarms. Their deaths feel like being swatted or crushed, never a fair duel.

**Method.** Every new or changed effect is captured beside the existing member of its family, same camera, same
zoom, night and noon (`capture_vfx_sheet.gd` plays every family at the game camera; add a shot for yours), and at
4K for the beauty read. No side-by-side, no review. Every effect passes the VFX lead before the lead sees it, and
the VFX lead's SHIP is final for effects (lead, 2026-10-23). Metrics are necessary, never sufficient.

## Visual direction (director, 12 answers, 2026-10-23; the lead logs them as D-n)
1. Fire is cinematic: deep orange-red flames, white-hot cores, heavy black smoke and embers (the reference video).
2. A rampage escalates: haze thickens and the sky glows orange from the fires; a late run looks like an inferno
   (the kaiju and streets stay readable).
3. A big collapse's dust wall may roll down the streets and swallow the camera for 2-3 s, clearing round the
   kaiju first (a deliberate exception to D-018's "smoke never hides the view").
4. Once large, a stomp's wave ripples through whole blocks: cars hop, windows burst, dust lifts, the camera thumps.
5. Big-collapse debris rains for 2-4 s (caps per graphics preset).
6. Rare split-second slow motion on the biggest moments only (landmark falls, a tower dropped on the army,
   evolutions); hit-stop skips sim steps, never Engine.time_scale (R 22.7).
7. Glass: windows burst into glittering shards that catch the light (a new small family, never alike to sparks).
8. Night blackouts spread: blocks round the damage go dark floor by floor; fires and the breath light the city.
9. Crushed people: a bloodless dust puff, never blood.
10. Enemy kills are mostly crushed, small pops (crumple, small fire, smoke puff; agents swatted); big fireballs stay
    special (explosive sites; D-140's helicopter break-ups keep their rule).
11. The croc's throat and spines crackle with white-hot lightning as the breath and Thunder Beam charge, stronger each
    evolution (never a blue "atomic" glow).
12. Taskforce energy is clean, precise tech: thin straight lines, crisp rings, a steady cold glow; never crackling
    like the croc's lightning.

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
  spread R 26), the title's FarFire (whole fire zoomed for distance, claude/ui-redesign; burning floors' windows
  turn fire-orange and the flames pour out of the openings, director 2026-10-23), the blast's fire
  (claude/city-explosives-v2). Stomp cracks glow `ff7a2a` (MOLTEN) inside the same hue range.
- **Rule:** a new burning thing instances Fire or builds from `Fire.EMBER_SHADER` + `Fire.FLAME_COLORS` at the
  flame voxel size. fire.gd is edited on three branches (fire-spread, ui-redesign, city-explosives-v2): merge one
  at a time and re-check the in-game fire is unchanged (same seed, same frame).

### 2. Smoke and gas: `scenes/smoke.gdshader`
- **Defined by:** camera-facing quads with a noisy round mask, lit dimly by the scene, colour and alpha from the
  particle (COLOR), soft edges; clears near the camera (8-22 m), over the screen centre (keeps 0.3) and in front
  of the kaiju (`smoke_focus`). Fire's column: 70 x size quads 1.0 x 1.7 tall, life 10 s, leaning with the wind.
- **Colour ramp:** charcoal, alpha 0 -> 0.46 at 0.08 -> 0.32 at 0.6 -> 0; rgb 0.05 -> 0.10 -> 0.20 -> 0.22.
- **Gas** (the chem lab's cloud, the Taskforce's blue-black gas, D-143) is smoke: this shader, tinted (director
  2026-10-23: "Soft tinted smoke"; the chem lab's green cubes are redone).
- **Lit from below, everywhere** (director 2026-10-23, after the sheet showed the charcoal column invisible at
  night and faint at noon, `fire_far_smoke`): every fire's smoke glows orange underneath, in game and on the title
  (D-141 "heavy smoke lit from below"), one shared change to this shader, never a title-only one.

### 3. Dust: `scenes/fx.gd` (Fx.dust, footfall, puff, dust_line) on `smoke.gdshader`
- **Defined by:** the smoke shader's puffs in warm grey, one-shot bursts (explosiveness 0.9), growing 0.4 -> 1.6.
  Every dust call (cloud, a person's puff, footfall and slam puffs, a tree's soil puff, the ring) is the street's
  own dust, `Fx.STREET_DUST` `8a6f4e` (`6a5238` at night), drawn in its own colour: `smoke.gdshader`'s `self_lit`
  moves the colour to emission and rounds the puff to a radial falloff (nothing at the quad's border), so night
  and noon match and the blue night ambient never tints it. One switch, `Fx.DUST_SELF_LIT`. Footfall puffs: 0.5 s
  at 0.5 opacity, about 150 px, at the toe, centre clearing off (D-018 does not thin a foot's own dust).
- A crushed tree's puff (`Fx.tree_puff`) is that dust, 2.4x the tree's size (about 120 px), 0.6 opacity, 0.5 s.
- **Rule:** every dust puff, cloud or ring of dust uses these calls. Dust is never solid cubes and never a flat sprite.

### 4. Debris: `scenes/debris_field.gd`, `carve_debris.gd`, `landmark_burst.gd`
- **Defined by:** solid, lit voxel cubes in the broken thing's own colours (carved slabs `8a8780`, D-101), real
  Jolt bodies for cosmetic pieces only (D-094), settling and crumbling away. The one family that is opaque cubes:
  they are pieces of the city.

### 5. Sparks and flashes: `scenes/fx_particles.gd` (FxParticles.sparks, glow_cube), `scenes/flare.gdshader`
- **Sparks:** ember-shader glow cubes (0.2 m for a shell hit), white-hot for the first 15% of life, then the tint
  (orange `SPARK_TINT` for shells and the breath's strike), dimming out; thrown fast (8-16) in a 35 degree upward
  cone, falling (gravity -18), shrinking to nothing; 28 per shell hit; varied lifetimes. Breath strike, armour
  deflect (`cfe6ff`), leap trail and regen motes use it.
- **Flashes:** `flare.gdshader` (additive camera-facing core + halo + four short rays, `fade` driven) plus a real
  light (CityView.flash). Muzzle, strike, ready eye flare (a gold four-point star on the eyes when the power
  charges). A deflect is a glance: one round soft white sprite (~60 px core, nothing at the quad's edge, no rays,
  lifted off the road, 0.12 s, a 1.0 light).

### 6. Electric / thunder: NOT BUILT
- D-108/D-112: the croc's signature is Lightning Breath (forked white-hot lightning, never "atomic"), its
  ultimate the Thunder Beam. Today the breath is still the orange "Atomic" plasma in the species eye colour
  `ff4a14` (`beam.gdshader` cylinder + `breath_curtain.gdshader` flame wall + flares, `breath_beam.gd`), and the
  ultimate is a solid emissive box (PowersView `_box`, `powers_view.gd:120`) that reads as a white slab from the
  side and is hidden behind the head at the game camera (sheet, BREATH, BEAM row).
- **In the M1 build** (director 2026-10-23), branch claude/thunder-beam. Build from
  `docs/research/2026-10-21/17-lightning-breath.md` (the recipe table and "For Kaiju Incremental" 1-4), plus:
  - **One beam shader for the game:** `bolt.gdshader` on an ImmediateMesh ribbon (core strip + wide halo strip,
    camera-facing in the vertex shader, additive, depth_draw_never). The breath, the Thunder Beam and later the
    Taskforce railgun and gunship lasers all draw with it; only width and tint differ by owner.
  - **Breath:** a dim feeler, then 2-3 bright strokes down one fixed main channel to `_first_hit`, 3-5 branches
    re-rolled per stroke fanning across the sim's BreathCone (never past it), at most 3 full flashes a second, no
    saturated red. Replaces the cylinder core AND the orange flame curtain (`breath_curtain.gdshader` goes).
  - **Thunder Beam (ultimate):** the same bolt held for the beam's seconds, its main channel re-struck on the
    stroke schedule as the head steers, branches lashing the buildings it crosses; replaces the solid box at
    `powers_view.gd:120`. It lights fires per D-129 through the existing coat.
  - **Power pillar:** the bolt is thick enough to read from the game camera behind the head (the body hides a thin
    one), its two pooled lights flood the street on each stroke (mouth + impact), the impact throws family-5 sparks
    and family-3 dust, a stroke kicks the camera through CameraShake, and a thunder layer sits under the first stroke.
  - **Colour:** white-hot core; the halo colour is the director's open question R 17.6: show 3 labelled 4K stills
    (hot amber / species-eye tint / white with a violet fringe) through the VFX lead, never agent taste.
  - Per-breath presentation seed (`Seeds.make("breath_bolt", ...)`), tunables in `data/tuning.json` fx.

### 7. Ability rings and ground marks: `scenes/shockwave.gdshader`, `scenes/fx_decals.gd`, `claw_slash.gd`
- **Rings:** a ring of street dust (`Fx.STREET_DUST`, unshaded, the same dust as a footfall) with a soil rim,
  about 35 px, brightest at the leading edge, a fill fading behind it and a small mound at the impact, out over
  0.55 s; blended by alpha only (peak 0.55), never darkened, multiplied or black: "grounded-monster-film dust,
  not a UI ring" (Fx.shockwave, tuning `fx.shockwave`). A stomp's ring is 3x its reach (`Fx.STOMP_RING`, about
  320 px for an adolescent); a tail sweep's ring spreads to the tail's reach (`Fx.shockwave_to`).
  (Fx.shockwave, tuning `fx.shockwave`). A tail sweep's ring spreads to the tail's reach (`Fx.shockwave_to`).
- **Marks:** projected decals (soot + cracks glowing in a tint, cooling over 60% of their life), never on the kaiju.
  Claw marks: additive unshaded streaks fanning along the rake arc (`claw_fx`).
- **Telegraphs:** BreathAim (`breath_aim.gd`): outline + middle line + faint fill (0.12) in the eye tint, gently
  pulsing, drawn over the city. The Taskforce's laser-bomb target rings (D-143) share this drawing in electric blue.

### 8. Taskforce blue energy: NOT BUILT (D-137/139/143/145)
- "Obsidian with Electric Blue highlights". ONE electric blue for every Taskforce glow, defined once in
  `data/tuning.json` when PR 1 lands; nothing else in the game uses blue (director 2026-10-23: "One blue, theirs
  only"; the armour-deflect flash `cfe6ff` moves to white). The kaiju's glows are warm or white.
- Railgun aiming line + hit, gunship laser: the beam ribbon of family 6, blue. Coils, jetpack exhausts and trails:
  family 5 glow cubes, blue. Gas: family 2 tinted blue-black. Frost: an ice crust of lit pale-blue voxels on the
  legs (a body material, cracking off as debris), with family-3 puffs tinted white. Laser-bomb rings: family 7
  telegraph. Bomb and mech blasts: family 9.

### 9. Explosions: base = CityView.flash + debris + Fire (TankFx.wreck); blasts on claude/city-explosives-v2
- **Canonical (director 2026-10-23: "Fire's tongues", "Same dust"):** the instant = family 5 (flare, real light,
  optional screen flash); the fire = a sudden tall burst of family 1's own rising flames (same voxel size, shader,
  heat and ramp), then a real Fire left burning with its smoke; debris = family 4; the ground shock = the same
  street dust as a stomp (family 3/7), never a special colour; fireworks = family 5 sparks in colours; gas =
  family 2. The same holds for Taskforce weapon hits.

### 10. Post effects (D-142, claude/post-fx, unmerged)
- A CanvasLayer under the HUD: a subtle vignette (red pulse below 25% health) and a 0.2 s colour fringe on the
  biggest hits and every railgun hit. No motion blur, film grain or lens dirt.

## Two looks today (flagged red on the sheet)
| family | canonical | second look | where | fix (owner) |
|---|---|---|---|---|
| dust | smoke-shader puff | flat radial sprite, tan | Fx.tree_puff (`fx.gd:141`) | smoke-shader puff that skips the centre clearing (fixed in #154, 2026-10-23) |
| ring | dust band shader | hazard-yellow torus | CityView.ring (tail sweep, ink), `city_view.gd:338` | Fx.shockwave (fixed in #154, 2026-10-23) |
| sparks | ember glow cube | plain unshaded cube, no bloom | Fx.sparks (shell hits, beam end) | FxParticles.sparks (fixed in #154, 2026-10-23) |
| fire | Fire's rising voxels | additive orange flame wall | breath_curtain.gdshader | goes with the lightning rework (b2-18) |
| beam | (none yet) | solid emissive box | Thunder Beam, `powers_view.gd:120` | ribbon shader (b2-18, in M1) |
| fire | Fire's voxels | big flat orange cube spray | blast fireball, city-explosives-v2 r8 | review FIX below |
| dust | smoke-shader puff | pale lit cubes | blast shock ring, city-explosives-v2 | review FIX below |
| gas/smoke | smoke shader | green lit cubes | chem lab cloud, city-explosives-v2 | tinted smoke (ruled 2026-10-23) |
| ember shader | `ember.gdshader` | `blast_ember.gdshader` (copy + fog off) | city-explosives-v2 | one shader for both |

## Review checklist (every effect, in writing, pass/fail/n.a.; verdict SHIP only if he will love it)
1. BEAUTY at 4K and game zoom: rich colour, real light, motion; would the player cause more to see it again?
2. CONSISTENCY: which family; reuses its owner (no new shader, material or ramp); side by side with the existing
   member, same camera and zoom, night and noon: one look; voxel size equal to its family's; no UI colours.
3. SCALE AND POWER: reads huge, heavy and slow enough to feel massive (not small, quick or polite); light floods,
   camera and audio answer; enemy effects small and their deaths swatted.
4. Reads in under a second at the game camera; kaiju never hidden; smoke clears per D-018; bloom only on light.
5. Numbers in data; owner file named; shared files (fire.gd, fx.gd, smoke.gdshader) unchanged in-game when a
   consumer adds options (same-seed before/after still).
