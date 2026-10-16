# Real-city handoff, 2026-10-16 21:30
## State: available (D-029 TABLED by the director; paused on a WIP branch, no PR)

## Task
D-029: drop real city districts from OpenStreetMap into the play area, Melbourne CBD first
(Hoddle Grid + Yarra edge). Offline bake, no runtime downloads, no player imports; cities ship
as patches. Director tabled it 2026-10-16: "focus on proofing the game before we expand to
that feature". Resume only when STATUS.md assigns it again.

## Branch and commit
claude/real-city-92596b (worktree .claude/worktrees/street-life-b59ef8, folder name is
historical), based on look-options 01f5305. NOT yet rebased onto PR #7 (city layout, 74d9a28).
No PR open.

## What exists
- docs/LICENSING_REGISTER.md: OSM (ODbL 1.0) CLEARED with the owed credit line "Map data ©
  OpenStreetMap contributors, ODbL" (credits screen + store page, NOT DONE: no credits screen
  exists yet) and share-alike notes; tools/osm CLEARED (stdlib only).
- tools/osm/districts.json: one entry per district (bbox, origin, metres_per_unit, play
  streets, start). tools/osm/fetch_osm.py: one Overpass bbox query, backoff over 3 public
  servers, cache tools/osm/cache/ (gitignored; 8.3 MB for the CBD).
  tools/osm/bake_district.py -> data/cities/melbourne_cbd.json (336 KB): rotate to the grid
  (-18.15 deg), 10 m per unit uniform, play rect between Spencer/Spring/La Trobe/Flinders
  centre lines (+30 m, +200 m south to mid-Yarra), street graph (avenue/street/alley by OSM
  class, width from tags), footprints rasterised to unit cells (tallest owns a cell), split
  into boxes; heights from height / levels / type rule; water, parks, plazas, rail yards.
  tools/osm/preview_district.py: top-down PNG of a bake (needs Pillow, run without -I).
- sim/city_district.gd (CityDistrict: data/plan/buildings/outer_buildings/play/start),
  sim/city_source.gd (CitySource: district or CityGen), Content.set_district + --district= arg.
  RampageSim: arena is a Rect2 (CitySource.play grown by margin), kaiju starts at
  CitySource.start (Melbourne: in the Yarra by Princes Bridge).
- scenes/district_ground.gd: roads + footpaths, glossy river, parks, rail; outer buildings as
  one skyline multimesh. city_view.gd hooks it in and skips CityDecor/StreetLife for districts.
- tools/capture/capture_district.gd: top-down (no fog), aerial, gameplay start/mid.
- Sim suite: _check_district (8 checks, floor 47): loads identically, every building whole,
  no overlaps, valid street graph, Yarra present, start in arena, rampage replays.

## Evidence so far
- Bake: 1,890 playable boxes from 2,553 footprints, 38,609 chunks, 3,091 nodes, 3,777 streets.
- smoke 11 + sim 47 green locally (21:10). Flow was running at pause (see Running jobs).
- Captures (lead review, not shown to the director): shared notes folder
  real-city-captures/ (bake_v1 preview, top_down, aerial, gameplay start/mid). Grid, Yarra,
  Flinders St yards, Fed Square, Birrarung Marr, Southbank skyline all read correctly.
- Bench: NOT valid yet. Both runs shared the GPU with another agent's Godot (PID 290008,
  49%): generic and CBD both 18 frames in 30 s at 4K. Rerun on an idle GPU.

## Next (when resumed)
1. Rebase onto look-options after PR #7: CityGen.map() now gives nodes/streets/blocks and
   Traffic/Police/StreetLife run on it. Make CitySource.plan() return CityDistrict.plan() for
   districts and route city_ground/city_skyline/decor/traffic through it; then drop my
   district_ground street drawing if city_ground can draw graph streets (keep water/rail).
   StreetLife walks block pavements: districts have no blocks; derive blocks from the street
   graph faces, or give StreetLife a pavement-along-streets mode.
2. Kaiju_pos/arena changes conflict with PR #7's rampage_sim (arena_margin): keep the Rect2.
3. Bench on an idle GPU (generic vs CBD, 4K, 30 s), then capture vs an OSM tile render.
4. Credits screen line (ODbL obligation) before any build ships with a district.
5. Scale call for the director: 10 m/unit (about 1/3) not 1/4: at 14 m/unit 30 m streets are
   2 units, narrower than a car is long. Ask with the ask-the-director skill.

## Rules learnt the hard way
- Python write_text on Windows writes CRLF: pass newline="\n" (.gitattributes wants LF).
- focus-guard needs override.cfg to exist before the command that runs Godot (separate call).
- Fog hides the map from 300 units up: overview captures switch it off, gameplay keeps it.
- Ground built with SurfaceTool: disable culling or check winding; quads came out facing down.

## Running jobs
None after this commit. override.cfg removed. tools/osm/cache/ holds the raw OSM pull (keep;
re-fetching costs Overpass fair use).
