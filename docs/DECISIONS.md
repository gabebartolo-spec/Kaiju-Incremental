# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. Only the merge role edits this file, from the "Board and log" section of merged PRs.

## 2026-10-22 · D-145 · Director · Demo is all three cities, ~90+ min; more Taskforce rules; roars, names, time of day

Asked 2026-10-22 ("ask me 20 questions"). Demo: includes the adult city (DESIGN's "hatchling to Behemoth" demo line is superseded); a first playthrough runs 90+ minutes; the end shows a thanks screen with rampage stats and a feedback link; the pause menu has a bug/feedback button that writes a report file with version and screenshot (no network calls); demo saves do not carry over to the full game. Taskforce: gas locks special powers only, the dash and every physical attack still work, and the cloud does no damage; mech bombs hit the kaiju and the city; the railgun line tracks the kaiju then locks shortly before firing, so a late step dodges it; several frost grenades refresh the slow, never stack; the dash shatters the ice early; gunships strafe with a blue laser cannon; squads arrive faster as more of the city falls; a destroyed mech blows up and damages nearby buildings; every railgun hit fires the post-effect colour fringe. Post effects: the red low-health pulse starts below 25% health. Title: one fixed view (not the player's current city); keep the BREAKING ticker. Layout: "move our main menu buttons achored to left of screen, keep the most visually apealling scene elements to the right of screen"; the logo sits above the buttons as one left column. Helicopter crews sometimes bail out by parachute. Load screens: a thin hazard-stripe progress bar. The signature beam is called "Thunder Beam for now but thinking of a better name". No roar button, but the kaiju "should roar more often, perhaps when he uses his ultimate power and/or a dash". Time of day: "the time of day will be randomised each run (a toggle available in the options menu to set a fixed time if players prefer)": random per run replaces D-106's rotation, with an options toggle for a fixed time; "random but cannot do the same time of day twice in a row".

## 2026-10-22 · D-144 · Director · Tanks caught by the longer breath just die

The longer baby breath trapped a retreating tank behind a parked one inside the danger radius; the lead had briefed a convoy re-plan, then a reverse-yield. Director: "think smarter, not harder, the tank doesnt need to avoid the breath, just let it die, even the most professional soldier wouldnt know to anticipate the breath in that moment". No convoy change; the military check counts only tanks that choose to park or fire inside the radius.

## 2026-10-22 · D-143 · Director · Taskforce: railgun strength, arrival, new adult-city enemies, obsidian and electric blue

Adds to D-137/D-139. A railgun hit costs about 8% of the kaiju's health. First arrival: a ticker headline ("ANTI KAIJU TASKFORCE DEPLOYED") as the first squad's glowing jetpack trails streak in. No on-screen markers for agents. Aesthetic for all Taskforce troops and vehicles: "Obsidian with Electric Blue highlights". Every Taskforce agent can jump building to building with grappling hooks and jetpacks. Adult city adds new types: gas-grenade soldiers whose blue-black cloud locks special powers (e.g. the thunder beam) while the kaiju stands in it; knee-high walking mechs in the street, 3-4 at a time, firing laser-bomb volleys marked by electric-blue target rings about 1.5 s before impact, destroyed by stomp, claw swipe, a toppled building or the thunder beam; Taskforce gunships (obsidian, blue lights). The regular tanks and helicopters keep coming alongside the Taskforce. All of it ships before the Itch demo (asked: agents first and the rest after; he picked "All before the demo").

## 2026-10-22 · D-142 · Director · Post effects: subtle vignette and impact colour fringe now, screen reflections later

Asked what post-processing is and whether more would help; picked: a subtle vignette (darker edges, pulsing red at low health) and a split-second colour fringe on the biggest hits only, both shown to him in one short clip before shipping; screen-space reflections on the max preset only, after the demo. Not wanted: motion blur, film grain, lens dirt (lead advised against).

## 2026-10-22 · D-141 · Director · Title fire, water shiver, no music; more Taskforce, wreck and art-process rulings

Title: keep the water reflections ("i love the reflection on the water"); the fire "looks like candles", so ragged flames pour out of windows on several floors with heavy smoke lit from below; the water shivers on every kaiju footfall ("Would be awesome if the water rippled whenever the audio of the Kaiju's footfall plays"), reflections breaking into wobbling bands that settle over about 1 s; no music, city sounds only. Taskforce: an agent killed in a collapse falls flailing with the debris, jetpack sputtering, with a short scream; a swatted agent spins into a nearby wall with a small impact. Helicopter wrecks start a building fire that can spread. Load-screen art: a board of about 20 staged shots, he picks 12. Textures: a board of one building in three voxel-detail styles first, then the city-wide rollout.

## 2026-10-22 · D-140 · Director · Demo build rulings: helicopter deaths, graphics preview, load screens, textures, title variants

Asked 2026-10-22 ("ask me a lot of questions"). Helicopter deaths (#86): a breath or direct hit blows the helicopter apart in the air, a glancing hit or a crumbling building sends it spinning down; wrecks never hurt the kaiju, only the city, and pay out as destruction. Graphics preview (#90): a small live burning street corner (fire, smoke, a looping explosion) redrawn at the chosen setting with the frame rate shown. Load-screen art (#92): the kaiju appears in most shots; no tip text, art and header only. Textured surfaces (#80): building walls and roofs first. Title background: recompose to his reference photo's view (near shore, water, skyline on a lit far bank: "it looks like the city is half underwater"); build night and a glare-free dusk ("dusk could be fine if you doctor the image a bit, remove the glare") and he picks.

## 2026-10-22 · D-139 · Director · Anti Kaiju Taskforce details; it is the next build

Adds to D-137. Agents die when the building they cling to collapses, and a claw swipe can swat one out of the air while it jetpacks. Look: black tactical armour with glowing blue railgun coils and jetpack exhausts. Arrival: agents jetpack in from the map edge. Squads of 3-4, up to about 12 alive. Frost grenades are launched at street level at the feet, and ice crusts up the legs until it cracks off ("we cant have them hit his head but freeze the legs"). Railgun: a thin aiming line plus a rising charge whine, about 2 s before the hit. Each agent killed pays bonus cash. Order: the Taskforce starts first when builders free up, ahead of textures, helicopter deaths and the graphics preview.

## 2026-10-22 · D-138 · Director · Original sounds may be made on ElevenLabs

"builder should create original sounds on 11labs if necessary" (comment #91, about the title screen's screams, sirens and gunfire). When no CLEARED sound exists, original sound effects may be generated on his ElevenLabs plan (commercial use per the plan's terms; check and name the licence in docs/LICENSING_REGISTER.md for every file). Spend stays within the plan's existing credits; anything that needs new credits or a plan change is asked first.

## 2026-10-22 · D-137 · Director · The Anti Kaiju Taskforce, before the demo

"Roadmap: your adversaries": the Anti Kaiju Taskforce with "special anti-kaiju weaponry including: lazer railguns, frost grenades", reference Attack on Titan, "Special Agents fly around the city with jetpacks and grappling hooks" (comment #78). Asked: arrives from the adolescent city as the elite threat above police and tanks; agents grapple onto buildings only; frost grenades slow the kaiju a few seconds, railguns charge visibly then hit hard; built before the Itch demo (adds to D-132's 'fully featured').

## 2026-10-22 · D-136 · Director · Drift audit: agent-added content ruled

A read-only audit found content agents added without a decision (comment #77). Kept: police blockades, the regeneration node, the UI scale setting, elevated expressways, the far-shore skyline as it is, aircraft lights, neon signs; far burn-outs pay a quarter of a burn-out. Cut: the camera's sideways lift during the breath. Prestige abandoned ("it isnt relevant to our game"). Graphics quality never drops on its own ("We have to optimise our game well, and graphics settings potato-max allow flexibility"). News headlines: keep 8, cut "AIR FORCE GROUNDS ALL HELICOPTERS"; the results screen is reviewed when he next plays; the mecha's three attacks are a proposal only.

## 2026-10-22 · D-135 · Director · Three growth steps, one per croc body: the Apex Titan step is cut

Asked (comment #72): the game had four growth steps (young, Behemoth, Colossus, Apex Titan) but three bodies (D-014); an agent added the fourth at kickoff (8d02a024), never a director decision. Picked "3 steps, 1 per body": baby city, adolescent city (EVOLVE: Behemoth), adult city (EVOLVE: Colossus). Each evolve gives a new body. Changes: evolve3 and the fourth city/army/air row go; the top-tier skills and the jet bomber set-piece move into the adult city. Outside the demo (D-050), so no demo delay. Follow-up (comment #100): "with the removal of the fourth city, we need to now grow the 3 cities to compensate, a slightly bigger play area in each stage"; asked: about 15% wider each (young ~96 m, adolescent ~160 m, adult ~290 m across), performance checked in the adult city.

## 2026-10-22 · D-134 · Director · Tripo: a budget of 9000 credits for today

"Tripo is logged in, you have a budget of 9000 credits to use today" (2026-10-22). Covers today's Tripo work (the D-127 HUD icons, up to 3000, count inside it; landmark models once he picks them). Every model is set Private and logged in docs/provenance/tripo.md; stop at the budget.

## 2026-10-22 · D-133 · Director · Landmarks: a stable of about 12 that rotate, 3 per stage

"I would like many more landmarks" (comment #62). Asked: "3 per stage but I want a stable of around 12 landmarks which rotate randomly with each run"; kinds: famous-style icons (original buildings that evoke real ones, never copies), city services, fun one-offs and industrial. Changes D-071's fixed four (stadium, wheel, spire, megatower) into a pool of about 12, from which each run picks 3 per stage by its seed. Picked (asked, 2026-10-22): suspension bridge tower, opera-house shells, theme-park coaster, giant donut sign, power station, airport control tower ("it would be cool to have actual planes flying around and using it"), container port cranes, oil refinery. Built as Tripo models that "still need to be carvable" (voxelized into cell grids like any building).

## 2026-10-22 · D-132 · Director · The 1.0 demo goes on Itch, invite-only, when the reptilian stage is complete

"I would like the 1.0 demo build to be on Itch for testers" (comment #61). Asked: invite-only testers (a restricted page with download keys); the 1.0 demo is the build "when the Reptilian stage is 100% implemented: bug free, polished visuals, good performance, fully featured". Earlier builds stay local.

## 2026-10-22 · D-131 · Director · The baby croc turns smoothly; the adolescent and adult step real turns

Small turns smooth (D-130) did not bring the stage-1 and stage-2 rise point under the 10 s bar (11.7-12 s): the baby makes many real turns at close range, and each stepped turn delays it. Asked who steps their turns, he chose "Baby turns smoothly": the baby turns smoothly at its pre-stepped rates (90 degrees in about 0.6 s), so it feels nimble while small; the adolescent and adult step every real turn (small corrections smooth, D-130), so the weight arrives as it grows. The 10 s bar stays.

## 2026-10-22 · D-130 · Director · Small course corrections turn smoothly; real turns step

After "turn 5% faster" (comment #49) made the stage-1 rise point worse (faster yaw swings the baby about its planted foot and overshoots): corrections under about 20 degrees turn smoothly while walking, with no slice or pivot; real turns still step foot by foot, so the adult never swivels on the spot ("Small turns smooth"). The turn rates stay as they were; the 10 s rise-point bar stays.

## 2026-10-22 · D-129 · Director · Fire: breath, beam and army shells light it; a burnt-out building collapses

Asked for fire gameplay (R 26, after D-126): with City Ablaze owned, the first fire is lit by the croc's lightning breath, its ultimate beam and the clumsy army's stray shells ("Breath, beam and army shells"; croc only until other species ship, D-124). A building that burns out collapses like a smashed one, floors giving way and toppling ("Collapses"). Node placement and costs start as placeholders flagged for tuning; Firestorm is stubbed until explosive sites merge.

## 2026-10-22 · D-128 · Director · Tripo Text to Motion: soldiers and crowd only, one 20-credit clip

Asked after the Text to Motion research (side-session-notes tripo-motion/report.md: humanoid rig only, no tail chain, so a croc would read as "a man in a croc suit"): he picked "Soldiers and crowd". One 20-credit text clip for a soldier or civilian action the ~101 free biped presets lack, inside the D-127 budget, Private, a docs/provenance/tripo.md row; the croc keeps its Blender clips (D-047).

## 2026-10-22 · D-127 · Director · HUD skill icons: Tripo-made kaiju moves, up to 3000 credits

After the minimal HUD (comments #45-47: "ui looks sooo much better, but id say make the skill icons bottom left like 15% bigger. we can generate nice icons with tripo please"): the rings grow to 80 px; the icons show the move itself ("Kaiju moves": breath = croc jaws with lightning, dash = clawed foot mid-charge, ultimate likewise); render style "try both and show me" (voxelized in the game look vs smooth 3D render); spend "as many as you need, up to 3000" Tripo credits on the paid plan, every task Private, rows in docs/provenance/tripo.md.

## 2026-10-21 · D-126 · Director · Fire gameplay: a tree unlock, 60% payout, five headline-named nodes

Asked before fire gameplay (R 26): spreading is unlocked by a tree node ("Tree node"); a building that burns down pays about 60% of a smashed one ("A bit less, ~60%"), so smashing stays the best payout; the five-node line fits, "but less AI slop names, more kaiju themed", then he picked the "Disaster headlines" set: City Ablaze (unlocks spread) / Five-Alarm (faster spread) / Fire Front (downwind, wind fixed per run, D-115) / Ember Rain (jumps streets) / Firestorm (explosive sites set off big fires).

## 2026-10-21 · D-125 · Director · Music builds up in layers

Asked how music reacts during a rampage (options: layers, switch tracks, one track per run), he picked "Layers build up": one track per city, split into stems (drums, bass, lead...) that fade in as the destruction ramps up, on one locked tempo (the Metal: Hellsinger model, research 011). Godot: AudioStreamSynchronized layers. Suno Pro stem split costs plan credits, no extra spend (D-114).

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
