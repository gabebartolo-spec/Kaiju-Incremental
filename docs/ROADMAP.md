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

**A. Close what is in flight; fix what no later choice changes.**
WP7 carving physics (D-099, claude/carve-wp7 e50b0be, resynced, tests then PR) · board PR (D-100..D-103, this
chapter) · repo CLAUDE.md + kaiju-handoff skill to the 300k/500k context rule · b2-6 every building in the play area
destroyable, any that cannot be is removed from it · b2-21 stadium placed as far from the spawn as the map allows ·
b2-26 atomic breath hurts trees · a destroyed building stays rubble, never a burning shell (comments #14, #111) · the kaiju rises out of the river water, never the asphalt (comments 2026-10-20 #10) · b2-2 first half: find out why the tail swipe does not fire, fix that bug only ·
p1-9 confirm in play that the south-of-spawn buildings are gone (#88) · sim check "armoured scales cut the damage"
(fails locally on look-options) · worktree and branch cleanup. Gate: build 3.

**B. Look foundations: director decisions, captures only, no production code.**
These change scale, density and framing for everything after, so they come first. b2-20 voxel vs a non-voxel look
(labelled captures of the same street) · b2-19 voxel count down / today / up, same shot · b2-7 camera angle and
distance (2-3 framings as clips) · shaders: a few candidate looks (lighting/post/material shaders), side by side at
morning, noon, dusk and night, he picks one (director 2026-10-20) · heli-cam A/B (parked; folded into the camera choice). Gate: his four picks
recorded in DECISIONS.

**C. Destruction core, on the picked look.**
b2-4 effortless carving even for a baby kaiju: no building HP, a structure dismantled by physics · b2-5 varied
collapse directions (not always onto the kaiju; revisits D-099's "onto the kaiju" lean) · b2-22 shared walls get
real facades · rubble cap (823 pieces from one building) · WP6 follow-ups (landmarks promote to cells; stadium first
hit 246 ms hitch) · b2-8 stadium crowd thins over time, never vanishes · stadium spectators on a broken stand fall or die, never hang with their feet in the air (comments #17) · b2-3 slow frames in heavy destruction
(profiled in the carving path, fixed there) · b2-30 run start freezes 2-3 s · b2-29 quitting freezes 2-3 s.
Gate: build 4.

**D. Kaiju body and combat feel.**
Turning with weight: lumbering and unstoppable yet responsive, the head turns toward the new heading before the body follows, no sliding pivot (comments #16, 2026-10-20) · b2-1 claw and arm animation reads as a swipe, no twitching · b2-2 tail as an autonomous extra limb · b2-9 tanks
shoved and flung into buildings, people and vehicles (uses C's physics) · b2-18 atomic breath VFX pass · run intro: a <=3 s shot, close on the water that ripples and fountains, the kaiju bursts out roaring, the camera pulls out to the play angle (#11) · water that reacts to the kaiju with physics (#12) · #104
follow-ups (ring under the foot renders; leap slam clip) · river splash colour (lost in the #88 resync) · rooftop
hits on legs and tail (#86). Gate: clips through the motion critic, then build 5.

**E. Progression: the upgrade tree.**
b2-28 two to three times the nodes · b2-2 tail node · b2-27 drop "reptilian branch" · copy pass b2-15, b2-16,
b2-17, b2-24 and every other node text · then ONE balance pass on the new tree: p1-8 upgrade cadence and the young
retune (#107 draft is superseded by it; its findings are inputs). Balance is his playtest. Gate: build 6.

**F. UI redesign, on the final camera and tree.**
b2-10 HUD: timer stays, biomass a boxless figure bottom right, controls shown once at the start and in a controls
menu · b2-12 breath cooldown as an icon with a circular fill · b2-13 health bar removed or repurposed · b2-11
species select: the kaiju centred, spinning in frame · b2-23 tooltips one fixed width (the ultimate no longer
reshapes the screen) · b2-14 bespoke original UI assets (boxes, cards) for every screen. Gate: screen critic, build 7.

**G. Performance audit, after the visuals are final (his order).**
b2-25 fans and GPU load: a measured audit at 4K, frame cap and per-system cost · CI shard timings
(claude/ci-shards). Gate: build 8.

**H. Content after the slice (already decided, unchanged order).**
Rooftop mortars · mecha kaiju boss · jets (#58, #61) · species motion (#11) and the other species · six languages ·
music (Suno, needs his spend yes) · greenery (#55) · look-options -> main (#3) once the slice ships.
