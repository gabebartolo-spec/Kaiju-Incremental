# Roadmap

This file is the only roadmap and its source of truth (D-444, D-455). Change it by PR; add a new item the same day it
is named. Rebuilt from git on 2026-11-03 against main at d05726342 (#561) and docs/DECISIONS.md up to D-455.
Phase notes and research refs ("R n.m") are in `docs/archive/ROADMAP_2026-10.md` (frozen). Read it by section.

## Vision and scope (Phase 2 vertical slice)

- The demo is Ostia Minor plus one pick of Carthago or Thule (D-425). It uses the croc only, one kaiju per mission
  (D-424). It runs at dusk only (D-359), in English only (D-406). It ships as a Windows exe on Itch, about 2 h long.
- No balance tuning until the game is "beautiful and working" (D-363).

## Where things stand

**Overworld (campaign globe):** F1 to F4 and G1 to G7 are done.

| Row | What | PR |
|---|---|---|
| F1 | Hologram globe spike, campaign rulings D-418..D-425 | #509 |
| F2 | SaveFile v6 holds the campaign | #510 |
| F3 | data/continents.json: seven placeholder continents | #513 |
| F4 | Conquest bonuses go through the upgrade stat path | #516 |
| G1 | Tellus Nova landmass mask from the director's map | #517 |
| G2 | Globe scene: continents, spin, drag, hit-test | #518 |
| G4 | Mission markers and camera fly-to (D-429) | #520 |
| G3 | Continent colour states (D-430) | #523 |
| G5 | Mission panel, stub mission, conquest on the globe (D-431, D-432) | #525, #526 |
| G6 | Conquests unlock the Komodo and the serpent (D-423) | #558 |
| G7 | Globe LAUNCH starts the real city; unplayable titans hidden on the rack (D-454) | #561 |
| — | Global Threat Level logic: capped at 99, the last conquest sets 100 and opens Aurelia (D-422, `sim/campaign.gd`) | built |

Still open on the overworld:

- the stub mission becomes the real mission flow
- continent rows hold real data, not placeholders
- a globe readout for the Threat Level (logic built; UI unverified)
- continent bonuses: later (balance, D-363)

**Cities, C1:** Phase 0 is done (#538). Three demo layouts: Ostia beach, Carthago harbour and Thule fjord (D-435).
Every city is the adult city at every stage (D-436); the threat level belongs to each city (D-437). Phases 1 to 4
are open; next are the landmark-spot notes.

**Testing and CI:** slow suites fixed (#534), `counts` green (#545, D-446). Touched suites run locally; a PR runs the
lints and sim suites, engine suites run on main (D-403). Test tools in #539 and #541.

**Since 2026-10-30:**

- Performance: 111 fps (#530), decor loads in 1.4 s (#531), CPU trims (#544 D-447, #548 D-451), leap suite speed (#551).
- Controls: W walks forward, the stick turns with the camera (#542, D-445).
- Civilians: fleeing never steps toward the kaiju (#546, D-450); calmed ones never walk back (#554, D-453).
- Destruction: tank carving (#537); falling buildings hit neighbours and the kaiju, never pass through (#547 D-448, #553).
- Leap: never vaults or lands on a tower above his shoulder (#549 D-449; #555 seeded-city regression).
- Look: dusk grade copied from Shin Godzilla (#550, D-452); title night beach (#532, D-440, D-441); FFT ocean (D-428),
  ripple fade (#528); bay bridge gone (#527); load stills (D-427).
- Taskforce: gunships in the adult city, up to 2, laser cannon (#556; D-143, D-145, D-152); with gas soldiers and mechs (#450) the full Taskforce is in.
- Overworld: Komodo and serpent unlocks (#558, D-423); globe LAUNCH starts the real city (#561, D-454).
- Cleanup: octopus and insectoid code removed (#535, D-438).
- In review: bug bash, nine verified bugs fixed with tests (#560).

## Open work

| # | Row | Status |
|---|---|---|
| 1 | Croc animation (Cascadeur, reference copied exactly, D-410) | open |
| 2 | Bay-coast junctions | done (#431; bridge removed #527) |
| 3 | Destruction: landmarks and bridges carve, varied collapse, stadium crowd | done (#421 D-387 D-388, #427 D-389, #537) |
| 4 | Random cities (city_seed, pool and spots, D-375) | moved into C1 Phases 1 to 4 |
| 5 | Upgrade tree: rings, 2-3x nodes, Ricochet/Domino, tail-lash nodes, bio lab screen | done (#422 D-275, #430, #455, #493, #445, #454 D-396) |
| 6 | Render and performance, graphics preview | done (#530, #531, D-393) |
| 8 | CI | done (#534; #545 D-446) |
| 9 | Sound and music | open |
| 10 | Demo shell: textures, preview, load art, end screen, feedback link | done except textures (D-393, D-395, D-427) |
| 11 | Civilians never flee toward the kaiju | done (#546 D-450, #554 D-453) |
| 12 | Falling buildings never pass through a neighbour: they carve it or follow physics | done (#547 D-448, #553) |
| 13 | Bug: the kaiju can jump onto the tops of extremely tall buildings | done (#549 D-449, #555) |
| 14 | Revisit the appearance of closed windows | open (art: capture to the director first) |
| 15 | Globe LAUNCH starts the real city; locked titans hidden until playable | done (#561, D-454) |
| 16 | Continent bonuses | later (balance) |

## Milestones

- **M1: feel pass**
- **M2: Taskforce agents**
- **M3: demo complete**, which needs all of these:
  - done: full Taskforce (gas soldiers and walking mechs #450, gunships #556; D-143, D-145, D-152)
  - textures
  - helicopter deaths
  - the overworld loop: globe, real mission, conquest
  - done: graphics preview (D-393), load art (D-427), end screen, feedback link (D-395)
- **M4: Itch release candidate**
  - done: build and release tooling, draft page, RC checklist (D-457, docs/release/)
  - open: icon, page approval, price, RC play test, upload

## Parked

- Komodo and serpent content stays out of the demo (croc only, D-424); their unlocks are built (#558)
- Hatchlings (D-358)
- Mecha finale (shape ruled: GODBREAKER in Aurelia, D-422)
- Colour-blind cues, until after the demo (D-407)

## Open director questions

- Walk speed vs cadence (R 11.2)
- Camera growth (R 19)
- Serpent design (D-246)
- Body contact: carve or yield (R 13.3)
- Throw nodes (R 22.4)
- Fire (research 26) and fire crews
