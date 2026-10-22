# Kaiju Incremental: design

The one design document. Every agent reads it in full before work. It says what the game IS today; how and when
things get built is `docs/ROADMAP.md`, why each ruling was made is `docs/DECISIONS.md` (D-n). Cap 200 lines. Edited
only by the lead when the director rules; replace the old line, never append history. Quotes are the director's.

## Pillar
**You are the disaster: every rampage must feel bigger than the last.** A system that does not change what the player
sees, decides or remembers is cut, not polished. A thrill, never a chore: "the game isnt meant to be extremely challenging or frustrating" (D-118). Designed by the director; agents execute and push back.

## The game
- An **active action game** with incremental progression, the Nodebuster / Brotato shape. No idle, no AFK, no offline
  gains, no clicker framing; progress only from playing. Authored pacing, **3-5 hours** to the end (D-002).
- **Loop:** a short rampage (40 s to a few minutes; ends on the clock, the army or the city falling) -> devour
  **biomass** from everything you flatten ("it devours what it flattens; evolving is growing", D-056; never "rubble"
  as a currency) -> buy nodes on the evolution tree -> rampage again, bigger (D-003).
- **Controls:** move; stomps fire on their own (0.7 s rhythm); one signature button; the ultimate on its own button
  (E / pad Y, long cooldown); dash (Shift / B). Keyboard and controller, readable on a TV (D-004, D-040).
- **Platform:** PC, a 4K 120 Hz TV (RTX 4070 SUPER), fullscreen from code in exports, UI a 1920x1080 canvas at 2x
  (D-027). Godot 4.7.2.
- **Not:** a clicker, idle, infinite exponential numbers, a city builder, a Godzilla copy.

## The kaiju
- Three species, picked at the start, one per save; each plays differently, not just looks different (D-006, D-035).
  Every power below is a **node in that species' branch of the tree**, the ultimate at its end: "this is an
  incremental, not a kaiju simulator" (D-037).
- **Reptilian, the croc titan: strongest, a living battering ram.** "A crocodile in a t-rex body, not godzilla
  shaped" (D-108): croc snout, pale flat bone scutes, charcoal spines, short reptilian arms, long low tail, ~20-30
  deg lean, graceful like a JP T-rex (D-031, D-046, D-048). Kit: claw swipe raking ahead every 2 s that undermines
  towers (D-095, D-096); tail as an autonomous extra limb that shears buildings (a tree node, b2-2); momentum
  (straight lines hit harder, turning bleeds it); dash (bursts through every building in its path, landmarks too, a kick per wall, #34). Signature: a breath of **hot forked white-hot lightning**,
  never "atomic" (D-108); its ultimate is a long sustained beam swept by steering.
- **Insectoid, the mantis: fast, and the brood mother.** Its identity: it **lays eggs that hatch elephant-sized
  young which run through the city on their own, destroying, devouring civilians and fighting the military**
  (director 2026-10-21; seeded autonomous minions, capped count). Two raptorial arms plus four legs, dark chitin,
  red eyes, rusty scythe tips (D-022, D-038). Movement kit: scuttle (fastest, sharp turns), leap with hold-to-glide,
  climbs towers and tips them from the top (D-037).
- **Cephalopod: the most cunning, a hydra of limbs.** Adult = 10+ barnacled tentacles (D-036). Kit: 360 deg limb
  attacks, each limb picking its own target; grab and throw tanks, cars and helicopters (a thrown tank explodes like
  a grenade); pulls itself along building edges, climbs, squeezes through gaps. Ultimate: corrosive ink that
  dissolves coated buildings and units. Slides and grabs, never tip-toes (D-031). Swims fast in water and can dive to dodge the army, bursting out under buildings; one of the 3 cities is a water city (D-123).
- **Growth:** baby (start, a toddler: slow, outscaled by the city) -> adolescent (EVOLVE 1, lanky, oversized feet,
  half-grown feature) -> adult (EVOLVE 2+, massive). Each stage a new body plan like Simba's, never only bigger
  (D-009, D-014, D-074). Body scale grows with every upgrade owned. No building is too strong for the baby; big ones
  just take longer (D-091). The reveal is titled by the node bought (BEHEMOTH), with the roar (D-051, D-055).
- **Motion:** terrifying monsters, not toys (D-013). Turns with weight, "lumbering and unstoppable" yet responsive:
  bigger turns slower "but not TOO slow" (#31), the head leads, the legs step the turn, never a sliding pivot or "swivelling on the spot like a plastic toy";
  shoulders and head move as it walks (comments 2026-10-20 #16, 2026-10-21 #3/#4). Physics on tails, limbs and
  antennae (D-015). Croc clips come from Blender, layered over procedural foot planting (D-047).
- **Body vs world:** the kaiju never clips through anything: walking into buildings, rubble or a falling tower
  breaks it (D-091, D-110, comments #24). A tower that falls on him breaks believably at the contact, large pieces
  folding off him, "not turned instantly to dust" (#25). A fallen building breaks
  against the ground into rubble, never disappears into it: each section shatters as it hits the ground, in
  sequence, base to top; nothing slides away whole (#26, #30).
- **Models:** Tripo designs, hand-rigged in Blender with welded weights, rendered as voxel cubes on a smooth skinned
  lattice (D-041, D-045). The kaiju gets double voxels per axis, the city keeps today's size (D-107). Mantis and
  octopus meshes kept; their game-ready plan is `docs/superpowers/plans/2026-10-18-mantis-octopus-game-ready.md`,
  plan only (D-060).

## The city
- Voxel, Look C "Concrete Realism", real structures with recessed framed facades and rooftop clutter, matching the
  kaiju's fidelity (D-005, D-008, D-028). Target look: `WATCH THIS.mp4` (repo root, untracked) 120-168 s and
  590-680 s: chewed buildings with ragged holes, tiny-voxel debris streams, thick smoke, glowing embers, haze. Reads as a real city with believable edges, not a grid in a void (D-024).
- **No vast empty spaces:** every cell the camera shows holds something to smash or kill (D-062). A believable amount
  of greenery, all crushable; green lots 8% (D-065, D-075). Civilians and moving traffic (D-019). Zebra crossings only
  at the central junction (D-054). Every building in the play area is destroyable (b2-6). A quiet row of bollards
  marks the edge (#18).
- **The city grows with each evolution:** more districts, taller towers, harder defences (D-039).
- **Start:** the kaiju rises out of the river water facing the city, from a wider bay onto a small shoreline, and
  walks straight in (#10, #17); where a bridge deck sits over the rise he bursts up through it and breaks it
  (director 2026-10-21); the bay fits the stage's biggest possible body (director 2026-10-21). Bridges always meet the land (#12). Nothing in the foreground hides the rise (#27).
- **Landmarks:** stadium, wheel, spire, megatower, in that order (D-071). The stadium plays one random sport per run
  (AFL, NFL, soccer, cricket), full stands; players flee; the crowd is killable, thins over time and falls with a
  broken stand, never vanishes or dangles (D-078, D-078a, b2-8, #17). It sits far from the spawn (b2-21); bonus 1.5x
  (D-090), other landmarks 4x (D-081).
- **Explosive sites, the "red barrel":** fuel silos, fireworks factories, chemical labs; any damage (the kaiju,
  rubble, a stray army shell) arms them; blasts carve and chain. Really good SFX and VFX: a shockwave ring, air
  distortion, a sonic boom delayed by distance (#19, #20).
- **Fire:** a destroyed building stays rubble, never a burning shell (#14). Fire returns as gameplay: a tree node lets
  fire spread building to building on its own, burn-outs pay biomass, fires light the city (#15; rules in research 26).
- Real OSM cities (D-029) are tabled. A background kaiju rampaging in the far skyline is a prototype for his yes (#16).

## Destruction
- **Real carving and physics, top priority:** Teardown-style fine sim voxels, islands fall, RFG-style support and
  topple, a C++ core; Jolt for cosmetic debris only, never an outcome (D-094, D-097). "A building shouldnt have a
  health bar, it should be a physical structure which obeys the laws of physics and simply must be dismantled",
  effortless even for a baby (b2-4).
- Towers fall toward the side that was cut, even onto the kaiju (D-099), with more varied directions (b2-5). Carved
  slabs colour 8a8780 (D-101). Shared walls carry real facades (b2-22). Fallen slabs are destructible (D-110).
- Smoke never hides the view: clear near the camera, thinned over the kaiju (D-025, D-018).

## The army
- A professional military, escalating gradually: "a city caught unaware" at the start, faster spawns the more you
  destroy, scaling inside each stage so defeat stays possible (D-066, D-069, playtest 11).
- **Clumsy, not perfect:** tanks miss, run over cars and sometimes blow up their own city (#9, #18).
- Tanks and helicopters, 2x real size, desert tan (D-042); tanks get shoved and flung into buildings, people and
  vehicles, never whittled like a health bar (b2-9). Rooftop squads of armed citizens fire raggedly, never in unison,
  for chip damage (D-063, D-076, D-085). Four jet types; strikes wreck buildings but pay no biomass; the warning scales
  with kaiju size (D-072, D-080). Later: rooftop mortars, then a mecha boss finale (ROADMAP H).

## Progression
- The tree is the spine: per species, grown to 2-3x today's nodes, an upgrade affordable after every rampage, steady
  cadence (never 1 -> 8 -> 1 buys), first evolution at about 15 min (b2-28, D-087, D-098). Costs live in data.
- The stats panel shows only what the selected node changes, in plain words (D-077).
- **Copy rule for all player text:** short and playful, no mechanics explained, no internal names ("branch",
  "capstone", "floors" as a unit); the player smashes, buys, smashes more (b2-15/16/17/24/27).
- **Demo** (D-050): the croc only, hatchling to Behemoth, ends on a "demo complete" card.

## Look, camera, screen
- **Shader Cinematic** (heavy AO, contrast 1.3, saturation 0.9, bloom on fire, no crease edges, D-104; replaces
  D-057/D-068). Real light sources: lamps, lit windows, fires, muzzle flashes, explosion and breath light (D-010).
  Time of day is random per run (dusk, night, morning, noon), with an options toggle to fix one; morning less hazy, night lighter (D-106, D-145).
- **Camera C**, low and cinematic, sees to the skyline (D-105); how it grows per stage is still his pick (R 19). Run
  intro: a 3 s shot of the water rippling, the kaiju bursting out roaring, the camera pulling out (#11). Water reacts
  to the kaiju (#12). Shake: smooth trauma, rotation only, one camera-motion setting.
- **UI look A "Emergency Broadcast"** on every screen: hazard yellow, alert red, near-black, hazard tape, square edges,
  news crawl; fonts Kaiju Claw (headings) and Kaiju Block (body), ours (D-061, D-021, D-058). Bespoke original UI
  assets (b2-14).
- **Minimal HUD:** the boxed timer at the top; biomass a boxless figure bottom right; breath cooldown an icon with a
  circular fill; health bar removed or repurposed; controls shown once and in a controls menu; fixed tooltip width;
  species select with the kaiju centred (b2-10..13, b2-23, b2-11). Text 24 px or more at 1080p.
- **Graphics:** presets Potato / Low / Medium / High / Max; 4K default Medium at 60 fps (D-093, D-109). Looks
  first, performance after the visuals are final (D-032, b2-25).

## Audio
- SFX from ElevenLabs Starter (owned) and CC0 / free libraries, synthesized in-house where better; every source CLEARED
  in `docs/LICENSING_REGISTER.md` (D-030, D-092). Suno Pro music only after his written spend yes. The director
  generates in his own browser; agents write prompts, ingest, QA and register.
- Explosions: layered crack and body, sub thump, delayed debris, a distance-delayed sonic boom (#20). Rooftop rifles
  must not sound like a typewriter (playtest 1).

## Open for the director (ask at its phase, the ask-the-director way)
walk: slower speed vs faster cadence (R 11.2) · throw upgrade nodes (R 22.4) · lightning halo colour (R 17.6) · tree map layout (R 16.5) ·
mecha concept (R 23.1, finale = mecha boss after 3 cities, D-113) · which original species follow the croc
(research 02).
