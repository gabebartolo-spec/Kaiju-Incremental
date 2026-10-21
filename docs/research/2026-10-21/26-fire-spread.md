# Fire that spreads, pays and lights the night (research for Kaiju Incremental)

Researched 2026-10-21 for lead 10. Director, comments #15: "im still interested in Fire as a source of lighting and gameplay (perhaps natural flame that can spread (unlockable in skill tree) and add to your biomass collection)". Also in force: a destroyed building stays rubble, never a burning shell (#111); explosive sites are coming (#19); a clumsy army misses into the city (#18).

Marking: **[src]** = taken from a cited source. **[guess]** = my number or opinion, untested; the pacing bot (`tools/pacing.gd`) and a playtest decide it.

Read in full: `CLAUDE.md`, `scenes/fire.gd`, the fire/ruin call sites in `scenes/city_view.gd`, `sim/species_powers.gd` (burn coat), `data/tuning.json` (burn_seconds 3, burn_dps 4, run_seconds 40, rubble_mult). Read by grep only: `docs/ROADMAP.md` (section E is the upgrade tree and holds no fire paragraph; fire appears only as b2-26 and the #111 rubble rule in the build-2 notes), `12-lighting.md`, `16-upgrade-tree.md`, `01-incremental.md` (pulled from the sibling research folder `local_cf0b00c9.../research`, because they are not in this one). Section D and `docs/VISION.md` have no fire text.

## What the repo does today (the problem to fix first)

- `scenes/fire.gd`: one `Fire` node per fire = one `OmniLight3D` (flicker from two sines) + three `GPUParticles3D` (flames 130, embers 45, smoke 70, each times `max(1,size)`) = about 245 particles and 4 nodes per fire. The wind is a hard-coded `WIND` constant.
- `scenes/city_view.gd:188`: a collapse has an 18% chance to call `fire(...)` using the **presentation** RNG (`_rng`), and the fire then burns forever until it is the oldest of `MAX_FIRES = 30`. This breaks three rules at once: Sim is the authority (rule 3), determinism (rule 2, a replay shows different fires), and #111 (a burning shell on rubble that never goes out).
- `sim/species_powers.gd:275`: breath sets a `burn` coat (4 dps, 3 s) on units. Fire on **buildings** has no sim state at all.

So the order is: take fire into the sim as a building state, then let presentation read it.

## Key findings

1. **The two shipped systems everyone cites are simple rules plus a hard stop, not physics.**
   - Far Cry 2: a gameplay programmer spent a year and a half on it and cut the research down to what plays. Fire uses wind direction, hot gas (faster uphill), humidity (jungle resists, rain delays). Crucially: "The fire doesn't propagate indefinitely because it's just not fun", and his first test (one shot into a barrel burned miles of terrain and dropped the PC to a crawl) is why there are limits. Players complained they could not control it, and the author called that lack of control "a good thing" because chain reactions are "always different" and "unscripted". ([Game Developer interview](https://www.gamedeveloper.com/game-platforms/interview-how-i-far-cry-2-i-s-fire-fuels-spreads)) A separate write-up by the same author describes a 2D grid of fire cells with "burnability" and lifetime, where each burning cell needs spreading points to pass fire on ([jflevesque.com](https://jflevesque.com/2012/12/06/far-cry-how-the-fire-burns-and-spreads/), read as a search excerpt only).
   - Breath of the Wild: three rules. Elements (fire, water, ice, wind, electricity) change the state of materials (leaves burn and disappear); elements change each other (water kills fire); materials never affect each other ([Thumbsticks, GDC 2017 report](https://www.thumbsticks.com/gdc-17-breath-of-the-wild-science-lies/)). Lesson for us: players trust a rule set that is consistent and "clever", and then invent uses (wind carries fire) without being told.
   - Noita: fire is "kind of simple": a burning pixel looks in a random direction to ignite one pixel; once it has burned long enough it destroys that pixel ([80.lv](https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation), excerpt). Burn time, then removal: the same shape as our building.
   - Teardown (voxel fire): I found only video and forum snippets, nothing citable on rules. Skipped.

2. **The academic urban-fire models say what to model per building: distance, wind, material, and a "domino" tail.**
   - The oldest, Hamada's, gives spread rate as a function of wind velocity and building-to-building spacing, with a factor for how much of the district is non-fireproof ([IAFSS physically based model](https://publications.iafss.org/publications/fss/7/129/view/fss_7-129.pdf), excerpt). Radiant heat is the main cause of spread between neighbours ([monograph 34](https://raczar.es/assets/publicaciones/monografias/monografia34/087.pdf)); once a few buildings go, a domino effect follows until the wind drops ([IBHS](https://ibhs.org/wildfire/wind-driven-building-to-building-fire-spread/)). Firebrands (embers) cause the jumps across gaps ([UMD dissertation](https://drum.lib.umd.edu/items/b9c8055d-84a2-4545-83ca-c1b16c0dee78)).
   - I did **not** extract Hamada's coefficients; do not copy numbers from this file as if they were his. Every number below is a game-feel guess.
   - The grid models (Drossel-Schwabl: tree, burning, empty; ignition probability) are the textbook CA ([Wikipedia](https://en.wikipedia.org/wiki/Forest-fire_model), [multi-factor CA paper](https://www.sciencedirect.com/science/article/pii/S2666449624000422)). Their lesson is the three states plus a burn duration. Their weakness for us: coin flips per tick read as random. See finding 3.

3. **Make spread legible with a heat meter, not dice.** [guess, my design] Each unburnt building holds a `heat` value. Every sim tick, each burning neighbour adds `w(distance, wind, material) * dt`. At `heat >= threshold` it ignites. The threshold is drawn once from the sim's seeded RNG (so two runs with one seed match, and no clock is used). The player sees it as: windows on the downwind side glow orange and a thin heat shimmer grows for 1-3 seconds before the building catches. A player can read "that one is next", can cut a firebreak by stomping the building that is next (rubble does not burn), and can tilt the wind. This is the "clever lie" BotW describes, and it answers Far Cry 2's "I could not control it" complaint without removing the surprise.

4. **Fire is a sim state, rubble is the end state.** Building states: `intact -> heating -> burning -> rubble`. `burning` lasts `burn_time` (material and size) and then triggers the **existing collapse path**, which already produces rubble. The flames, embers and light live only while `burning`; nothing burns on a rubble pile (satisfies #111). Existing `ruin.gd` scorch ("char near the fire only") already gives the burnt look on the ruin afterward; keep it.

5. **Pay biomass on burn-out, bounded by the run timer, so it is never idle income.** The run is 40 s base (`run_seconds`), each run ends and the player returns to the tree, so a fire cannot pay between runs. Inside a run, three rules keep it active [guess]:
   - Payout only at **burn-out** (the building collapses), at `rubble value * fire_pay` where `fire_pay` is below 1 (try 0.6), so fire is a multiplier on reach, not a replacement for smashing. Your own stomp/breath/tail on a burning building pays the normal rate and adds a heat spike (see tree node "Fan the flames").
   - A **conflagration multiplier** counts burning buildings in the last few seconds and decays; it only rises when the player lights new ones, so stopping stops the bonus. Cap it so fire stays under about a third of a typical run's biomass (tuning target, pacing bot checks).
   - Burn-outs far outside the camera or the kaiju's leash radius pay a quarter (guess), so "light it and wander away" is worse than "light it and keep working the edge of it".
   - The tree-time rule from `01-incremental.md` ("zero AFK progression", the late-game AFK trap) is met because there is no payout outside a run.
   - Same lesson as FC2's designer: fire that burns the whole map is not fun and kills the frame rate. Each fire needs a fixed ceiling: finite `burn_time`, a heat threshold that rises with distance, and a max simultaneous burning count (suggest 48 sim, 12 full visuals, see budget).

6. **Lighting: fires are the night city's light, through the existing pool.** From `12-lighting.md` (cited there to the Godot docs): Forward+ clusters up to 512 elements; gl_compatibility only renders 32 positional lights per frame and 8 per mesh, and drops the rest; the recommendation there is a pool of about 24 real lights, nearest-to-camera first, with everything else as emissive voxels plus glow. Applied to fire:
   - One light per **fire cluster**, not per burning building. Merge burning buildings that share a block into one light placed at their centroid with energy and range scaled by the count. A burning block then reads as one big warm pool, and a district of 40 buildings costs at most 6-8 lights. [guess]
   - Priority in the pool: kaiju rim light, then fire clusters by screen size, then lamps, then police. Muzzle and breath flashes borrow slots for under a second (already a rule in `12-lighting.md` item 7).
   - Keep the existing sine flicker but drive it from one shared noise value per cluster so a block does not flicker in unison or look like 30 strobes.
   - Warm fire against cool sky is the film trick (Godzilla 2014 DP, quoted in `12-lighting.md`); the lighting research's "warm light from below onto the kaiju" item means fire is also what lights the monster. No new rendering feature needed.
   - Distance-fade (`distance_fade_enabled`) on every fire light, shadows off on all small fires (also from `12-lighting.md`; shadowed and unshadowed lights do not match in Compatibility).

7. **Performance budget.** [all guess, to be measured with the existing bench captures]
   - Sim: a neighbour list per building built once at city gen (4-6 entries, gap distance under about 12 m). A tick at 4 Hz over at most 48 burning buildings, 6 neighbours each = under 300 float adds a tick. Negligible; no grid needed.
   - Visual tiers by distance and count: full fire (flames+embers+smoke, about 245 particles today) for the 12 nearest burning buildings; smoke-only (about 20 particles, one node) for the next 24; beyond that, an emissive window-glow shader flag on the building cells and nothing else. Worst case about 12 x 245 + 24 x 20 = about 3.4k particles, against 30 x 245 = 7.4k today at the cap.
   - Pool and reuse `Fire` nodes; do not `new()` per ignition. The shader compile hitch is already handled by `Fire.prewarm`; keep it.
   - Particle `visibility_aabb` is already set on smoke; add it to flames so offscreen fires are culled.
   - gl_compatibility: positional-light cap above is the real limit; pool of 24 leaves 8 for flashes.

## Skill-tree nodes (3 to 5), simplest first

All are unlocks in the existing tree, species-agnostic by default; breath species light buildings directly, others need a spark source (ignitable explosive, tank wreck, army shell). Before the first node, fire stays what it is today: a short visual on the one thing hit, **no spread**, no payout, and no permanent flames on rubble.

| # | Node (working name) | What it changes in play | Rough cost [guess] |
|---|---|---|---|
| 1 | **Kindle** (3 levels) | Turns spread on. L1: a burning building heats neighbours within about 8 m. L2: 12 m. L3: heat gain x1.5. One breath or tank hit can now light a block. Burn-out pays `fire_pay`. | Sim state + heat tick + payout + remove ruin-fire (small/medium) |
| 2 | **Fan the flames** (2 levels) | Active verb. A stomp, tail swipe or claw on a *burning* building adds a heat spike to its neighbours and pays the normal rate on its collapse. L2: the breath cone adds heat across everything in the cone. Rewards steering fire instead of watching it. | Reads existing hit events; small |
| 3 | **Tailwind** (2 levels) | Wind is a visible arrow and a run-long vector (smoke already leans with it). Spread heat gets `1 + k*dot(dir, wind)`. The node lets a tail flap or roar **rotate the wind a quarter turn** on a cooldown: push the fire toward the dense downtown. | Wind into sim, tiny UI arrow; small |
| 4 | **Ember storm** (3 levels) | Tall buildings throw embers: 1-3 firebrands per second along the wind, landing 15-40 m away, where a landing adds a big heat chunk. They jump roads, the river and your firebreaks, and are the visible, seeded randomness. | Seeded roll per burning building, ember particle arc; medium |
| 5 | **Firestorm** (1 level, capstone) | Explosive sites (fuel silo, fireworks, chem lab, #19) inside or next to a burning block detonate: a shockwave that adds heat to everything within its radius and throws debris. Many burning buildings in one block at once (suggest 6+) trigger a firestorm for 5 s: inward wind, heat gain x2, and the conflagration multiplier uncapped for the duration. Big, loud, lights the whole screen. | Needs the explosive-site feature (#19) and army fire into the city (#18); medium/large |

How each reads: Kindle is the visible "oh, it spreads"; Fan is what the player does with their hands; Tailwind is the new decision (where to push); Ember storm is the surprise; Firestorm is the payoff and the "every rampage bigger than the last" moment (CLAUDE.md philosophy).

Prerequisites: 1 first; 2 and 3 both need 1; 4 needs 3; 5 needs 4 and the explosive sites. Suggest about 25-35% of the cost of an equal-tier Atomic Breath node [guess]; fire is a multiplier on reach, not a new damage source.

## What the army and explosives add (comments #18, #19)

- A tank shell that misses the kaiju and lands in the city is a free ignition source: a `spark` event at the impact point, small heat (not an instant ignite). With Kindle owned, enemy fire starts your fires, which is funny and makes "the army burns its own city" a real thing.
- Explosive sites are materials with `explosive = true`: when their `heat` reaches the threshold they detonate instead of burning. This is the BotW pattern of rule 1 (element changes material) with one extra material; no new system.
- Fire-fighting (a fire truck, or police water) is optional later [guess]. BotW and FC2 both show water puts fire out; a fire truck that fights a block gives the player something to defend a fire against. Not needed for v1.

## For Kaiju Incremental (ranked, simplest first)

1. **Delete the permanent ruin fire.** (small, hours) Stop `city_view.gd` calling `fire()` on collapse with the presentation RNG, so rubble never burns (closes the #111 shell problem and the determinism leak). Keep a 4-6 s dying ember/smoke puff on collapse as pure presentation. Risk: none; the scene looks quieter until step 2.
2. **Fire as a building state in the sim** (medium). Add `heat`, `burn_t`, a seeded ignition threshold, and a `burning -> collapse` transition; emit `ignited`, `burned_out` events; presentation spawns a pooled `Fire` per burning building and ends it on `burned_out`. Gated by Kindle so builds without the node are unchanged. Needs `kaiju-sim-review` (a shared simulation rule). Evidence: replay test with a pinned seed shows identical burn timelines twice, and a player-effect fixture shows Kindle changes biomass.
3. **Pay on burn-out with the conflagration multiplier and the leash rule** (small once 2 exists). Tune in `tuning.json`, check the share of run biomass with the pacing bot.
4. **Wind in the sim and a visible arrow** (small). Replace the `WIND` constant in `fire.gd` with the sim value so smoke, embers and spread agree; smoke lean is already the best wind telegraph.
5. **Fire-cluster light pooling** (medium). One light per cluster, nearest 24 as the budget; shared flicker noise; add distance fade. Check on both renderers; the 32-light cap makes gl_compatibility the test.
6. **Fan the flames** (small), then **Ember storm** (medium).
7. **Explosive chain and Firestorm** (medium/large) after #19 sites exist.

## Open questions for the director (decide, not research)

- Does fire need a source on non-breath species (a spark), or is Kindle "the kaiju burns what it touches" for everyone? My lean: everyone gets an ignition, the breath species just light more at once. [guess]
- Wind: fixed per run and rotatable (my lean, readable), or drifting on its own (more Far Cry 2, harder to plan)?

## Sources

- https://www.gamedeveloper.com/game-platforms/interview-how-i-far-cry-2-i-s-fire-fuels-spreads (read in full)
- https://jflevesque.com/2012/12/06/far-cry-how-the-fire-burns-and-spreads/ (excerpt)
- https://www.thumbsticks.com/gdc-17-breath-of-the-wild-science-lies/ (read in full)
- https://80.lv/articles/noita-a-game-based-on-falling-sand-simulation (excerpt)
- https://publications.iafss.org/publications/fss/7/129/view/fss_7-129.pdf (excerpt)
- https://raczar.es/assets/publicaciones/monografias/monografia34/087.pdf (excerpt)
- https://ibhs.org/wildfire/wind-driven-building-to-building-fire-spread/ (excerpt)
- https://drum.lib.umd.edu/items/b9c8055d-84a2-4545-83ca-c1b16c0dee78 (excerpt)
- https://en.wikipedia.org/wiki/Forest-fire_model and https://www.sciencedirect.com/science/article/pii/S2666449624000422 (excerpts)
- Godot limits and the 24-light pool: `12-lighting.md` in the lead's research folder, which cites the Godot docs.
- Cities: Skylines fire-spread complaints (spread "too fast", players disabling it): https://www.reddit.com/r/CitiesSkylines/comments/1e1k19h/ (excerpt; supports "cap it").
