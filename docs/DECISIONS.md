# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. Only the merge role edits this file, from the "Board and log" section of merged PRs.

## 2026-10-16 · D-028 · Director · Buildings must match the kaiju's fidelity
Why: "our kaiju models look so good that they make the buildings look shitty, can we up their
fidelity". Kaiju are ~16 voxels per floor-unit, buildings 4. Changes: city-layout raises building
RES (8-12) with recessed, framed facades and rooftop clutter, distance LOD if perf needs it.

## 2026-10-16 · D-027 · Director · The game targets a 4K 120 Hz TV
Why: "i want the game to display on a 4k tv" (Beyond TV, 3840x2160, 120 Hz VRR, HDR, 400 nits).
Changes: starts fullscreen, stretch aspect "expand", adaptive vsync (VRR); UI stays a 1920x1080
canvas scaled 2x. The TV is plugged into the 4070 SUPER (director, 2026-10-16). Still open:
TV-distance text sizes, HDR output, perf at native 4K.

## 2026-10-16 · D-026 · Director · Ability powers get proper VFX and SFX (later milestone)
Why: "we will eventually need some nice vfx and sfx for our powers/abilities that we will unlock".
Changes: none yet. Any SFX source must clear the licence register first.

## 2026-10-16 · D-025 · Director · Smoke must not obscure the camera view
Why: "a little smog in the camera is good and immersive, too much and it just ruins the view".
Changes: smoke.gdshader fades smoke near the camera (clear inside 8 units, full from 22) and keeps
55% of it over the screen centre where the kaiju stands. This is the rule for every future smoke,
dust or fog effect.

## 2026-10-16 · D-024 · Director · The city must read as a real city with believable edges
Why: "it seems like our city exists in a void... far too gridlike"; "not saying our map has to be
infinite, but it has to make sense visually". Changes: helper session city-layout (branch city-layout).

## 2026-10-16 · D-023 · Director · Tripo credits: quality over cost
Why: "dont worry about credit cost, just get good results, the credits ar there to be spent".
Changes: no per-session cap for kaiju/vehicle/landmark generation; every task is still logged in
docs/provenance/tripo.md.

## 2026-10-16 · D-022 · Director · The insectoid is a mantis: two raptorial arms plus four legs
Why: "the insectoids are looking a bit armless, they should have legs and arms"; "keep pursuing
the mantis look". Changes: adult = mantis_a (Tripo 9668b815); the rig needs a hexapod skeleton.

## 2026-10-16 · D-016 · Director · ~1,000 Tripo credits approved for 9 rig-ready kaiju this session
Why: "Yes, ~1,000 credits". Smart Mesh P2.0 (100 each, 4 variants per run) + auto-rig (~20 each).

## 2026-10-16 · D-015 · Director · Every kaiju is animatable, with physics on tails, limbs and antennae
Why: "all must be animatable too"; "i want nice physics for the tail/limbs/antennae".
Changes: kaiju become skeletons carrying voxel chunks per bone; spring-bone physics on tail chains,
antennae and tentacles. Rig-ready meshes (Smart Mesh), Tripo auto-rig for the reptile, Blender rigs
for the insectoid and cephalopod.

## 2026-10-16 · D-014 · Director · Three models per kaiju: baby, adolescent, adult
Why: "we should probably have 3 models per kaiju though". The first reptile sculpt: "he looks
wonderful" (adult). Stages map to the evolutions: baby (start), adolescent (EVOLVE 1), adult (EVOLVE 2+).

## 2026-10-16 · D-021 · Director · Game font: "Kaiju Claw" (direction B) for headings and big buttons
Why: picked from the A/B/C font board (docs/captures/2026-10-16-font/font_board.png) in the font
session. Ours (built with fontTools); body text below 36 px keeps the default font. PR #4.

## 2026-10-16 · D-020 · Director · Tripo sculpts for military vehicles and landmarks (~350 credits)
Why: "do military vehicles and landmarks". Tank, attack helicopter, fighter jet, APC; stadium, radio
mast, bridge. Vehicles voxelized as rigid models (rotors/turrets split); landmarks voxelized and cut
into structural chunks so they still collapse.

## 2026-10-16 · D-019 · Director · Civilians and moving traffic in the streets ("we also need civilians in the streets", "cars, etc")

## 2026-10-16 · D-018 · Director · Smoke dialled back ~15% for visibility (opacity and particle count)

## 2026-10-16 · D-017 · Director · A unique game font that fits the flavour (queued after the kaiju)

## 2026-10-16 · D-013 · Director · Terrifying monsters, not toys; buildings are real structures
Why: "the kaiju currently look like childrens toys, they should look like terrifying monsters";
"towers falling like jenga ... they should be actual structures"; "need shaders and particle effects".
Reference footage: WATCH THIS.mp4 (CityV voxel destruction) and the CG Cookie detailed-voxel trailer.
Changes: Structure (chunks, support, drops, toppling), dust/shockwave/sparks, kaiju rebuilt from models.

## 2026-10-16 · D-012 · Director · Kaiju models come from Tripo, voxelized in Blender
Why: realistic anatomy and skin texture in dense voxels (the raptor in the reference trailer).
Spend: approved at "roughly a few hundred credits per species with retries"; the lead asks before
going past 500 credits in one session. Every model passes a six-view inspection before use; every
task id, credit cost and verdict goes in docs/provenance/tripo.md.

## 2026-10-16 · D-010 · Director · Real light sources; no sterile lighting
Why: "lighting is very sterile too, should be real light sources in the game". Changes: evening sun
with long shadows, streetlamps that light the street, lit windows, burning ruins and wrecks, muzzle
flashes, explosion and breath light, screen-space bounce light. The evening setting is the lead's
pick for making lights read; the director may move the time of day.

## 2026-10-16 · D-009 · Director · The kaiju starts young, outscaled by the city, and grows as you play
Changes: body scale = young 0.5 x evolution tier x (1 + 2% per upgrade level owned); reach grows with it.

## 2026-10-16 · D-008 · Director · Look C (Concrete Realism), far more detailed; more voxels
Why: chosen from A Toy / B Night / C Concrete on the labelled board; "theres not enough voxels".
Changes: buildings at 4 voxels per floor with window grids, sills, balconies, awnings, roof gear;
kaiju at 5 voxels per design unit with teeth, claws, scales, plates; streets with lane markings,
cars, trees, streetlights that flatten underfoot. Looks A and B removed.

## 2026-10-16 · D-007 · Director · The third species is the Cephalopod
Why: chosen from Cephalopod / Primate / Crystalline / Mechanical; the clearest contrast to a brawler
lizard and a fast bug. Changes: data/species.json, Tentacle Lash (ring attack, huge reach, slow).

## 2026-10-16 · D-006 · Director · Players choose a species at the start: Reptilian, Insectoid, a third
Why: customisation. Each species has its own body, stats and signature attack (rule: a choice must
change play). One species per save; "New kaiju" starts over. Changes: species select screen.

## 2026-10-16 · D-005 · Director · Voxel graphics
Changes: buildings, kaiju, army and debris are voxels; destruction removes layers and spills blocks.

## 2026-10-16 · D-004 · Director · Controls: move + auto attacks, one signature button
Why: focus on positioning and builds; works on controller and the TV.

## 2026-10-16 · D-003 · Director · Short rampages (1-3 min) between visits to the upgrade tree
Why: tight loop, the evolution tree is the spine (Nodebuster / Brotato shape).

## 2026-10-16 · D-002 · Director · Active action game, NOT idle: deep upgrade tree, deliberate pacing,
3-5 hours of content, zero AFK progression
Why: director's words at kickoff. Changes: nothing accrues while closed; no passive income.

## 2026-10-16 · D-002a · Lead · Godot 4.7.2, PC first with a web export; private GitHub repo
Why: director chose Godot (PC + web). The repo-visibility question went unanswered; private is the
standard default and is reversible.

## 2026-10-16 · D-001 · Director · Kaiju Incremental is started with the shared kickoff scaffold
Why: the project-kickoff skill (~/.claude/skills) produced the repo skeleton: CLAUDE.md, CI with
check floors, PR template, board and log, project skills extending github-hygiene and
game-architecture.
Changes: the first commit.
