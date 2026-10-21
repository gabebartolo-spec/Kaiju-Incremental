# Procedural city generation for a voxel kaiju rampage (roads, blocks, lots, buildings, districts, landmarks, coast)

Research date 2026-10-21. Repo context read (no edits): `sim/city_gen.gd`, `sim/city_lines.gd`, `sim/city_lots.gd`,
`sim/city_river.gd`, `sim/city_sites.gd`, `sim/city_band.gd`, `sim/city_growth.gd` (header comments only).
The game already has a seeded grid-with-random-gaps street plan, a ring avenue, a diagonal avenue, alleys, nested
districts that open per growth stage (D-039), lots lining block faces with party walls (New York / Tokyo style), two
tower districts, a river row with quay sheds and bridges, landmark plazas, and a band of real buildings past the edge.
So the findings below are judged as "what to add or avoid", not "what to start from".

## Key findings

1. **Parish & Müller (SIGGRAPH 2001) is the founding method: an L-system extended with "global goals and local
   constraints", driven by image maps (land/water boundary, population density) that outputs highways, streets,
   subdivided lots and building geometry.** The extension exists to cut the complexity of the production rules
   ([SIGGRAPH history archive](https://history.siggraph.org/?p=116923)). Martin Evans' write-up re-frames it in
   practice as a priority queue of candidate segments, a "global goals" step proposing segments and a "local
   constraints" step that accepts, rejects or snaps them; it is not really an L-system when implemented
   ([Martin Evans, "Procedural Generation For Dummies: Roads"](https://martindevans.me/game-development/2015/12/11/Procedural-Generation-For-Dummies-Roads/)).
   The reusable idea for us is the **population-density map as an input**, not the growth algorithm.

2. **Tensor-field streets (Chen, Esch, Wonka, Müller, Zhang, SIGGRAPH 2008) give the most organic, editable road
   networks, but are the most fragile and slowest to get right.** Fields (grid, radial, heightmap, polyline along
   rivers or cliffs) are blended and streamlines are traced along the major/minor eigenvector fields
   ([project page](https://www.sci.utah.edu/~chengu/street_sig08/street_project.htm)). Evans, who implemented it,
   reports tracing is "extremely sensitive to errors", needed RK4 integration, sign-flip handling, two quadtrees for
   intersection tests, and eigen-sample caching that "more than tripled" speed; his cities still took **5-10 s** to
   generate and he called it the part he is "most unhappy about"
   ([Martin Evans](https://martindevans.me/game-development/2015/12/11/Procedural-Generation-For-Dummies-Roads/)).
   The best open implementation, ProbableTrain's City Generator, is **TypeScript under LGPL-3.0**
   ([GitHub](https://github.com/probabletrain/mapgenerator); [itch.io](https://probabletrain.itch.io/city-generator)),
   and its own output is "American grid-based" in style anyway.

3. **Agent-based and simulation-driven growth produce believable hierarchy (main roads, minor roads, land use) but add
   a simulation to tune.** Beneš, Wilkie and Křivánek (Eurographics 2014) grow networks with a simple traffic
   simulation adding major roads and use waterways to place city centres
   ([CGG Prague](https://cgg.mff.cuni.cz/?p=1672)); a 2025 arXiv model uses "extender" and "connector" agents for
   tertiary roads ([arXiv 2507.18899](https://arxiv.org/pdf/2507.18899)); another assigns commercial / residential /
   industrial / recreational use to plots on an existing network
   ([arXiv 2211.01959](https://arxiv.org/pdf/2211.01959)). A land-use-model approach (Eurographics 2009) generates
   "large city layouts in seconds" from high-level inputs
   ([EG digital library](https://diglib.eg.org/items/ce0c30db-a64c-4320-a3b3-704a45484a3c/full)). Value for us:
   **district assignment by rules (distance to centre, to water)**, not the agents themselves.

4. **Lot subdivision: Vanegas et al. (CGF 2012) combine an OBB recursive split (for the open interior) with a
   straight-skeleton split (for the street-facing ring), tuned from real cities**
   ([EG digital library](https://diglib.eg.org/handle/10.1111/v31i2pp681-690);
   [Purdue PDF](https://www.cs.purdue.edu/cgvlab/papers/aliaga/eg2012.pdf)). Practitioners report the skeleton
   method's corner handling is hard to reproduce and fall back to simpler splits
   ([SideFX forum](https://www.sidefx.com/forum/post/307409)); a small open OBB implementation stops recursion on a
   minimum area ([stavguo/obb-parcelling](https://github.com/stavguo/obb-parcelling), licence not checked). Tom Kelly's
   straight-skeleton thesis is CC-BY ([Glasgow theses](https://theses.gla.ac.uk/4975)). On an axis-aligned grid,
   **OBB split degenerates to a simple recursive rectangle split**, which is close to what `sim/city_lots.gd` already does.

5. **Building variety: CGA shape grammar (Müller, Wonka et al., SIGGRAPH 2006) builds a crude volumetric "mass model"
   first, then splits and repeats along axes (floors, bays, windows), with context rules so parts do not
   intersect** ([paper PDF](https://course.ccs.neu.edu/cs5150f13/readings/muller_buildings.pdf);
   [Brown thesis summary](https://cs.brown.edu/research/pubs/theses/ugrad/2013/zweig.pdf);
   [gamedev.net tutorial](https://gamedev.net/tutorials/programming/engines-and-middleware/procedural-modeling-of-buildings-with-shape-grammars-r4596)).
   For voxels only the **mass-model stage** matters at kaiju scale: podium + shaft + setback + crown is a "repeat
   split along y" with a few rules, which changes silhouettes (what the player reads and topples) cheaply. Facade
   detail can stay in shaders/materials.

6. **Wave Function Collapse (Townscaper, Bad North) gives charming local variety but its cost is art modules and
   solver failures.** Townscaper uses an irregular quad grid, marching-cubes-style corner pieces and WFC; failures are
   silent (loose supports). Bad North used **300+ hand-built tiles**, banned identical/mirrored neighbours, validated
   islands for reachability and restarted the solver on failure; a Townscaper reskin was estimated at ~500 tiles
   ([Game Developer, "How Townscaper works"](https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making)).
   Stålberg's principle worth keeping: **large forms follow clear, predictable rules; small details vary** (same
   source). A Godot 4 WFC addon with backtracking exists, MIT per the Asset Library
   ([Asset Library 1951](https://godotengine.org/asset-library/asset/1951); repo AlexeyBond/godot-constraint-solving).

7. **Districts by Voronoi are optional: Watabou, whose Medieval Fantasy City Generator popularised Voronoi wards,
   now says the Voronoi diagram is "not really necessary", and that the method is deliberately arbitrary, aiming at
   a nice-looking map, not an accurate city** ([itch.io page and comments](https://watabou.itch.io/medieval-fantasy-city-generator)).
   Its source is **GPL-3.0 Haxe** and lacks the water features ([TownGeneratorOS](https://github.com/watabou/TownGeneratorOS)),
   so it is a reference to read, not code to ship in a commercial build.

8. **Coastline and docks, simplest known method (Watabou 0.4.0): generate the city normally, forbid wards in water
   (a "bitten apple" outline), remove the wall facing the water, assign some seafront blocks as "docks" and draw piers
   into the water.** The author notes it took far more refactoring than expected and the water body hurt performance
   ([devlog "Coastal cities"](https://watabou.itch.io/medieval-fantasy-city-generator/devlog/4923/040-coastal-cities)).
   Port-placement rules from another game: on the coast, minimum spacing between ports, reachable by sea
   ([Frozen Fractal](https://frozenfractal.com/blog/2025/9/21/around-the-world-25-placing-ports/)). Beneš et al. use
   waterways to seed city centres ([CGG Prague](https://cgg.mff.cuni.cz/?p=1672)).

9. **Voxel destruction games keep levels small and hand-made, or procedural but sparse; I found no source for a
   dense, procedural, destructible voxel city in shipped form.** Teardown's levels are fully destructible voxels with
   per-material behaviour, deliberately small; the developer felt its largest map, Villa Gordon, was already
   "long-winded and tiring" ([PCGH](https://www.pcgameshardware.de/Teardown-Spiel-73677/Specials/PC-Game-Test-Benchmark-Voxel-Dynamic-Destruction-1394545/2/);
   [PC Gamer review](https://www.pcgamer.com/teardown-review/)). Procedural voxel destruction sandboxes exist
   (Voxelite, Voxel Turf) without published generation methods ([ModDB Voxelite](https://www.moddb.com/games/voxelite);
   [Voxel Turf](https://snapperthetwig.itch.io/voxel-turf)); a Unity voxel+CSG destructible-building system is not
   yet released and has no licence ([80.lv](https://80.lv/articles/this-cool-voxel-building-system-for-destructible-cities-might-be-useful-for-your-game)).
   Introversion's Subversion city generator (roads, highways, buildings down to floors) was documented on their blog
   and shelved in 2011 ([eightbar 2008](https://www.eightbar.com/2008/02/07/building-cities-by-generation-introversion/index.html);
   [Giant Bomb](https://www.giantbomb.com/games/3030-23768/)). The "CityV" reference video's generator is not
   documented anywhere I could find.

10. **Godot-side: no Godot voxel city generator turned up.** Options are general: Zylann's Voxel Tools (C++ GDExtension
    for Godot 4, blocky and smooth terrain, custom generators; [docs index](https://docsearch.algolia.com/mcp/docs/repo/zylann/godot_voxel),
    licence not confirmed in this pass), CityCrafter3D, a slot-grid blocky city tool on itch.io with no licence found
    ([itch.io](https://immaculate-lift-studio.itch.io/citycrafter3d-for-godot-4)), and Red Blob Games' mapgen4 for
    Voronoi terrain/rivers, **Apache-2.0, commercial use allowed** ([GitHub](https://github.com/redblobgames/mapgen4)).
    Kaiju already carves with its own native C++ library, so none of these is needed for buildings.

## Sources
- Parish & Müller 2001 — https://history.siggraph.org/?p=116923
- Martin Evans, roads (tensor fields, growth framework) — https://martindevans.me/game-development/2015/12/11/Procedural-Generation-For-Dummies-Roads/
- Chen et al. 2008, Interactive Procedural Street Modeling — https://www.sci.utah.edu/~chengu/street_sig08/street_project.htm
- ProbableTrain mapgenerator (LGPL-3.0) — https://github.com/probabletrain/mapgenerator ; https://probabletrain.itch.io/city-generator
- Beneš et al. 2014, Procedural Modelling of Urban Road Networks — https://cgg.mff.cuni.cz/?p=1672
- Agent-based tertiary roads — https://arxiv.org/pdf/2507.18899
- Agent-based land use — https://arxiv.org/pdf/2211.01959
- City layout from land-use models (EG 2009) — https://diglib.eg.org/items/ce0c30db-a64c-4320-a3b3-704a45484a3c/full
- Kelly & McCabe (road network first, then buildings) — https://history.siggraph.org/?p=142350
- Vanegas et al. 2012, parcels — https://diglib.eg.org/handle/10.1111/v31i2pp681-690 ; https://www.cs.purdue.edu/cgvlab/papers/aliaga/eg2012.pdf
- SideFX forum on parcels — https://www.sidefx.com/forum/post/307409
- OBB parcelling repo — https://github.com/stavguo/obb-parcelling
- Kelly straight-skeleton thesis (CC-BY) — https://theses.gla.ac.uk/4975
- Müller et al. 2006, CGA shape — https://course.ccs.neu.edu/cs5150f13/readings/muller_buildings.pdf
- Brown thesis on split/repeat rules — https://cs.brown.edu/research/pubs/theses/ugrad/2013/zweig.pdf
- gamedev.net shape grammar tutorial — https://gamedev.net/tutorials/programming/engines-and-middleware/procedural-modeling-of-buildings-with-shape-grammars-r4596
- How Townscaper works — https://www.gamedeveloper.com/game-platforms/how-townscaper-works-a-story-four-games-in-the-making
- Godot WFC addon (MIT) — https://godotengine.org/asset-library/asset/1951
- Watabou MFCG — https://watabou.itch.io/medieval-fantasy-city-generator ; coastal devlog https://watabou.itch.io/medieval-fantasy-city-generator/devlog/4923/040-coastal-cities
- TownGeneratorOS (GPL-3.0) — https://github.com/watabou/TownGeneratorOS
- Frozen Fractal, placing ports — https://frozenfractal.com/blog/2025/9/21/around-the-world-25-placing-ports/
- Teardown — https://www.pcgameshardware.de/Teardown-Spiel-73677/Specials/PC-Game-Test-Benchmark-Voxel-Dynamic-Destruction-1394545/2/ ; https://www.pcgamer.com/teardown-review/
- Voxelite — https://www.moddb.com/games/voxelite ; Voxel Turf — https://snapperthetwig.itch.io/voxel-turf
- 80.lv voxel/CSG destructible buildings — https://80.lv/articles/this-cool-voxel-building-system-for-destructible-cities-might-be-useful-for-your-game
- Subversion — https://www.eightbar.com/2008/02/07/building-cities-by-generation-introversion/index.html ; https://www.giantbomb.com/games/3030-23768/
- Voxel Tools for Godot — https://docsearch.algolia.com/mcp/docs/repo/zylann/godot_voxel
- CityCrafter3D — https://immaculate-lift-studio.itch.io/citycrafter3d-for-godot-4
- mapgen4 (Apache-2.0) — https://github.com/redblobgames/mapgen4

## For Kaiju Incremental

Verdict on the main question: for "dense, smashable, believable" at least code, **grid + perturbation (what
`sim/city_gen.gd` already does) beats L-systems, tensor fields, agents and WFC**. A kaiju sees blocks and skylines,
not road topology; the literature's sophistication is spent on the road graph, which is the part the player reads
least. Spend effort instead on density, district identity, silhouettes and set-pieces. Ranked, simplest first:

1. **Make "no empty space" a test, not a hope (cost: one suite, no new system).** For pinned seeds at every growth
   stage, assert per district: built footprint / block area above a floor, no playable block left "built" with zero
   lots (the `bare` list in `generate()` is the place to check), and a max gap between buildings along any street.
   This protects the director's rule against every later change. Determinism is already structured for it
   (districts fill innermost first so numbers stay stable).

2. **One seeded density field drives height and lot size (cost: a small function plus a `data/tuning.json` table).**
   Parish & Müller's population map, reduced to one scalar per block: high at the downtown cores, falling with
   distance, lifted along the waterfront. Lot width, height cap and tower chance read from it. Each stage raises the
   field's peak and spreads it, so "bigger than the last" is a tuning change per stage in `city_growth.gd`, not code.

3. **District types as a per-block label from simple rules (cost: a lookup and a style table in `data/`).**
   Downtown towers (density high), residential (mid, front yards, which `city_lots.gd` already has), industrial (low,
   wide sheds, tanks, chimneys: big cheap smash targets), docks (seafront). Rules: distance to centre, distance to the
   river/coast, one per ring. Skip Voronoi (Watabou says it is not needed). Readability rule from Stålberg: big
   forms predictable per district, small details random.

4. **Docks and harbour, the Watabou way (cost: moderate; reuses `city_river.gd`).** Assign the blocks touching the
   water as docks: cranes, container stacks, warehouses, piers into the water. The kaiju rises among them (D-083,
   #113), so the first thing it smashes is harbour clutter, never an empty quay. Budget performance time for the
   water body (Watabou's warning).

5. **Landmarks placed for the camera, from data (cost: data plus a placement rule in `city_sites.gd`).** The literature
   has no landmark-placement algorithm worth copying; use Townscaper's "high-priority module under a condition"
   idea: each landmark in `data/landmarks.json` names a condition (end of the diagonal avenue's axis, visible from the
   spawn camera, on the waterfront for a bridge, at the stage's new ring for the stadium) and the site finder tries
   it first, then falls back. One new landmark per stage gives each rampage a headline set-piece.

6. **Mass-model building grammar for silhouettes (cost: medium; touches carving cell counts and toughness tiers).**
   CGA's first stage only: podium + shaft + optional setback + crown/spire, chosen by district. Changes what topples
   and how it reads, at no art-module cost. Profile cell counts per stage before raising density (Teardown's lesson
   that big voxel maps get tiring and heavy).

7. **OBB recursive lot split only if non-grid blocks arrive (cost: medium).** Needed if the diagonal avenue or a
   curved coast makes many irregular blocks; on axis-aligned blocks the current face-lining is equivalent.

Not recommended now: **tensor fields** (5-10 s per city in a reference implementation, error-sensitive, reference
code LGPL), **L-system/agent growth** (a simulation to tune for road shapes the player barely reads), **WFC**
(hundreds of modules, silent failures, restarts; fine later for decor only, MIT addon exists), and **copying
Watabou's GPL-3.0 code** into the shipped game.

Generation budget: the cited systems take "seconds" (Evans 5-10 s; land-use model "seconds"). Kaiju's grid plan
should be far faster; add a timing line to the suite in item 1 per stage so growth in city size is caught before it
becomes a load-time problem.

**Evidence gaps:** no published timings for grid-based generators or for Godot GDScript city gen; no developer source
on how CityV or other dense destructible voxel cities are generated; Kelly & McCabe's 2006 survey full text not
retrieved; Parish & Müller and Vanegas read via abstracts and secondary sources, not full text; licences for
godot_voxel, CityCrafter3D and obb-parcelling not confirmed; no literature on placing landmarks as set-pieces.
