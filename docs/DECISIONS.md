# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. Only the merge role edits this file, from the "Board and log" section of merged PRs.

## 2026-10-21 · D-124 · Director · No octopus work until the croc is 100% shippable
Why: his words, "no octopus work until the croc is 100% shippable". D-123 is recorded design only; no cephalopod builds, captures
or assets start before the croc ships. The insectoid waits too. "Shippable" = a full croc playthrough: all 3 cities, the mecha
finale, music, menus and the Steam build, polished, with only the croc playable (asked 2026-10-21).

## 2026-10-21 · D-123 · Director · One of the 3 cities is a water city; the octopus swims fast and can submerge
Why: his words, "im planning the octopus to be in a city with lots of water so it can move quickly through it". Asked: the water
city is one of the 3 every species plays; in water the octopus is fast and the others move normally; it can also dive to
dodge the army and burst out under buildings. Water becomes gameplay for the cephalopod (amends D-122's 'no gameplay effect').

## 2026-10-21 · D-122 · Director · Water = the R 21 plan (presentation physics), built after fire gameplay
Why: asked whether "proper water with physics" (#12) means the planned ripples, wakes, splashes and floating rubble with no
gameplay effect, or gameplay water or a fluid sim: the plan. Order: fire gameplay (R 26), then water (R 21).

## 2026-10-21 · D-121 · Director · Camera growth: A (today's camera plus look-ahead); walk contact built now
Why: picked from the A/B/C stage-4 boards (kaiju 51% / 33% / 47% of screen height). Falling towers fade like standing ones.
The D-118 walk contact is built now, ahead of fire gameplay (his yes 2026-10-21).

## 2026-10-21 · D-117 · Director · Run timer stays 40 s at the start, 100 s at most
Why: Asked 2026-10-21 (R 1.2). No change to data.

## 2026-10-21 · D-118 · Director · Walking into buildings: small ones crumble; big ones take visible damage and tear easily with a little more effort
Why: His words 2026-10-21: "even big building should take visible damage, it should be easy for him to tear through them, it just requires slightly more effort / the game isnt meant to be extremely challenging or frustrating, its meant to be a thrill". Closes R 13.3.

## 2026-10-21 · D-119 · Director · Skins and body-part mutations are stretch goals
Why: Asked 2026-10-21 (customisation beyond species).

## 2026-10-21 · D-120 · Director · The background skyline rampage stays after the slice (section H)
Why: Asked 2026-10-21.

## 2026-10-21 · D-113 · Director · The game ends in a finale boss fight against a giant military mecha, after 3 cities
Why: Asked 2026-10-21 (open list: finale shape, how many cities). Changes: ROADMAP finale (R 23) builds a mecha boss; city count 3.

## 2026-10-21 · D-114 · Director · Music: Suno Pro (director's written yes to the spend; he subscribes and generates)
Why: Asked 2026-10-21 (Suno Pro vs ElevenLabs Music). Agents never enter keys; he generates, the lead cuts loops and registers licences.

## 2026-10-21 · D-115 · Director · Fire: wind fixed per run; non-breath species light fires through tree augments
Why: Asked 2026-10-21. His words: "fire augmentation possible in the upgrade tree, i.e. insectoid 'searing venom' cephalopod 'flammable oil spray'". Fire as gameplay (R 26) is the next build after the current batch.

## 2026-10-21 · D-116 · Director · Heartbeat sound: the director makes it in ElevenLabs
Why: Asked 2026-10-21; the lead gives the prompt and length, then wires and tunes it.

## 2026-10-21 · D-112 · Director · The croc's signature is "Lightning Breath", its ultimate "Thunder Beam"
Why: D-108 retired "Atomic Breath" for the forked white-hot lightning; asked during the UI redesign QC (species card
and tree still said Atomic Breath / Atomic Beam). Changes: species.json, the species card, HUD and tree copy.

## 2026-10-21 · D-109 · Lead · Medium (balanced + MSAA 2x) is the 4K default
Why: R 18.1 grew the graphics table to Potato/Low/Medium/High/Max; balanced ran FSR1 with no AA, which the Godot docs advise
against. Medium = balanced + MSAA 2x costs about +6.5% GPU and keeps D-093's 60 fps cap. Built in #129. Supersedes D-093's
"Balanced" default name only; the fan/power reason stands.

## 2026-10-21 · D-111 · Director · The look stays voxel (b2-20)
Why: asked from labelled boards and an 8 s side-by-side clip of today's voxels vs the same models meshed smooth (same seed and
tick; destruction stays cubes in both), he picked A, voxels. Changes: none to the game; claude/phase-b-boards stays a
capture-only branch. Phase B left: camera growth per stage (R 19).

## 2026-10-21 · D-110 · Director · Fallen slabs are destructible: anything the kaiju touches breaks
Why: playtest of build 4, "rubble blocks are probably too big, the kaiju is gonna clip through them; alternatively make the
rubble blocks destructible too" (comments #14, docs/roadmap/2026-10-21-rubble-slabs.webp). Asked smaller slabs vs
destructible vs both, he picked destructible. Changes: a landed slab stays big, but a stomp, swipe, dash or the body walking
into it breaks it into smaller chunks and gravel (sim decides, deterministic); the kaiju never clips through rubble.

## 2026-10-21 · D-107 · Director · Voxel size: the city stays at today's size, the kaiju gets double voxels (b2-19)
Why: asked from labelled stills of half / today / double (same seed and tick, game and close camera), he answered "b but
kaiju with double voxels". Double everywhere ran at 5.6 fps with a 13 s stall; at the game camera the city sizes looked nearly
alike. Changes: city, cars, people keep today's cell size; the kaiju model is voxelised at twice the resolution per axis
(finer silhouette and skin), every stage, measured for fps before it ships (claude/kaiju-double).

## 2026-10-21 · D-108 · Director · The croc's breath is hot lightning, not atomic; its shape is a croc in a t-rex body
Why: research 02 flagged the upright reptile + dorsal plates + glowing breath beam combination as the Godzilla look; he
answered "we could have our croc shoot hot lightning instead of atomic theme" and "ours is like a crocodile in a t-rex
body, not godzilla shaped" (comments 2026-10-21 #7). Changes: Phase D b2-18 breath VFX and copy pass re-themed to forked
white-hot lightning (research 17); the halo colour is still his question (R 17.6).

## 2026-10-20 · D-106 · Director · Every time of day, one per run
Asked which time of day the Cinematic look uses, he answered "all of them, except make morning less hazy and the night a bit lighter". Runs rotate dusk, night, morning, noon (run index from the save; the first run is dusk, the look as written).
Changes: data/looks.json "times" (overrides of look keys; morning fog 0.008 -> 0.003, night ambient 0.8 -> 1.4, sun 0.18 -> 0.35, lighter sky and fog), Content.set_time/time_for_run, Rampage.setup picks it.

## 2026-10-20 · D-105 · Director · Camera framing C: low and cinematic
He picked C from four labelled framings of one seeded run (stills + 2x2 clip): rest offset (0, 16, 30), FOV 60 (was (0, 27, 19), FOV 55).
Why: build2-7 "the camera doesnt let us see much of the city"; C sees to the skyline and keeps the kaiju big. Changes: data/tuning.json "camera"; the run intro (Phase D) ends on this angle.

## 2026-10-20 · D-104 · Director · Shader: Cinematic
He picked Cinematic from four candidates (today, toon, diorama, cinematic) at morning, noon, dusk and night: heavy ambient occlusion (ssao 3.0, power 2.0), contrast 1.3, saturation 0.9, bloom on fire (glow 1.0, threshold 0.9), no crease edges.
Why: his shader comparison (comments 2026-10-20 #7). Changes: data/looks.json concrete; city_view reads ssao, ssao_power, glow_threshold from the look. Time of day stays dusk (not asked).

## 2026-10-20 · D-103 · Lead · Carving build calls (WP4-WP7)
Why: small calls made while building, none changes the vision. (1) WP4 slab colour B 8a8780 is the director's pick (D-101).
(2) A fixture cell on grid layer 0 counts as grounded. (3) Glass towers get structural columns, spacing in
`tuning.json`. (4) WP6 `arc_shed_cells` stays 32. (5) WP5 ships after critic round 3; its remaining motion items (block
shear sawtooth, chunks behind panes on a swipe, tower slab propped on its teeth) are carried into WP7 integration
(no-marginal-gains), which narrows D-102's "fix now". (6) D-098's young rooftop sting 0.05 is executed with the Behemoth
sting scaled by the same factor so the size order holds.

## 2026-10-20 · D-102 · Lead · WP5 gets one more fix round before its PR
Why: the round-2 motion critic's three findings are defects, not taste (lead 2x on the clean CI clips): the fallen tower
slab lands whole and then vanishes, block towers shear in a regular staircase, debris floats visibly inside glass.
Carving is top priority (D-097), so they are fixed now on claude/carve-wp5 rather than carried into WP7.

## 2026-10-20 · D-101 · Director · Carved slab colour B (8a8780)
Why: picked from the WP4 slab stills. Changes: carved floor slabs and cut faces in the WP4 view mesher use 8a8780
(claude/carve-wp4 609ea71).

## 2026-10-20 · D-100 · Lead · Carving support rules for attached parts and glass towers
Why: the WP3 review found islands before any carve (panes, signs, tanks, glass curtain walls). Changes: materials carry a
`fixture` flag (window, mullion, glass, shop, sign_frame, neon0-3); a structural cell is grounded by 6-face contact, a
fixture by 26-neighbour touch, and a fixture never carries a structural cell; grid layer 0 is the ground (a shopfront on
the street stands). Glass towers get a hidden structural frame (columns every `destruction.column_bay` cells, a beam
behind the transom row), in sim and view alike. Built in #97 (WP1) and #98 (WP3).

## 2026-10-20 · D-099 · Director · Carved towers fall by real physics, even onto the kaiju
Why (asked through the question tool): true physics is the headline (D-097); a cut tower goes over toward the side that
was cut away, wherever the kaiju stands, and can land on it. Supersedes D-096's lead call "an undermined tower falls away
from the kaiju". Changes: carving WP1/WP5 keep the support rule's own direction; #89 drops its "every topple falls away"
override (croc-contact builder, 2026-10-20) before it merges.

## 2026-10-20 · D-098 · Director · Young croc retune = option A "steady upgrades"
Why: playtest note 8 (cadence 1 -> 8 -> 1 upgrades per death); he picked A of three via the question tool. Values:
level-1 costs about half of level 2 (claws 45, hide 45, stride 80, quake 100, rage 75, greed 125, frenzy 220, r_tail 200,
r_momentum 400), evolve1 400 -> 600, young rooftop rifle sting 0.01 -> 0.05. Bot: e1 0.24-0.27 h, young defeats ~8.5/15,
2-4 buys per death. Built on claude/young-retune (with #89, #90 and the army ramp from closed #85). Settled only when his
playtest passes.

## 2026-10-20 · D-097 · Director · True physics and carving are top priority, started now
Why: "true phyiscs should be top priority. carving included. its a game about destroying cities, the city destruction has
to be good"; earlier the same day he chose "start now, 2 builders". Supersedes D-094's "after demo exe 2". Changes: WP1
(sim grid, claude/carve-wp1), WP2 (native C++, claude/carve-wp2), WP3 (building cells, claude/carve-wp3) and WP5 (physics
presentation, claude/carve-wp5) are running in parallel with the demo fixes; carving PRs, CI and reviews go first.

## 2026-10-20 · D-096 · Director · Swipes undermine towers
Why (asked through the question tool): claw hits on a tower's base count as chewing it, so towers topple sooner with
Claws. Lead call: an undermined tower falls away from the kaiju, so the player sees the fall. Built in #89
(sim/claw_swipe.gd chews the building face; tuning is a seeded 5-seed mean, not a single seed).

## 2026-10-20 · D-095 · Director · Claws = a claw swipe, for the croc only in the demo
Why: with the contact body on (D-091) the body already breaks the low buildings and chews towers, so five levels of
Claws no longer helped the young croc ("Claws is useless"). The croc rakes a band ahead of it every 2 s; the other
two species keep Claws as +3 stomp. Built in #89.

## 2026-10-19 · D-094 · Director · Full-game destruction is option A: real carving (after demo exe 2)
Why: "i want real dynamic destruction, actual physics and buildings than can be carved by giant monsters"; picked A
from the spike (#91, docs/research/DESTRUCTION_SPIKE.md): Teardown-style fine sim voxels, island flood fill, RFG-style
support and topple, a C++ GDExtension, Jolt for cosmetic debris only. About 19 agent-days. Starts after demo exe 2
(D-083). Build plan: branch claude/destruction-plan (agent-handoffs/destruction-spike.md).

## 2026-10-19 · D-093 · Director · At 4K the default is Graphics Balanced at 60 fps
Why (the playtest's loud GPU fan; RTX 4070 SUPER, 4K 120 Hz): Balanced (0.75 FSR1, MSAA off) + 60 cap halves the power
(199 -> 110 W) and holds 60 fps as the Behemoth. High stays in Settings. #92 MERGED (41d452f); settings.cfg v2 so a
cap saved by demo exe 1 no longer overrides it.

## 2026-10-19 · D-092 · Director · SFX from ElevenLabs Starter; Suno music deferred
Why: Starter is $1 the first month, then $6/mo, with a commercial licence (the free plan has none). The director
subscribed himself and picked 12 sounds on a loudness-matched shootout (shell_hit kept). #87 MERGED. Suno: free
has no commercial rights; Pro $12/mo; not bought.

## 2026-10-19 · D-091 · Director · No building is too strong for the baby; big ones just take longer
Why: "the buildings shouldnt be too strong for our little kaiju, it should just take him longer ... hes more than
capable of tearing the roots out and toppling the large buildings". Replaces the tier gate and "TOO STRONG"; evolve1
text "Grow huge. Tear through towers faster." In #89 (croc contact).

## 2026-10-19 · D-090 · Director · Stadium rubble bonus 4x -> 1.5x
Why: the playtest's biomass cadence (1 upgrade, then ~8, then 1) came from the stadium's 4x. Replaces D-081. #79 MERGED.

## 2026-10-19 · D-089 · Director · Demo exe 1 waited for the stall fix
Why: the windowed stall (Structure.settle rescanning every floor) had to be fixed first; #75 MERGED, exe 44f56fd.

## 2026-10-19 · D-088 · Director · The demo exe ships without #50; the military AI follows in a second exe
Why (AskUserQuestion, "Ship now, patch after"): tanks and helicopters are already in the demo; #50 is their smarter
movement and failed its r3 critic. #50 r4 (tank overlap and skew, helis in frame, rotor clearance, young retune
on evolve1 400) runs now; a fresh critic, then a second exe.

## 2026-10-19 · D-084a · Lead · #55 trample: topple out, crush in place instead (rule 8)
Why: ten topple rounds failed; method change to crushing trees in place (debris, stump, footfall puff). Still after
the demo build per D-084.

## 2026-10-18 · D-087 · Director · The first evolution comes at about 15 minutes
Why (19:xx): "try to get the first evo earlier, no ones going to play 41 minutes of a demo if theyre still a baby";
picked "About 15 min" from 10 / 15 / 20-25. Lever: evolve1 cost 1778 -> 400 (#36, MERGED cceabba): 130 runs on the
real head give evolve1 0.26 h, young defeats 8/14, tree 82/87 at 3.37 h. The growth test ratio moved /10 -> /20.

## 2026-10-18 · D-086 · Lead · #36 option A (Behemoth army 0.03), void
Why: proposed for Behemoth defeats; superseded the same evening by D-087's pick and never applied.

## 2026-10-18 · D-085 · Director · Rooftop squads fire raggedly, never in unison
Why (via the rooftops session): "shooters arent firing in unison ... improvised, unrehearsed resistance". Seeded
ragged gaps per squad (51a2d5d); in #63.

## 2026-10-18 · D-084 · Lead · #55 trample gets one last round, else the demo ships without it
Why (18:0x, same rule as D-082): r9 failed the critic (topple hidden by the body, sprite dust, see-through crowns, dark
stumps, falls along the tail). One more round; if it fails, greenery's trample is not in the demo.

## 2026-10-18 · D-083 · Director · After the demo, playtest fixes come first
Why (16:0x): director's call for after the demo build (P7 playtest); no new feature work jumps ahead of its fixes.

## 2026-10-18 · D-082 · Director · #50 military AI gets one more round, else the demo ships without it
Why (16:0x): the fresh motion critic failed #50 (tanks skewed mid-street, helis firing nose-away). One last round,
and #50 ships only if it passes a fresh critic before #36 is tuned.

## 2026-10-18 · D-081 · Director · Landmark rubble_bonus stays 4x
Why (16:0x): asked whether to change it; kept as built in the landmark sites work.

## 2026-10-18 · D-080 · Director · The jet strike warning scales with the kaiju's size
Why (15:4x): director's call on the jets PRs; applied on the jet branches (#58, #61).

## 2026-10-18 · D-079 · Director · shell_hit keeps its full boom (A); #52 closed
Why: heard the A/B; kept A, the existing full boom. The alternative's PR #52 is closed unmerged.

## 2026-10-18 · D-078a · Director · The stadium stands are full of spectators watching the match
Why (18:0x): "the stadium needs to be full of people in the stands watching the sport, currently its empty".
Added to #59's brief; the AFL clip is re-rendered with the crowd.

## 2026-10-18 · D-078 · Director · Stadium matches: one random sport per run, players flee when the wall caves in
Why (14:1x): AFL, NFL, soccer or cricket, random per run; presentation only, low-effort visual flavour, in the demo.
Real cities make the sport deliberate later. Lands in #59 (landmarks session).

## 2026-10-18 · D-077 · Director · The tree's stats panel shows only what the selected node changes, in plain words
Why (10:5x): the 12-number summary (STOMPS/S, RECHARGE, ARMOUR 0.0, SIZE 1 -> 2) read as software. Now the cost and
the node's own stats ("Stomps hit harder: 13 -> 16"), lines from data/tuning.json "stat_text". MERGED #51 (997f516).

## 2026-10-18 · D-076a · Lead · Rooftop density: reach from the stomp edge, more squads, a tenth of the chip
Why: for D-076 at the same threat. Option A: chip per volley scaled down per tier so each stage's damage per run
holds within ±5%; tanks unchanged; no HUD change (the hide spark is the hit read). PR #63.

## 2026-10-18 · D-076 · Director · Rooftops: more squads, firing more often
Why (10:5x): "more squads, more often". Cause found: rifle reach was measured from the kaiju's centre. Plan in D-076a.

## 2026-10-18 · D-075 · Director · Green lots at 8% of the city
Why (10:5x): answers D-065(b), the green-lot share tabled with its chunk and pacing table. City session, after
greenery (a).

## 2026-10-18 · D-074b · Director · Stage 1 at speed 0.6 and hp 1.15 (~43 min demo)
Why (13:2x): ~0.6 h to evolve1 is unreachable at 0.6 speed (the sweep floors at ~0.66 h). Accepted ~0.71 h: about
45% of early runs end in defeat and 87% of the city is destroyed by evolve1. PR #54.

## 2026-10-18 · D-074a · Director · Baby speed ~0.6 with more hp; demo ~35 min
Why (11:4x): revises D-074 with a target; superseded by the measured numbers in D-074b.

## 2026-10-18 · D-074 · Director · Slow stage 1: the baby reads as a toddler
Why (10:5x): slow stage 1 so the baby reads as a toddler; pacing re-measured in the P3 PR (#54).

## 2026-10-18 · D-073 · Director · Croc baby and adolescent approved
Why (10:5x): the P3 bodies from the croc titan design (D-059) are approved for the demo; clips kept, slam polish
later. PR #54.

## 2026-10-18 · D-072 · Director · All four jets; strikes wreck buildings but give no biomass
Why (10:5x): jets arrive from Colossus; the bomber is the Apex set-piece; the octopus can grab jets. PRs #58, #61
(parked until after the demo).

## 2026-10-18 · D-071 · Director · Landmarks in order: A stadium, D wheel, E spire, F megatower
Why (10:5x): picked from the landmark board. A sites PR with A and D first, then E and F.

## 2026-10-18 · D-070 · Director · All tabled sounds ship, with a new mix
Why (10:5x): #43 #45 #39 #42 #46 #53 #60 #56 #51 #57 #62 merged, each resynced by the sound session; #52 decided by
D-079.

## 2026-10-18 · D-069a · Director · Soften #36's young stage to about half the early defeats
Why (11:2x): about half the early defeats; cause: Armoured Scales moved late in the tree. #36 lands last before the build.

## 2026-10-18 · D-069 · Director · The army scales inside each stage, so defeat stays possible after Behemoth
Why (10:5x): the pacing run showed 1 defeat in 92 runs after Behemoth. growth.per_level in tuning; regen and armour
priced late. Merge #36 after #50 and P3.

## 2026-10-18 · D-068 · Director · Crease shader B (0.3) on
Why: picked B from the A off / B 0.3 / C 0.6 board; the per-voxel edge bevel is dropped (invisible at the game
camera). MERGED #35.

## 2026-10-18 · D-067 · Director · Army sounds shipped as heard
Why: "Tank fire, shell hit and helicopter rotor shipped as heard". MERGED #34.

## 2026-10-18 · D-066 · Director · Tanks and helicopters move and fight like a professional military
Why: road-bound tank columns with firing posts and fallbacks, helicopter pairs with attack runs; total damage per run
held within ±5%; helicopters a real threat to dodge ("overall difficulty unchanged"). PR #50; heli mix shift OK.

## 2026-10-18 · D-065 · Director · A believable amount of greenery throughout the city
Why (06:2x): "make sure there are a believable amount of trees, bushes, floral areas, parks, gardens, playgrounds
throughout the city". (a) street trees, gardens, playgrounds, hedges, all crushable: PR #55; (b) green lots: D-075.

## 2026-10-18 · D-064 · Director · Menu sounds and the SFX volume slider shipped as heard
Why: "Menu click/confirm/deny sounds and the SFX volume slider shipped as heard". MERGED #33.

## 2026-10-18 · D-063 · Director · Rooftop defenders shoot at the kaiju
Why (05:50): "put soldiers/gun bearing citizens defending their homes on rooftops shooting at the kaiju". Their shots
do chip damage, no new escalation curve (army unit "rooftop"). MERGED #40.

## 2026-10-18 · D-062 · Director · No vast empty spaces: every cell the camera shows holds something
Why (05:27): "there should never be vast empty spaces with nothing to smash or kill". Inside the arena something to
smash; past the edge, dressing, never bare asphalt; checked in the city suite. MERGED #37.

## 2026-10-18 · D-061 · Director · UI look A "Emergency Broadcast" for every screen
Why: picked from three mockups (A broadcast, B concrete and rubble, C monster hide) for a "thematically rich, beautiful
and intuitive" UI (UI session, 2026-10-18). Changes: UiKit palette (hazard yellow, alert red, near-black), hazard tape,
square edges, news crawl; one look for every screen. Lands in PR #27.

## 2026-10-18 · D-060 · Director · Mantis and octopus: keep all six meshes, plan only for now
Why (04:27, species session): keep mantis 9668b815 / 0161ad14 / 06ed8a12 and octopus 8bf2f668 / a328effe / 6176590f and
give them the croc's Blender hand rig with welded weights, no redesign, octopus first (D-045: the auto rig, not the mesh,
broke the octopus). 04:50: "I only wanted the plan, not execution": work halted after the plan
(docs/superpowers/plans/2026-10-18-mantis-octopus-game-ready.md); nothing merged. Outside the demo (D-050).

## 2026-10-18 · D-059 · Director · Croc baby and adolescent from the croc titan design; 260 Tripo credits
Why: the demo needs the hatchling and Behemoth stages in the croc look (D-050). The director approved the stage line
(docs/captures/2026-10-17-reptile-design/croctitan_stage_line.png, after a realism-critic pass) and the spend: two Smart
Mesh (100 each) and two textures (30 each), balance 19415 -> 19155. Six-view PASS sheets: croctitan_{baby,adolescent}_
six_view.png; GLBs to blender-reptile for the hand rig, weights, clips and export (P3). Rows in docs/provenance/tripo.md.

## 2026-10-18 · D-058 · Director · Body text uses Kaiju Block; headings stay Kaiju Claw
Why (05:13): "still seeing generic fonts in game when we should be using our own": the UI kit drew every label below
heading size in the engine default. Board A rubble / B fault / C claw / D block at 20 and 24 px; D picked (cleanest at
20 px, ours, same tool). All faces are capitals only: accepted. Lands in PR #27 with a no-default-font check.

## 2026-10-18 · D-057 · Director · Lighting stays the current "concrete" look
Why (05:12): board A current / B golden hour / C blue hour / D night at the game camera (1080p + 4K, luminance p50
72/78/52/27); the director kept A. The lighting branch (claude/lighting) is parked, not merged: a system that does not
change what the player sees is cut.

## 2026-10-18 · D-056 · Director · The kaiju earns and spends BIOMASS, not rubble
Why (05:08): "I don't like the concept of rubble as currency." Options: biomass (you devour what you flatten; evolving
is growing), terror, radiation, rename only. Picked biomass. Changes: player-facing words only (title Continue line,
pause, results "Biomass devoured", tree, HUD, upgrade desc, VISION.md); internal keys and the save field stay. In #27.

## 2026-10-18 · D-055 · Director · The croc roar plays on the evolution reveal and the demo end card
Why (04:35): heard roar_reveal.mp4; "ship it". Not layered under Atomic Breath, no new power. PR #8.

## 2026-10-18 · D-054 · Director · Zebra crossings only at the central avenue junction
Why (04:35): "remove the level crossing hellscape": zebras were painted at every avenue arm and mid-block. Now only the
avenue x avenue junction nearest the centre keeps them (city.zebra_junctions = 1; 0 = none); dashes and kerbs kept. PR #26.

## 2026-10-18 · D-053 · Director · Worktrees: one live worktree per live session
Why (04:30): the demo team runs six to eight sessions at once and the cap of four blocked work. The lead prunes dead
worktrees; tools/lint/worktrees.sh caps the total at 8. PR #25.

## 2026-10-18 · D-052 · Director · Demo SFX shipped as heard
Why (04:30): listened to three game-camera clips (stomps + footsteps, building collapse, Atomic Breath) with cracks
capped at one per 2.5 s and a footstep minimum interval; "ship as is". The 0.7 s auto-stomp rhythm is the sim's (D-004).

## 2026-10-18 · D-051 · Director · The evolution reveal is titled by the node bought
Why (04:20): after buying EVOLVE: Behemoth the reveal said "REPTILIAN ADOLESCENT"; now it says BEHEMOTH (the node's data
name), for every evolve node. Life-stage names stay internal. PR #23.

## 2026-10-18 · D-050 · Director · Minimal playable demo: croc line only, ends at Behemoth
Why: the director asked for a minimal playable demo (plan approved 03:35, five questions answered). Decisions: (1) the
croc titan (reptilian) is the only playable species; (2) the demo ends after the first evolution (Behemoth, about
20-30 min) on a "demo complete" card; (3) the croc baby and adolescent get new models from the croc titan design
before the demo ships; (4) SFX are unpaused for the demo (PR #8); (5) the croc titan adult appears only on the end
card, roaring, since the player never reaches tier 3. Phases: P1 balance D data, P2 D-047 adult clips, P3 baby and
adolescent models, P4 SFX, P5 demo slice (data `demo` section, species allow-list, end card), P6 Windows export from
look-options, P7 director playtest. Out: insectoid and cephalopod, evolve2+, the Apex city, #11 locomotion.

## 2026-10-18 · D-049 · Director · City-growth balance: apply proposal D
Why: with one cost curve the runs were cephalopod 2.94 h, reptilian 3.94 h, insectoid 1.93 h (insectoid well under the
3-5 h target, driven by the Leap Slam). Changes (measured in #16's tools/pacing.gd): all costs x1.27; Leap Slam cooldown
4.5 -> 6.5 s, damage 22 -> 18; reptilian breath range 9 -> 11, damage 30 -> 36, cone 30 -> 36 deg, speed 5 -> 5.5; Atomic
Beam cost x0.6, Brood cost x1.8. Expected runs 3.70 / 4.43 / 3.26 h; the insectoid stays the fastest clearer.

## 2026-10-17 · D-048 · Director · Croc titan v2: short reptilian arms (B) and charcoal spines (B)
Why: director: the arms are "always doing something odd... maybe his arms are just too long" and "too human looking
in the musculature" (measured 51% of height, 76% of the leg); "i dont like how light the colour of his spines are".
Boards: croctitan_arms_board.png (NOW / A / B / C, picked B) and croctitan_spine_colour_board.png (olive / charcoal /
bronze, picked charcoal). Changes: new Tripo Smart Mesh c8185166 (6623 quads, arms clear, long low tail), charcoal
re-texture, six-view PASS (croctitan_v2_six_view.png); the Blender hand rig is re-fitted to it before D-047 ships.

## 2026-10-17 · D-047 · Director · Play the Blender-made croc titan clips in the game
Why: in game, the Blender weights (#19) fixed the hip shear and tail-root seams, but the game's procedural walk and
roar still read as a 5 m lizard (fresh critic: rear-up, no settle, the jaw drops vertical). The Blender clips
(blender-reptile r7, d924b29) passed three fresh motion critics: crouch, throw, a slow drift at the peak, tail
counterbalance. Options: play the Blender clips (picked), or keep procedural and tune by hand. Changes: the croc
titan's roar, turn and idle play from exported Blender clips; the walk is the Blender cycle layered over the
procedural foot planting (root motion and terrain stay procedural). Other species follow once their models are decided.

## 2026-10-17 · D-046 · Director · New reptile look: A "Croc titan"
Why: board docs/captures/2026-10-17-reptile-design/reptile_directions.png (Tripo GPT Image 2.5, free quota):
A croc titan, B armoured monitor titan, C lean apex predator. Picked A: croc snout and pale flat bone scutes
carried over from the Blender model, bulk with grace. Changes: A goes to T-pose and multi-view references, then
Tripo Smart Mesh, texture and the Blender hand rig (D-045); the baby and adolescent follow from it.

## 2026-10-17 · D-045 · Director · Reptile body: a NEW original Tripo design, rigged in Blender
Why: Blender motion test (blender-reptile 4ab6781, clips in notes blender-reptile/motion-test/): one hand-made
skeleton with welded falloff weights moved BOTH the Blender model and the Tripo model cleanly (critic: deformation
and feet PASS), so poor in-game motion comes from our auto rig, not the mesh. The director prefers Tripo's detail but
A's originality ("less a blatant Godzilla copy"). Options: new Tripo design (picked), Blender A, current Tripo B.
Changes: new Tripo reptile steered away from Godzilla (croc snout, pale back plates, long low tail), then rigged in
Blender with the hand rig; Blender weights feed the game in place of rig_voxel's guessed bone ownership.
