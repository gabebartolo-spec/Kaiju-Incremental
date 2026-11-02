# Roadmap

This file is the roadmap and its source of truth (D-444). Both Claude accounts can read it. Change it by PR. It was rebuilt from git on 2026-11-03: main up to 77cb93e9e,
docs/DECISIONS.md up to D-443, and `docs/archive/ROADMAP_2026-10.md`. Edits made to the Claude Doc
(claude.ai/artifact/CvbnH4ZPRZDLha74homA8Q) after 2026-10-30 are not in it, because that doc only opens from one
account. That doc is frozen. If the director names something it held that is missing here, add it here.

Phase notes, research refs ("R n.m") and owners are in `docs/archive/ROADMAP_2026-10.md`. Read it by section.

## Vision and scope (Phase 2 vertical slice)

- The demo is Ostia Minor plus one pick of Carthago or Thule (D-425). It uses the croc only, one kaiju per mission
  (D-424). It runs at dusk only (D-359), in English only (D-406). It ships as a Windows exe on Itch, about 2 h long.
- No balance tuning until the game is "beautiful and working" (D-363).

## Where things stand

**Overworld (campaign globe):** F1 to F4 and G1 to G5 are done.

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

The overworld rows still open live in plan doc PcHHG2EhRYsKfBzC2ZkQkV, which this file can't see:

- the stub mission becomes the real mission flow
- continent rows hold real data, not placeholders
- the Global Threat Level, with the sixth conquest opening Aurelia (D-422)
- Komodo and serpent unlocks (D-423)

**Cities, C1:** Phase 0 is done (#538). There are three demo layouts: Ostia beach, Carthago harbour and Thule fjord
(D-435). Every city is the adult city at every stage (D-436), and the threat level belongs to each city (D-437).
Phases 1 to 4 are open. Next comes the landmark-spot notes.

**Testing and CI:**

- The six slow suites are fixed (#534).
- Touched suites run locally. A PR runs the lints and the sim suites, and the engine suites run on main (D-403).
- Test tools are in #539: wt_setup, shot, ab before/after sheet, triage.
- Main's slow suite `counts` has been red since #536.

**Since 2026-10-30:**

- Performance: play runs at 111 fps (#530), and decor loads in 1.4 s (#531).
- Title screen: a night beach (#532, D-440, D-441).
- Water: the ripple fades with distance (#528), and the open sea is an FFT ocean (D-428).
- Skyline: the bay bridge is gone (#527).
- Destruction: tank carving (#537).
- Cleanup: the octopus and insectoid were removed (#535).
- Load screen: stills (D-427).

## Open work (archive rows, updated)

| # | Row | Status |
|---|---|---|
| 1 | Croc animation (Cascadeur, reference copied exactly, D-410) | open |
| 2 | Bay-coast junctions | open; the bridge was removed (#527) |
| 3 | Destruction: landmarks and bridges carve, varied collapse, stadium crowd | tank carving done (#537), rest open |
| 4 | Random cities (city_seed, pool and spots, D-375) | moved into C1 Phases 1 to 4 |
| 5 | Upgrade tree: rings, 2-3x the nodes, Ricochet/Domino, tail-lash nodes; bio lab screen (D-396) | open |
| 6 | Render and performance: graphics preview in options | perf done (#530, #531); preview open |
| 8 | CI | slow suites fixed; `counts` red |
| 9 | Sound and music | open |
| 10 | Demo shell: textures, preview, load art, end screen, feedback (Itch link, D-395) | end screen (demo_end.gd), feedback link (D-395), graphics preview with the menu cap lifted (D-393) and load stills (D-427) done; textures open |

## Milestones

- **M1: feel pass**
- **M2: Taskforce agents**
- **M3: demo complete**, which needs all of these:
  - full Taskforce
  - textures
  - helicopter deaths
  - graphics preview (done, D-393)
  - load art (stills done, D-427)
  - end screen (done)
  - feedback link (done, D-395)
  - the overworld loop: globe, mission, conquest
- **M4: Itch release candidate**

## Parked

- Komodo and serpent, now unlocks after conquests (D-423)
- Hatchlings (D-358)
- Mecha finale
- Colour-blind cues, until after the demo (D-407)

## Open director questions

- Walk speed vs cadence (R 11.2)
- Camera growth (R 19)
- Serpent design (D-246)
- Body contact: carve or yield (R 13.3)
- Rampage timer (R 1.2)
- Throw nodes (R 22.4)
- Tree layout (R 16.5)
- Fire (research 26) and fire crews
- Finale shape (R 23.1)
