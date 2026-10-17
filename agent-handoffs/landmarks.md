# Landmarks handoff, 2026-10-18 07:50
## State: running a check (fresh critic on board round 4)

## Task
Original city landmarks, modelled in Blender and voxel-baked so they break chunk by chunk like any
building, wired in through data, PR into claude/look-options to LEAD ("Kaiju: Lead",
local_106fc100...): 8-line body, Auto-fix off, never merge. Director prompt: "dont forget we can create
our own models in blender, but maybe you should work on some landmarks". Director (via the old lead):
"use tripo if results in blender are poor". Blender results are not poor, so Tripo was not used.

## Branch and commit
Worktree ../Kaiju-Incremental-wt/landmarks on claude/landmarks (from origin/claude/look-options 7911400).
No PR yet.

## Done
- Board r1 (notes landmarks/board1): six concepts. LEAD's 2x check passed; the fresh critic said FIX on
  every panel (board1/critic.md). Round 2 fixed it all: stadium piers and ribs, gate rebuilt (tall
  pillars, passage, steps, free-standing lanterns), clock-hall gable + hipped roof + 4 faces with
  hands, wheel polygon rim + drum hub + outside capsules, spire ring-stepped shaft + flat roof,
  megatower open crown. Plus a side-view scale strip and "units" in the captions.
  Board r2 (board2/): critic r2 passed B and E and asked for fixes on A, C, D and F. The round-3 fixes
  are done: stadium piers flush (and the caption now says bowl 7 floors), every clock reads 3:00 with
  dark belfry openings, wheel hub raised over a lower hall, megatower axis-aligned (rotated floors
  aliased) with a crown of tapering points, croc staged clear of bases. Critic r3: A, B, E PASS;
  C, D, F FIX -> r4: portico gable roof, dial rings + 10:10 hands, side windows; wheel rim complete
  (brace removed) with the hall centred under it; megatower a glass row per floor + straight stepped
  crown points, caption "45 floors + crown"; small red lanterns in the gate passage. Board r4
  (board4/) is with a fresh critic (board4/critic.md). Megatower is now ~706k raw voxels (Perf note).
- For LEAD, outside my scope (critics r2/r3): the City 1-2 croc (adolescent scaled down) has its tail
  hanging straight down so it reads as a third leg; the City 3-4 croc's pale back plates on an upright
  body may read as a Godzilla silhouette. Those belong to the croc model's owner.
- Full suite green on db908ac (smoke 27, sim 39, powers 24, tentacles 18, city 11, growth 24, load 9,
  flow 109, harness self-test). City + load re-run green after the r3 stadium rebake.
- The director question is tabled for his morning by LEAD: "which landmarks per city"; I recommend
  A stadium -> D wheel -> E spire -> F megatower (the demo needs only A + D).
- Code (stadium as the test model; city 1 gets one under every option):
  - assets/source/landmarks/build_landmarks.py (all six, Blender from code) + stadium.glb;
  - tools/landmarks/bake.py: raw voxelize.py shell -> assets/landmarks/<id>.kvox (building-local
    cells, flags = 6-bit mask of faces open to outside air) + data/landmarks.json (w, d, h, kvox,
    chunk mask = chunks holding a voxel or sealed air);
  - scenes/landmark_voxels.gd (extends BuildingVoxels, facade off, cached kvox); BuildingMesher
    uses DIRECT colours and the face mask (mask -1 = old path); BuildingView picks LandmarkVoxels when
    b.landmark != "";
  - sim: sim/landmarks.gd builds every Building from its entry (moved out of RampageSim: 400-line
    cap); Structure.keep(layers); Building.landmark / rubble_bonus; chunks_total += alive_count;
    pay() x rubble_bonus. Content.landmarks().
  - tests: city +5 (mask rows, keeps exactly its chunks, stands as built, destruction counts real
    chunks, player-effect 3x pay), load +3 (no stray voxels, open faces only, debris samples).
    Floors: city 6 -> 11, load 6 -> 9.
- Licence rows added (landmark models, bake tool).
- Sim-review packet draft: notes landmarks/sim_packet.md.

## Recipe
blender -b --factory-startup --python assets/source/landmarks/build_landmarks.py -- <dir> stadium
blender -b --factory-startup --python tools/blender/voxelize.py -- <dir>/stadium.glb raw.kvox <round(h*8)+1>
python tools/landmarks/bake.py raw.kvox stadium
Board renders: notes landmarks/src (board_render.py, lineup.py, compose.py), Cycles on the CPU.

## Next
1. Critic r2 verdict -> fix -> LEAD QA -> director pick (LEAD asks).
2. After city-calm's D-062 merges (LEAD pings): the landmark site in CityGen.map() (merge the blocks
   under a data anchor into a plaza, drop the inner streets), tuning city.landmarks [{id, district,
   anchor, tier, rubble_bonus}], city_ground/decor draw the site; city-calm reviews the city_gen diff.
3. Bake the picked ones; CI 1080p stills standing/destroyed + 2x crop of the break (capture.yml, one
   at a time); Perf bench (megatower is ~500k raw voxels).
4. PR to LEAD with the sim packet; kaiju-sim-review by LEAD.

## Open decisions
- Director: which landmarks per city (tabled by LEAD for the morning).

## Findings for the lead
- voxelize.py shells surfaces only: a solid disc bakes as a cap. Build open parts as real rings
  (a boolean annulus). The stadium bowl was a white lid until that fix.
- Slow tapers (cones) and thin tori bake into stair-step streaks and lumps at 8 voxels per floor.
  Constant-radius stacked rings and straight-segment polygons bake clean (critic r1 -> r2).
- Blender renders on CPU Cycles need no GPU slot (15-30 s a panel).

## Rules learnt the hard way
- gdlint caps files at 400 lines: rampage_sim.gd was at 399; move code out rather than squeeze it.
- gdformat on Windows writes CRLF; convert back to LF before committing.
