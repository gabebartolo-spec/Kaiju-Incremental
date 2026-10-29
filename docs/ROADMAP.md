# Roadmap

Cap: 600 lines; finished work and dated detail roll to `docs/roadmap/` and `docs/archive/`. Read by section, never
whole. A phase has deliverables, a gate and what is still forbidden after it. No roles (director 2026-10-29): a row's
owner is whichever session takes it and reports to him. The director decides; a roadmap row is context, not authorisation.

## Index (read this, then only the section your task names; grep the rest)
- Phase 0, 1, 2 (the demo)
- Live work, in order
- Playtest milestones
- Flat surfaces programme
- Parked and after the demo
- Moved out, unchanged (grep there): `docs/roadmap/2026-10-20-post-demo-plan.md` (phases A-H with the 10-21 research,
  10-22 comment rows), `docs/roadmap/2026-10-23-24-motion-reptilian.md` (Motion first, Reptilian models and skins),
  `docs/roadmap/2026-10-23-26-sections.md` (10-23 overnight, interview answers, director comments; 10-26 interviews).
- Trackers: `docs/roadmap/2026-10-27-tech-debt.md` (debt rows), `docs/roadmap/2026-10-27-destruction-plan.md`,
  `docs/roadmap/2026-10-28-unlanded-audit.md` (branches not on main), `docs/roadmap/2026-10-28-director-comments.md`
  (his latest comment rows), `docs/roadmap/2026-10-28-grown-croc-verdicts.md` (37 clips, 8 SHIP, 29 FIX).

## Phase 0, 1, 2 (the demo)
- Phase 0 foundations and Phase 1 visual and factory proof: done (the look picked, D-104 / D-105 / D-285).
- **Phase 2, the vertical slice, is the live phase.** Demo (D-050, D-145, D-212): the croc only, all three cities
  (baby, adolescent, adult) with the full Taskforce, a Windows exe, about 2 hours to the thanks screen and endless mode;
  dusk only (D-359). Gate: his playtest of the demo exe (the Playtest milestones below). Forbidden until then: balance
  tuning (D-363 "until the game is beautiful and working"), paid audio (spend yes first), new species.
- Playtest records: `docs/roadmap/2026-10-19-director-playtest.md` (exe 1), `docs/roadmap/2026-10-20-build2-playtest.md`
  (carving build 2; "b2-N"), `docs/roadmap/2026-10-20-director-comments.md`, and the dated comment files after them.
- Only what the demo needs is tested (director 2026-10-29): the reptilian; other species' suites are parked
  (tests/parked/). The far insectoid stays as the skyline beast.

## Live work, in order
Each row: what, where it stands, next. A row leaves this list when its PR merges (its decision and PR number are the
record); nothing is appended as a log. D-310 order: debt fixes, then parked work; creature animation runs alongside (D-354).
1. **Croc animation, keyed in Cascadeur (D-199, D-302, D-362):** young croc walk and turns rebuilt (#405), adult eyelids
   and rise clips (#398), collar bones (#410), claw rake (#332), beam_jaw (#392), Colossus helper joints (#396).
   Open: the 29 FIX clips of the grown
   croc verdicts; the baby jaw (neck0-2 split into game bones); the Komodo and serpent clips wait with their species.
2. **Bay-coast junction spacing (director 2026-10-29, after #413):** fixed in city-gen: CityLineFit.x_rule keeps the diagonal's crossings an avenue's clearance off the bay's pinned back street (z -7), as it does the ring z-lines; city audit "close!" holds on every seed with no exemption (the _at_bay_coast one never reached main). PR open, claude/bay-coast-junctions.
3. **Destruction (D-327, in the demo):** stage 1 (carved buildings drawn from the sim's cells, #328) and stage 2 (native
   carve colliders, merged falling islands; render items 10 and 11, #381) are on main. Open: landmarks carve on cells and
   river/bay bridges become carved structures (carve is universal, director 2026-10-26; tests/run_structures_tests.gd
   names them as known failures), varied collapse directions (b2-5), the stadium crowd falling with a broken stand
   (comments #17). Plan: `docs/roadmap/2026-10-27-destruction-plan.md`.
4. **Random cities (D-259, D-261, D-263, D-375):** a fresh city each run from shuffled blocks, the landmark pool drawn
   into tiered spots. Open: sim/city_seed.gd ignores the save seed (replays differ per slot: D-261, D-263); the pool
   and spots per D-375 (stage 1 shows the east spot only, D-380).
5. **Upgrade tree (D-275, b2-28):** rings per species, 2-3x the nodes, his croc node ideas first
   (`docs/roadmap/2026-10-26-interview-audit.md` section 1), an upgrade affordable after every rampage; the tree screen
   skin follows. Balance itself waits (D-363). Throw nodes "Ricochet" and "Domino" (D-259); the tail lash's nodes (D-329).
6. **Render plan and performance (D-276, D-300, D-312):** items 0-4, 6-9, 12-14 merged and on; item 5 parked (D-192 bar);
   item 15 (Medium GPU p95, 0.3-0.9 ms over the bar at the 10-28 re-baseline, `docs/research/2026-10-28-render-rebaseline.md`)
   PARKED (D-372). Graphics presets Potato..Max exist in data; the live preview in the options menu (comment #90) and the
   measured per-preset audit at 1080p and 4K (b2-25) are open, after the visuals are final.
7. **Tech debt (`docs/roadmap/2026-10-27-tech-debt.md`):** rows 15 (file and long-function caps: baseline 22 of 33) and 21
   (procedural creature animation, row 1 above) are the open ones; the rest are done.
8. **CI (D-351, D-382, D-383):** countable speed-run bars run as GitHub checks; a PR skips the 13 slow second-angle
   suites (the `pr_skip` line of tools/ci_timings.txt), which run on main; no local suite runs, push and CI is the test.
   Open: the first push-to-main run after #412 proves the slow job.
9. **Sound and music:** croc takes made ("Croc now, others later"); the Godzilla set (D-184) on the menu and as the three
   city Covers; collapse voices (D-367); layered music and the menu theme (#423). Open: wider-city pacing waits for
   balancing (D-366); Suno only after his written spend yes.
10. **Demo shell (M3 below):** textured surfaces (Flat surfaces programme), the graphics preview, load-screen art (about 12
   staged 4K shots on one board, he picks), the demo end screen and feedback button, six languages plus Chinese.

## Playtest milestones (D-146, 2026-10-22)
The director plays only at these; each gets an exported .exe in a fixed folder and an exhaustive survey for that game
state. No per-change approvals in between; stills and clips only where the look or the motion is the point.
- **M1 Feel pass:** fire spread, heavier turning, bigger explosions, post effects, the new title screen, the clumsy army,
  three growth steps with wider cities, the bay start, momentum (D-337), the leap (D-361), atmosphere (D-155: rampage
  escalation, sky and sea life, weather; the demo plays at dusk, D-359), city sound and layered music.
- **M2 Taskforce agents:** jetpack agents with railgun and frost, in the adolescent city (sim/taskforce*.gd built;
  judged in play).
- **M3 Demo complete:** the full Taskforce (gas soldiers, walking mechs, gunships), textured surfaces, helicopter deaths,
  the graphics preview, load-screen art, the demo end screen and feedback button.
- **M4 Itch release candidate (D-132):** M3 survey fixes only; invite-only Itch page when the reptilian stage is 100%
  done: bug free, polished visuals, good performance, fully featured.

## Flat surfaces programme (director 2026-10-25: "flat textureless colour blocks need to go")
P0 (roads, quays and river walls, bridge decks, pavements, lawns, expressway, rubble) and P1 (river and bay water, #388)
are textured through scenes/surface_detail.gdshaderinc or their own shaders; the CI test tests/lib/flat_surfaces.gd fails
any other untextured surface. Its KNOWN_FLAT list (20 entries, cap KNOWN_FLAT_MAX 20) may only shrink: texture the
surface, delete its line, lower the cap. Phases: P2 rooftops and building faces (target 2026-10-31), P3 props, people,
cars, aircraft, debris, the stadium, the kaiju (target 2026-11-04).

| KNOWN_FLAT entry | Surface | Phase |
|---|---|---|
| CitySkyline:std | lamp heads (glow boxes on the far skyline) | P3 |
| CitySkyline:shader:facade.gdshader | far-city towers, roof gear, lattice tower | P2 towers and roof gear, P3 tower |
| CitySkyline:shader:facade_far_fogged.gdshader | hazy far towers, lattice tower (FarHaze twin) | P2, P3 tower |
| BuildingStream:shader:facade.gdshader | building faces (stream) | P2 |
| BuildingView:shader:voxel.gdshader | building faces (voxel) | P2 |
| RooftopView:shader:voxel.gdshader | rooftops (flat black stripe, window panels) | P2 |
| RooftopView:std | rooftop gear | P2 |
| Aircraft:std | aircraft | P3 |
| DebrisField:std | debris chunks | P3 |
| CityDecor:shader:voxel.gdshader | trees, lamps, props | P3 |
| Traffic:shader:voxel.gdshader | cars | P3 |
| StreetLife:shader:voxel.gdshader | people | P3 |
| Police:shader:voxel.gdshader | police | P3 |
| StadiumMatch:shader:voxel.gdshader | stadium | P3 |
| StadiumMatch:std | stadium | P3 |
| StadiumCrowd:shader:crowd.gdshader | stadium crowd | P3 |
| ArenaEdge:std | arena bollards | P3 |
| KaijuRig:shader:voxel.gdshader | the kaiju's own skin pipeline | P3 |
| VoxelSkin:shader:voxel_skin.gdshader | the kaiju's skin | P3 |
| VoxelSkin:shader:voxel_skin_fill.gdshader | the kaiju's skin fill | P3 |

## Parked and after the demo
Recorded, not being built; each returns in D-310 order or when its gate opens. Detail for every row is in the moved-out
files above and in `docs/DECISIONS.md` by its D-n.
- **Komodo dragon and serpent (D-197, D-206, D-251, D-310):** Komodo walk "ship it", lands OFF by default; branch
  claude/komodo-land (06c88b38, not on main), komodo mouth tooling claude/komodo-mouth-49564a. Serpent redesign waits for
  his pick (D-246). Reptilian idle states (D-210), sounds (snorts, hisses, rattle), skins (D-221..D-226 "earned by
  playing"), head evolutions (D-171) follow their species.
- **Hatchlings (D-358):** a late Colossus node; one purple-crackling egg spewed from the maw per rampage hatches the
  species' baby form, which rampages on its own. When built: ask him the biomass mark, judge the spew move from one clip;
  the sim needs a seeded autonomous baby (seek, attack, devour).
- **After the demo (D-083 order, playtest fixes first):** rooftop mortars (research 24); the Taskforce commander
  mini-boss; the mecha boss finale (D-211, D-227, D-230; research 23, 3-5 weeks); fire crews (comment #50, after fire
  spread is judged); background city rampage on the far skyline (comment #16); achievements and about 8 croc recolour
  skins (comment #95); the Threat Dossier bestiary (D-147); light narrative briefings and bonus goals (comment #76);
  screen-space reflections on Max (D-142); random time of day and weather per run (D-106, D-155; dusk only in the demo,
  D-359); ElevenLabs SFX pass and Suno music (both need his written spend yes and a CLEARED register line first);
  languages Spanish, Japanese, French, German, Russian, Italian; full-game destruction option A (D-094); real OSM cities
  (D-029, tabled).
- **Expansion (D-212):** a mammal, an avian, an aquatic, build-your-own kaiju from presets; mantis and octopus stay
  stretch goals (meshes kept, plan only, D-060).
- **Open for the director (ask at its phase):** walk speed vs cadence if the long stride cannot fit (R 11.2) · camera
  growth per stage, A/B/C clips (R 19) · the serpent's final design (D-246) · when body contact carves vs yields (R 13.3)
  · rampage timer start and ceiling (R 1.2) · which throw upgrade nodes beyond Ricochet and Domino (R 22.4) · the
  tree's map layout from labelled captures (R 16.5) · fire: a spark source for non-breath species, wind fixed or drifting
  (research 26) · how hard fire crews fight · the finale's shape and mecha concept board (R 23.1).
