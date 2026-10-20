# Roadmap

Cap: 600 lines; finished phases roll to `docs/archive/`. Read by section, never whole. A phase
has caps, deliverables, a gate, a signer, and what is still forbidden after it. Nothing scales
before the vertical slice proves the core loop with the director playing it.

## Phase 0 — Foundations
Deliverables: the scaffold green on main; the deliberately broken PRs rejected; the document pack.
Gate: every item in `docs/STATUS.md` Phase 0 done; CI red on each planted defect.
Forbidden after: still no content beyond the slice.

## Phase 1 — Visual and factory proof
Deliverables: one capture stage, one character at game scale, the look chosen from labelled
captures by the director, the asset pipeline proved by rebuilding one asset byte-identically.
Gate: director look approval recorded in `docs/DECISIONS.md`.

## Phase 2 — Vertical slice
Deliverables: the core loop playable end to end with placeholder content; player-effect fixtures
for every system; save, reload, continue.
Gate: a director playtest; the slice success test the vision names.
Demo (D-050): the croc line only, hatchling to Behemoth, a Windows exe; the director's playtest of it is this gate.
After the demo (D-083 order: playtest fixes first): better sound effects (ElevenLabs) and music (Suno), director
2026-10-19. Both are paid for commercial use: the director's written spend yes in `docs/DECISIONS.md` and a CLEARED
line in `docs/LICENSING_REGISTER.md` come before any generated audio enters `assets/`.
Also after the demo (director 2026-10-19): rooftop mortars (topple the building to kill them); a final boss, a mecha
kaiju built to fight you; languages Spanish, Japanese, French, German, Russian, Italian (one text table, CJK +
Cyrillic fallback fonts CLEARED, native-speaker review); full-game destruction option A (D-094).
Director playtest of demo exe 1, every note with owner, PR and status: `docs/roadmap/2026-10-19-director-playtest.md`.
Director comments of 2026-10-20 (shockwave, carving build goal): `docs/roadmap/2026-10-20-director-comments.md`.
Carving build 2 playtest, every note with phase, owner and status: `docs/roadmap/2026-10-20-build2-playtest.md`.

## Post-demo plan (2026-10-20, director: "sort it into the roadmap, put it in a chronological order")
Every open item in one order, so nothing is built on something still subject to change. A phase starts when the
one before it has merged; inside a phase the lead and the one Opus builder (director 2026-10-20) take items two at a time. "b2-N" = note N of
`docs/roadmap/2026-10-20-build2-playtest.md`; "p1-N" = note N of `docs/roadmap/2026-10-19-director-playtest.md`.
Each phase ends with a build the director plays (its gate). Copy rule (b2-15/16/17/24/27) applies to all player text.
"R n.m" = recommendation m of research file n in `docs/research/2026-10-21/` (director 2026-10-21: "i quite liked all
its suggestions ... incorporate the best findings into our roadmap"). Costs and sources are in those files.

**Any phase, now (objectively good, no decision; a builder takes them between phase items).**
Distance fade on every lamp, fire and beacon light (R 12.1) · pool positional lights to about 24 real ones, the rest
emissive + glow, so gl_compatibility's 32-per-frame cap never drops lights at random (R 12.2) · audio buses: master
HardLimiter + one Hero (roar, stomp, big collapse) to Bed sidechain duck, values in data (R 8.1) · tentacle Verlet
chains on a fixed 1/60 s substep, their tunables into data (R 9.1) · "no empty space" as a suite: built footprint per
district, no built block with zero lots, max gap along a street, a timing line per stage (R 6.1) · a headless parse
step on every agent-written script (Godot 3 names) (R 5.6) · graphics: the existing `display.graphics` table (high,
balanced) grows to Potato/Low/Medium/High/Max rows and Medium gets MSAA 2x under FSR1 (balanced runs FSR without AA,
which the docs advise against) (R 18.1) · bugs found by research 20: a dash, signature or ultimate pressed in the
last 0.2 s before control returns is dropped (latch it for the first live tick, with a scripted-input test) (R 20.3);
the evolution reveal counts frames, so it lasts 3.8 s at 60 Hz and 1.6 s at 144 Hz (count fixed ticks) (R 20.5) ·
the camera's zoom curve (hard-coded 0.75 + 0.4 x body scale) into data, with a test that the kaiju's screen share
rises every stage and stays at or under about 35% (R 19.1).

**A. Close what is in flight; fix what no later choice changes.**
WP7 carving physics (D-099, claude/carve-wp7 e50b0be, resynced, tests then PR) · board PR (D-100..D-103, this
chapter) · repo CLAUDE.md + kaiju-handoff skill to the 300k/500k context rule · b2-6 every building in the play area
destroyable, any that cannot be is removed from it · b2-21 stadium placed as far from the spawn as the map allows ·
b2-26 atomic breath hurts trees · a destroyed building stays rubble, never a burning shell (comments #14, #111) · the kaiju rises out of the river water, never the asphalt (comments 2026-10-20 #10) · b2-2 first half: find out why the tail swipe does not fire, fix that bug only ·
p1-9 confirm in play that the south-of-spawn buildings are gone (#88) ·
worktree and branch cleanup. Gate: build 3.

**B. Look foundations: director decisions, captures only, no production code.**
These change scale, density and framing for everything after, so they come first. b2-20 voxel vs a non-voxel look
(labelled captures of the same street) · b2-19 voxel count down / today / up, same shot · b2-7 camera angle and
distance (done: D-105 framing C, low and cinematic; open: how it grows per stage, his pick of A today plus
look-ahead, B grows on screen to about 34%, C low hero at adult (pitch to about 15 deg), each a 2x2 clip of stages 1
and 4 (R 19, framings)) · shaders: a few candidate looks (lighting/post/material shaders), side by side at
morning, noon, dusk and night, he picks one (director 2026-10-20) · heli-cam A/B (parked; folded into the camera choice). Gate: his four picks
recorded in DECISIONS.
Research inputs to these boards: one shader candidate is Godot's own toon shading + a next_pass outline (R 7.1); every
candidate puts a low sun or moon behind the kaiju with fog sun scatter and aerial perspective, normal bias (not bias)
raised for voxel edges (R 12.3), and a time-of-day rim light plus a warm fire under-fill on the kaiju only (R 12.4);
haze thickens with stage (R 2.5); shake rebuilt as trauma squared on smooth noise, rotation only, capped at 2-3 deg,
heavier per stage, with one camera-motion setting (R 19.2); look-ahead toward the move input after a 0.3 s hold
(R 19.3); BuildingFade fixes (a carved stump never fades) before any cutaway (R 19.4); the camera candidates pull back less than the kaiju grows and keep cars, people and
bollards near its feet in frame at every stage, so growth never reads as shrinking (R 2.2).

**C. Destruction core, on the picked look.**
b2-4 effortless carving even for a baby kaiju: no building HP, a structure dismantled by physics · b2-5 varied
collapse directions (not always onto the kaiju; revisits D-099's "onto the kaiju" lean) · b2-22 shared walls get
real facades · WP6 follow-ups (landmarks promote to cells; stadium first hit 246 ms = 8 ordinary buildings promoted
at once: spread promotion, one per step) · b2-8 stadium crowd thins over time, never vanishes · stadium spectators on a broken stand fall or die, never hang with their feet in the air (comments #17) · b2-3 slow frames in heavy destruction
(profiled 2026-10-21: every worst frame is sim.step, VoxelFrame.settle's ground flood 50-60% and Carving._promote
20-25%; the 823-piece rubble cap is not wired into the game) · b2-30/b2-29 start and quit freezes (done, #116).
How (research): settle becomes a bounded flood fill from the cut cells to ground anchors, on a coarse brick graph,
cost scaling with the island not the building, in the C++ carve library if GDScript is still too slow (R 10.2) ·
toppling stays a seeded hinge fall the sim owns; Jolt never decides an outcome (Godot's Jolt is not replayable) (R 10.1)
· debris is presentation only: a MultiMesh per area with shader ballistics seeded from the sim event, settling into
rubble; dust and chips as GPU particles over one camera-following heightfield collider (R 10.3, 10.4) · the sim emits
one size-bucketed break event per cluster (material x small/medium/large from energy), the hook for sound (R 8.3).
Gate: build 4.

**D. Kaiju body and combat feel.**
Turning with weight: lumbering and unstoppable yet responsive, the head turns toward the new heading before the body follows, no sliding pivot (comments #16, 2026-10-20) · b2-1 claw and arm animation reads as a swipe, no twitching · b2-2 tail as an autonomous extra limb · b2-9 tanks
shoved and flung into buildings, people and vehicles (uses C's physics); found by research 22: a thrown tank today
flies a straight line through towers (a 0.7 s timer, one blast where it lands), kill credit is paid at the grab, and
the ram may leave a tank inside a building; how: the throw arcs in the view first (R 22.1), then becomes a sim
ballistic at a fixed step that sweeps cells, carves the building it hits through Carving.hit and pays credit at
landing, with pinned-seed tests and a sim review (R 22.2) · the ram launches the tank low instead of teleporting it,
and a survivor re-joins its road (R 22.3) · capped chain hits on other units, the hook for upgrade nodes he picks
(ricochet, domino, wrecking ball) (R 22.4) · people and parked cars tumble along the path as presentation (R 22.5) ·
Jolt throws only turrets, tracks and panels, never the hull (R 22.6) · hit-stop by skipping sim steps, never
Engine.time_scale (R 22.7) · b2-18 breath VFX pass, re-themed from atomic to hot lightning: forked white-hot bolts, scorch and sparks, the name
and every "atomic" word in player text changed in the copy pass (director 2026-10-21; sim rules unchanged). How
(research 17): one ribbon mesh replaces the straight beam: a main channel from the jaw to the first hit, its shape
fixed for the breath, and 3-5 branches fanning across the sim's BreathCone that re-draw on each stroke (R 17.1) ·
one stroke schedule (a dim feeler, then 2-3 bright strokes, never more than 3 flashes a second, no saturated red)
drives the pooled lights and the zap, crackle and thunder sounds (R 17.2) · a per-breath presentation seed, never the
sim's (R 17.3) · in gl_compatibility the halo is real geometry because glow is LDR (R 17.4) · arcs to struck vehicles
only if the fan alone does not read electric (R 17.5) · run intro: a <=3 s shot, close on the water that ripples and fountains, the kaiju bursts out roaring, the camera pulls out to the play angle (#11); how (research 20): the sim's rise retuned to fit 3 s (today about 3.5-5.5 s) with a
180-tick test (R 20.1), the intro camera driven by the rise's own progress, no Tween, handing over on kaiju_emerged
(R 20.2), the roar on the surface break (R 20.3), full intro on the first run and after an evolution, a 1.5 s cut
otherwise, any press skips by running the sim ticks faster so replays match (R 20.4), the run starts at last run's
zoom and eases out so growth shows (R 19.5) · evolution reveal polish: low start, tilt up the tower, silhouette pulse
(3 a second or fewer), stinger, bars (R 20.6, his taste) · water that reacts to the kaiju with physics (#12); how (research 21, presentation only, both renderers): the flat
glossy river becomes one shader on a subdivided plane, rippling from the last 64 sim events (stomps, sweeps, falls,
throws, footfalls in a channel) on the sim clock, with stepped flat toon tones (R 21.1) · a wake V and bow foam while
wading, a bulge before the head breaks the surface, foam round the body during the rise (R 21.2) · cube-droplet
splashes and water sheeting off the body as it rises (R 21.3) · rubble that reaches the water floats on the same
ripples (R 21.4) · foam lines where the water meets quays, legs and rubble (R 21.5) · the bay matches the river
(R 21.6) · #104
follow-ups (ring under the foot renders; leap slam clip) · river splash colour (lost in the #88 resync) · rooftop
hits on legs and tail (#86) · more motion in the shoulders and head while it walks (comments 2026-10-21 #4) · the
walk is "not great" and the turn should step "rather than swivelling on the spot like a plastic toy" (2026-10-21 #3).
How (research), walk: measure cadence per stage first (the adult likely plays about 2.4x its authored rate; pass bar
0.8-1.2x) (R 11.1) · then lengthen the stride, not the cadence: re-bake with duty about 0.70 for the older stages; if
a long enough stride is out of reach at the sim's speed, he picks slower walk vs faster cadence from two clips
(R 11.2) · every footfall lands: pelvis compression, small tail and jaw kick, strength by life stage (R 11.3) · ease
in on starts, stop hard (R 11.4) · each stage heavier: slower turns and acceleration, longer camera shake, per stage
in data (R 2.1). Turn: a planted foot steps at about 25-30 deg of twist, outside foot first, inside foot pivots
(R 14.1) · the body yaws fully only while a foot swings (R 14.2) · head leads, chest takes about half, hips what the
feet allow, tail counter-swings, drawn lag capped at 30-40 deg (R 14.3) · the sim carries the turn rate (the
turn-weight work), the gait only step timing and chain order, never a second layer of lag (R 14, "how this fits").
Body against buildings: tail and tentacle joints pushed out of solid cells inside the chain passes, presentation only
(R 13.1) · feet and grips stand on the roof or rubble under them, with a stretch cap (R 13.2) · body discs for the
cephalopod and insectoid (R 13.4) · he decides the rule for when contact carves and when the body yields (attack,
dash or speed above a threshold; does a fast turn's tail sweep carve?) (R 13.3). Shake and hit-stop: about 40 lines
of our own trauma shake (R 7.2). Gate: clips through the motion critic, then build 5.

**E. Progression: the upgrade tree.**
b2-28 two to three times the nodes · b2-2 tail node · b2-27 drop "reptilian branch" · copy pass b2-15, b2-16,
b2-17, b2-24 and every other node text · then ONE balance pass on the new tree: p1-8 upgrade cadence and the young
retune (#107 draft is superseded by it; its findings are inputs). Balance is his playtest. Gate: build 6.
How (research): an upgrade affordable after every rampage and the first purchase inside about 60 s, costs geometric
(rate about 1.07-1.15) in data, a seeded sim test over the first hour (R 1.1) · rampage timer starts short and grows
through upgrades to a ceiling; start value set by his playtest (R 1.2) · about 1 node in 4 changes what the player
does or sees (a verb, prey, district, the next stage); reveal only the next ring (R 1.4) · the city scales with the
kaiju so the late game never goes AFK (taller blocks, more tanks and helicopters; prestige = harder enemies, bigger
rewards), the genre's top complaint (R 1.3) · target 3-5 h to the ending.
How (research 16, a beautiful tree whose paths set the pace, director 2026-10-21): today the tree thins as the
kaiju grows (11 / 6 / 5 / 1 nodes per stage, 87 levels, gone in about 0.9 h); write 50-65 nodes per species as rings
that grow outward (about 14 / 16 / 18 / 10), each node a `kind` (stat, verb, stage), a cheap 3-4 node burst just past
each evolution and a dearer climb before the next; the pacing bot asserts 1-4 buys a visit, at most 5 runs between
verb or stage nodes, evolutions within 20% of their target times (b2-28 and p1-8 are one sum) (R 16.1) · buying is an
event: the node pops, light runs along the link to each node it opens, the sound rises a step per level, an
evolution gets a bigger beat before the reveal (R 16.2) · the next step shown in full, the next stage as silhouettes,
the next evolution always visible as a landmark (R 16.3) · kind read by shape and size, not colour: small round stat
nodes, larger verb nodes with an icon, the largest evolution keystones (R 16.4) · an outward map that pans but never
zooms, so text keeps its size; it remembers the view, has a home key, and moves itself only for an evolution reveal;
d-pad focus by geometry (R 16.5; 50-65 nodes do not fit the 8 x 6 grid, so b2-28 forces it; layout picked here in E,
skin in F) · last, a flowing shader on owned links (R 16.6).

**F. UI redesign, on the final camera and tree.**
b2-10 HUD: timer stays, biomass a boxless figure bottom right, controls shown once at the start and in a controls
menu · b2-12 breath cooldown as an icon with a circular fill · b2-13 health bar removed or repurposed · b2-11
species select: the kaiju centred, spinning in frame · b2-23 tooltips one fixed width (the ultimate no longer
reshapes the screen) · b2-14 bespoke original UI assets (boxes, cards) for every screen · a screen-shake setting
(R 1.5). Gate: screen critic, build 7.
How (research 15, a really minimal HUD, director 2026-10-21): strip the HUD to his rulings: delete the controls hint,
the HP plate and both plates, keep the boxed timer, biomass one boxless outlined figure bottom right, no HUD text
under 24 px (today's 20 px HP text and "CITY DESTROYED" break it), margins into the TV title-safe area (about 96 px
sides, 54 px top and bottom at 1080p, in data) (R 15.1) · breath as a ring drawn with draw_arc, a pulse and a sound
when ready, bottom centre where the health bar was (R 15.2) · health as a red edge vignette that widens as HP falls,
a heartbeat under about 30% and a hit flash on the kaiju, so it never relies on colour alone (R 15.3) · one shared
outlined text style, checked at 4K for body height and 4.5:1 contrast over the brightest fire (R 15.4) · biomass
rolls toward its value and pops on big gains (R 15.5) · a first-run controls card plus the settings CONTROLS list
from pause (R 15.6) · fixed tooltip width with a test over every node (R 15.7) · a stage-up notice (R 15.8) · later:
a minimal / full HUD setting and a UI scale (R 15.9).

**G. Performance audit, after the visuals are final (his order).**
b2-25 fans and GPU load: a measured audit at 4K, frame cap and per-system cost (light counts and any Jolt body
budget measured on his PC, not taken from published numbers) · graphics settings with five presets, Potato, Low,
Medium, High, Max (director 2026-10-21), built from the audit's per-system costs (shadows, light pool size, SSAO/SSIL,
fog, glow, debris and crowd caps, render scale, draw distance), each preset measured in fps at 1080p and 4K, chosen
in a settings menu that matches Phase F's UI. How (research 18): shadow splits, distance, size, filter, PCSS (first
to go below High), SSAO, SSIL and glow per preset in the live applier, city_view.gd reading them instead of its
hard-coded values (R 18.2) · debris, fire, carve-physics, crowd and civilian caps and particle amount per preset,
applied at the next rampage start (R 18.3) · light pool 8/12/16/24/32 by preset (R 18.4) · default chosen by renderer
and GPU type, then a 4 s frame-time sample that only ever steps down, said once in settings (R 18.5) · Potato =
gl_compatibility behind a restart, last (R 18.6) · the shader baker on for exports, presets applied only from menus
or pause (R 18.7) · CI shard timings (claude/ci-shards). Gate: build 8.

**H. Content after the slice (already decided, unchanged order).**
Rooftop mortars · mecha kaiju boss · jets (#58, #61) · species motion (#11) and the other species · six languages ·
music (Suno, needs his spend yes) · greenery (#55) · look-options -> main (#3) once the slice ships.
Sound (research): a pooled SFX manager with voice caps per category from data, hero voices reserved, quietest or
farthest stolen (R 8.2) · a rubble stream (2-3 loops whose level follows debris landings) instead of a voice per
chunk (R 8.4) · crowd panic bed from civilian counts in four quadrants (R 8.6) · footsteps longer and lower each
stage over a falling-debris layer, roar pitched down per stage (R 2.3) · distant booms low-passed, delay by distance
only if a clip proves it reads (R 8.5) · adaptive music as synchronized stems following the destruction rate (R 8.7,
stems need spend or licence work) · loudness about -24 LUFS, checked on his TV (R 8.9). Free sources: Sonniss GDC
bundle (never in a public repo) + Freesound CC0 only (R 7.3).
Assets (research): military and civilian vehicles from padadu pack 15 and Kytric Voxel Vehicles (CC0), street props
from padadu pack 05, all re-voxelised to our cell size (R 7.5, 7.6) · people made in-house (no cleared voxel crowd
pack exists) (R 7.7) · models as data: a palette plus named part grids meshed by one culled mesher, authored in
MagicaVoxel and converted offline (R 5.1, 5.2) · hard-surface props from an LLM-written grid generator run headless
in Blender, five views per run (R 4.1) · organic stages from TripoSG image-to-3D, voxelised and cleaned by hand
(R 4.3). Traps: maxparata packs (CC BY-ND), packs with no licence, GPL shaders, Freesound NC, Hunyuan3D, any SMPL or
AMASS motion model (R 7, 3.6).
City (research): one seeded density field per block drives height, lot size and tower chance, rising each stage
(R 6.2) · district labels by simple rules (downtown, residential, industrial, docks) (R 6.3) · docks and cranes where
the kaiju rises (R 6.4) · one headline landmark per stage placed by a data condition (R 6.5) · podium, shaft,
setback and crown silhouettes by district (R 6.6).
Species (research): a silhouette gate per stage (filled black at play zoom, told apart by shape) (R 2.6) · one
signature verb per species tied to carving, cephalopod first: GRAB and DRAG (R 2.7) · cephalopod arms reach as a
bend travelling base to tip, haul back as a stiff three-segment fetch, wrap towers tip first on a helix, suckers face
the target, idle sway from a hash not the sim RNG (R 9.2-9.7) · original species concepts for his pick: burrower
(UNDERMINE), hermit crab that wears a building as its shell (WEAR), reef colony (ENCRUST), fungus walker (ROOT),
pangolin roller (ROLL), tide ray (BREACH and SLAM) (research 02) · authored finale with a readability pass (R 1.5).
Rooftop mortars (research 24): a sibling of the rooftop squad, placed at sim start on tall topple-able non-landmark
towers (2-5 per tier), firing beyond rifle range with a dead zone, one timed shell per 4-6 s aimed where the kaiju is,
killed by losing its roof, with a sim review and pinned-seed suite (R 24.1) · "ride the fall": kill and pay at the
tower's landing, the +N where it hits (R 24.2) · telegraph from existing parts: beacon, a filling landing ring, thunk,
whistle, boom (CC0 only), 4K capture through the screen critic (R 24.3) · an edge chevron for 1 s only when an
off-screen mortar fires (R 24.4) · a tower dropped onto a mortar nest kills it, combo bounty (R 24.5) · tree hooks
(bounty, topple radius, falling debris kills, shell-shrug) for his pick (R 24.6). Not now: mid-run spawns, lead aim.
Mecha boss finale (research 23): one boss rampage in the player's own city after the last evolution, army stood
down, beating it ends the game (R 23.1, his question) · sim/mecha.gd + data/boss.json, a greybox body, three
attacks (charge, salvo, stamp) from a shuffle bag, phases with a minimum time, sim review (R 23.2) · telegraphs
always visual, slow wind-ups, no feints, motion critic (R 23.3) · the city as the weapon: undercut a tower onto it,
a charge that sticks in a building, thrown tanks after R 22's Flung (R 23.4) · two-target camera, a thin boss bar
as the one HUD exception (his yes) (R 23.5) · it falls like the biggest tower, quiet, then results and credits
(R 23.6) · voxel model, rig, 6-8 clips through the Blender pipeline, concept board first (R 23.7). Estimate 3-5 weeks.

**Director questions the research raised (ask each at its phase, the ask-the-director way).**
D: when contact carves vs yields, and whether a fast tail sweep carves (R 13.3) · D: slower walk speed vs faster leg
cadence, if the long stride cannot fit (R 11.2) · E: rampage timer start and ceiling (R 1.2) · H: which original
species follow the croc, and their verbs (research 02) · H: spend on music stems, and Tripo octopod rigs (R 3.5, 8.7) ·
D: which throw upgrade nodes (R 22.4) · B: how the camera grows per stage, A/B/C clips (R 19) · D: the lightning halo colour (hot amber, species-eye tint, or white with a violet fringe), 3 labelled 4K stills
(R 17.6) · E: the tree's map layout, radial vs a left-to-right map, from labelled captures (R 16.5) · F: do dash and the
ultimate get rings like breath; health removed or shown only when hit; what happens to the "CITY DESTROYED" bar
(R 15.2, 15.3, 15.9) ·
H: the finale's shape (one boss rampage that ends the game) and which original mecha concept (BULWARK the walking
district, CONVOY built from wrecked army hulls, FOUNDRY the builder, COUNTERMEASURE the adaptive counter), from a
labelled concept board (R 23.1, research 23) · legal look check: the research says to avoid the combination of upright reptile, dorsal plates and a glowing breath
beam (Toho enforces the Godzilla look; research 02 finding 9, not legal advice). Answered in part (director
2026-10-21): "we could have our croc shoot hot lightning instead of atomic theme", so the breath is re-themed (D,
b2-18). Shape closed (director 2026-10-21): "ours is like a crocodile in a t-rex body, not godzilla shaped".
