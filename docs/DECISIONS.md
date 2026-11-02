# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. The lead owns the wording; a decision goes in the PR that acts on it (any PR may carry it).

## 2026-11-02 · D-443 · Director · The baby rises on the wading shelf, in today's spot
Q: flow@5 failed because the baby's head broke the water at frame 92, after the wade began: its unkeyed rise ended
on the hollow's 7 m deep floor, which is fitted for the adult's keyed crouch. Rise on the shelf, or a shallower
hollow at stage 1? A: "Shallower hollow". So below `harbour.shelf_below` (2) the hollow's floor is the wading
shelf (`wade_depth`, 2.5 m) and the rise spot is unchanged. The whole body is in open water and the head breaks
the water during the rise (frame 43). Stages 2 and 3 keep the deep hollow (EmergeReach.fit).

## 2026-11-02 · D-442 · Director · Tonight: the RAM floor drops to 4 GB for the slow-suite fixes
Q: the runner waited on D-317's 6 GB floor (5.5 GB free: his browser and games open); close them, or lower the
floor tonight? A: "Lower floor tonight". So tonight's local suite runs use `MIN_FREE_MB=4096`; the tool default
stays 6144 (D-317) and nothing in the repo changes. Tomorrow the 6 GB floor is back.

## 2026-11-02 · D-441 · Director · Title: today's croc side-on behind the city, its fires on visible towers
His words, on the title still: "this fire is wrong btw / and we should update the kaiju silhouette to match our
current adult croc design / improve it too". Q: which view of the croc? A: "C: side-on". Q: the left district's roof
fires float in the haze; which fix? A: "Thin the haze". Changes: Fire no longer scales its flame quad by the zoom the
particles already carry (title flames were zoom² tall; fx_pool `_zoomed_flames`); assets/title/colossus_0.png
re-baked from today's croc (bake_colossus `--yaws=45,60,90,135 --pick=1`), `title.colossus` eye and crown moved to
it; the title's far shore leaves the engine's depth fog (`title.far_fog`, ui `ui_title_haze.gd`), play area unchanged.

## 2026-11-02 · D-440 · Director · The title's foreground is a night beach, not a paved quay
His words, on the title still: "this is wrong btw... meant to be a beach". Q: how? A: "Sand in front, same view". Why:
the game is set on a beach and bay; the paved ledge read as a harbour wall. Changes: title_shore.gd draws the old ledge
as the game's own sand (grains, wet line) sloping into the bay, its waterline wandering (tuning `title.shore.beach_*`),
a broken foam line, the fires' orange on the wet sand, and the bay lapping up it with the game's lap (`water.lap`).
Camera and far shore unchanged; title_ledge.gdshader is replaced by title_sand.gdshader. UI suite `ui_title_beach.gd`.

## 2026-11-02 · D-439 · Director · A flung tank carves a building, wedges in a big one, caves a roof in
His words: "when a tank hits a building it needs to carve it, it would be really cool if a tank could even wedge into
and get stuck in the bigger buildings or if they land ontop of a building they could crush it". Picked "Tank-sized
hole", "Too big to punch through", "Punch through floors", "Own PR after threat". Why: a thrown tank should leave a
mark the player remembers, not bounce off. Changes: TankHold (army.flight.hold): a tank flying into a wall bores a
hull-sized tunnel, deeper the faster it flew; out a thin building's far side it flies on at bore_keep of its speed,
else it sticks wedged and stays as a husk while the floors over it stand; one coming down on a roof caves in floors
by its fall speed and ends inside; a husk falls when its floor breaks. Tank flight suite on/off fixtures: tank.bore
(slow vs fast), tank.wedge (thin vs thick), tank.roof (street vs low vs high drop), tank.husk (standing vs broken).

## 2026-11-02 · D-438 · Director · Octopus and insectoid code removed
His words: "remove octopus code if its bloating the game and confusing you", then "definitely remove the octopus
code", then "remove the insectoid too, the only trace of him should be in the city across the bay". Changes: every
cephalopod path is deleted (tentacles, Hydra Limbs, Grab and Throw, Squeeze, Corrosive Ink, radial gait, grip,
stand-in, its assets, upgrades, tuning, strings and tests). The insectoid is no longer playable (Glide, Climb, Brood,
its upgrades, tuning, strings and tests are gone); data/species.json keeps its entry with `playable: false` so the far
beast in the skyline (skyline_rampage, far_beast, hexapod gait and rig, insectoid_* assets) still draws it.
Content.species() and Demo.allows() list only playable species. The reptilian plays exactly as before. Both species
stay stretch goals in DESIGN; git history keeps the code.

## 2026-11-01 · D-437 · Director · The threat level belongs to the city: it sets where the army starts
His words: "'alertness' level is now tied to the city/stage themselves, rather than in-run progression". Picked "By
stage": the young city (Ostia Minor) 1, Behemoth (Carthago, Thule) 3, Colossus 4 (Aurelia 5 later); "Show the city's
level" on the badge; and "Starting point": the level sets where the army starts, destruction still ramps it inside
the run. Why: each conquest should feel like a harder city, not the same calm start. Changes: tuning `threat.level`
(stage overlays), RunNews.alert_chunks starts RampageSim.escalation at that level's share of the spawn ramp; the badge
is fixed all run and the "threat rises" crawl lines and event are gone (capture_threat.gd removed). Same day, no
enemy hit points: "if the tank gets smacked by a kaiju, i want that tank to go flying and die, not take hp damage";
picked "Yes, all kaiju", helicopters "Yes, one blow", "In the threat PR". Tank, helicopter and VIP hp are deleted:
a blow that reaches a tank wrecks it. Then "a stomp shouldnt send it flying but a tail swipe? or a charge attack?
yeah it should go flying"; picked claw swipe and explosions too. Tail lash, ram, leap ring, claw swipe and explosions
throw it (SimDamage.throw, flight blow_throw/throw_min/throw_max) and it comes down wrecked; stomp, slam, crash, bombs
and breath wreck it where it stands. One blow downs a helicopter, burst_blow or more blows it apart; chem cloud wrecks a tank after cloud_tank_seconds. Threat now
sets only spawn rate, helicopter cap, Taskforce and rooftop volley damage, never toughness. 11-02, balance: with no enemy hp the army stopped winning (pacing, reptilian: defeats Behemoth 2 of 20 vs main's 14
of 24, Colossus 3 of 34 vs 24 of 39); he picked "Army harder" and then "B as measured" over +1 levels and +1 heli: tank
hits x1.5 (Behemoth tank_damage 6.9 to 10.4, Colossus 7.3 to 11.0) and Colossus helicopter hits x1.5 (air damage 5.4
to 8.1); measured defeats 9 of 21 and 26 of 37, second evolution 0.80 h. Threat suite on/off
fixture: Behemoth city at level 3 vs 1 (escalation, helicopter cap); sim fixture: the same blow thrown (a sideways hit) vs crushed (a stomp).
11-02, Q: from level 3 the city's start puts the Taskforce wait at its 8 s floor, so destruction no longer
hurries the squads in grown cities; keep, or a wait only destruction shortens? A: "Keep 8 s from start".


## 2026-11-01 · D-434 · Director · The open sea's fine ripple fades with distance instead of tiling
His words: "bay texture looks bad from above zoomed out". Q: what looks bad? A: "Repeating pattern". Q: strong or gentle
fade? A: "Gentle fade". Why: the ocean's FFT cascades (8.8, 5.7, 1.6 m tiles) have no mip chain, so from high up one
pixel spans many texels and the fine tiles alias into a repeating speckle. Changes: water.gdshader fades each cascade
by its screen footprint (texels per pixel) between tuning `water.ocean.fade_texels` [3, 12]; the game camera's near
water is unchanged. Water suite check `_check_ocean_fade`.

## 2026-11-01 · D-433 · Director · The bay bridge is gone: no freeway stands in the front
His words, with a crop of the deck on piers across the bay: "i really hate this bridge, i have no idea why its even in
the game, remove it entirely". Why it was there: CitySkyline's elevated waterfront expressway (Tokyo's Shuto, the
pre-harbour skyline) ran 9 m inside the old quay; when the fixed front put the sea right up to the coast (D-381) it
was left standing on pillars across the whole bay, lamps and all, and read as a bridge; the two inland freeways
started in the water beside it. Changes: the waterfront expressway is removed; the inland freeways begin on land at
the front's back street (where the random grid starts) when the city has a harbour, so no deck stands in the bay,
on the beach or in the port. City suite fixture tests/lib/city_front_clear.gd (every city failed before, none after).

## 2026-11-01 · D-432 · Director · The mission panel is a compact card, not a full-height column
Replaces D-431's "Right side column". On the 1080p stills he called the full-height panel "AI slop", a giant box
with nothing in it, and picked "Compact card": the same lines and look, the box sized to its text and centred down
the right margin. The globe test fails a card taller than half the screen. On the card he also cut the "WIN ONE:"
label ("awful ai slop"; the bonuses stand alone, and the pick screen is headed by the continent's name) and the
"+10% Moves faster" wording ("syntactically meaningless"): each bonus stat has its own phrase with the number
inside ("Moves 10% faster", `bonus_lines` in data/continents.json).

## 2026-11-01 · D-431 · Director · Globe mission panel: a right-side column, and a Win/Lose stub mission with the pick
Overworld plan row G5, his picks: "Right side column", "Leave them out", "Win/Lose stub + pick". A picked continent
shows a full-height card down the right third (the continent stays in view on the left): its name, its stage in game
words, Threat +N%, WIN ONE: and its three bonuses in plain words, and LAUNCH. The city preview and landmarks are left
out until plan rows C1..C5 make them. LAUNCH opens a plain stand-in mission with WIN and LOSE until real cities start
from the globe: WIN offers the three bonuses, the player keeps one (D-421), and the globe returns with the continent
conquered, its bonus kept and Threat raised by its share (D-422); LOSE returns with nothing changed.

## 2026-11-01 · D-430 · Director · Globe continent states: grey coastline locked, pulsing yellow available, green conquered
Overworld plan row G3, his picks: "Grey / yellow / green" and, for locked, "Coastline only". A locked continent draws
only its coastline in UiKit LOCKED grey, no fill; an available one fills in ACCENT yellow and pulses slowly (one
breath every 2 s); a conquered one fills steady in UiKit GOOD green. Which continents are available follows D-420 and
D-422 (Campaign.states, read from the save's conquered list). Locked continents' markers turn LOCKED grey and the
continent neither lights on hover nor answers a click (his pick: "Grey, not clickable").

## 2026-11-01 · D-429 · Director · Globe mission markers: pin and name on all seven, click turns and zooms in
Overworld plan row G4, his picks: "Pin + name" (a small yellow diamond on the continent, a leader line up and right
to its name in caps, ACCENT yellow with a dark outline), "All seven now" (the offered-pair filter waits for T1, the
colour states for G3) and "Turn + zoom in" (a click turns the continent to the centre and closes the camera in over
0.7 s, eased; the spin holds while one is selected; a click on sea or Esc flies back out and the spin resumes). Shown the stills, "Keep both": Aurelia's pin (the south polar cap)
stays out of view at the default lean until the globe is dragged down, and Neptunia's one pin stays on its southern
islands with the northern islet chain unmarked.

## 2026-11-01 · D-428 · Director · The open sea is a copied FFT ocean; the sim's waves ride on top
Of the whole-bay water (D-426) "looks functional but ugly and not very realistic", and he picked "Copy a proven ocean
(Recommended)": the GodotOceanWaves Tessendorf FFT ocean (MIT, 2Retr0, commit a171446f; licence register row) runs
as OceanWaves, map 256, waves heading -107 degrees (in from the open sea). It is Froude-scaled by 0.1 (tuning
water.ocean.scale: tile, fetch and depth x0.1, wind x sqrt 0.1), so troughs stay under a metre and never bare the
seabed, while slopes stay those of the real sea. It fades out over the shelf where the sim's swell takes over. Its
wind-wave crest lights the water at 0.15 weight, as the sim's does: at full weight crest_light 1.4 drove a trough's
colour below zero, which the premultiplied blend drew as black blotches by the shore.

## 2026-11-01 · D-427 · Director · Load screen: 12 graded dusk stills, random each load
His shot list for load-screen art: "get caps of the powers / destruction / the city from panoramic angles / all three
kaiju forms / then edit the photos to be more epic", then "remove the ui from the screencaps". Shown the board of 12
(tools/capture/capture_load_art.gd: paused dusk rampage, staged cameras, no UI; graded for bloom, split tone,
contrast and vignette), he picked "All 12", grade "Keep as is" and "Random each load". The loading overlay shows one
4K still (assets/loading) behind INCOMING and the meter, never the same twice in a row (comment #92, D-140, D-359).
The band sits just above the crawl so the kaiju in mid-frame stays in view.

## 2026-10-31 · D-426 · Director · The whole bay is water: native step, open mouth, swell lifts the sheet
On the sea lying flat except one rectangle of waves round the kaiju (the sim stepped only an 80 m window by him,
walled at its edge): "investigate why all the water is flat except for this rectangle then fix it so all water is
behaving like water", and of the options he picked "Whole bay + real swell (Recommended)". The bay's shallow water
is stepped whole every frame by native code (KaijuWater, bit for bit the GDScript pipes; 1.8 ms at most for the
436x50 cells), its mouth is open sea (a wave runs out there instead of bouncing back), and the shader's swell lifts
the sheet itself everywhere, dying out over the shelf, so the whole sea rolls even when he is still.

## 2026-10-31 · D-425 · Director · The demo is Ostia Minor plus one pick of Carthago or Thule
Asked which continents the croc-only demo covers, he picked "Ostia to Carthago/Thule", then, told that both play at
Behemoth (D-419) so the demo has no Colossus stage, "Ostia + one pick": Ostia Minor (young), then the player picks
Carthago or Thule (Behemoth) and the demo ends after that conquest. Young and Behemoth only. Changes D-212's "the
full croc game" and the demo's "three cities" (D-050, D-145, D-156).

## 2026-10-31 · D-424 · Director · One kaiju per mission
Ruled with the Overworld plan (claude.ai artifact PcHHG2EhRYsKfBzC2ZkQkV, "Settled on 31 Oct"): a mission is played by
one kaiju; there is no tag-team or second kaiju in the same city.

## 2026-10-31 · D-423 · Director · Komodo after the first conquest, serpent after the second
Same ruling set. Species unlocks ride the path, not the map: the Komodo dragon unlocks after the first continent
conquered, the serpent after the second, whichever continents those were. Rewords D-197 ("finishing the first city
unlocks the Komodo, the next city the serpent"), since cities no longer come in a fixed order (D-420).

## 2026-10-31 · D-422 · Director · Global Threat Level; the sixth conquest sets 100% and opens Aurelia with GODBREAKER
Same ruling set. One campaign-wide Threat Level: each conquest adds its share and in-mission noise adds the rest, but
noise caps at 99%; only the sixth conquest sets 100%. At 100% the capital Aurelia opens with the mecha boss inside,
named GODBREAKER (its loss card reads K-07 LOST · GODBREAKER DEPLOYED; prestige faces GODBREAKER Mk II). Replaces
D-211's trigger ("once every upgrade of all three reptilians is unlocked"); the mecha itself (D-211, D-227, D-230) is
unchanged.

## 2026-10-31 · D-421 · Director · A conquest bonus is a pick of one from three
Same ruling set. Conquering a continent offers three bonuses and the player keeps one. The bonus lists in the plan
are proposals, still to be reacted to.

## 2026-10-31 · D-420 · Director · The globe offers the two lowest-tier unconquered continents in sequence
Same ruling set. Ostia Minor comes first; after it the globe always offers the two lowest-tier unconquered continents
in the fixed sequence Carthago, Thule, Silvania, Mons Ferrata, Neptunia: conquer one and the next in sequence joins
the pair. Difficulty always climbs and the choice is real (16 paths; the sixth pick is forced). Aurelia is last
(D-422).

## 2026-10-31 · D-419 · Director · A continent fixes the growth stage
Same ruling set. Each continent plays at one growth stage: Ostia Minor young; Carthago and Thule Behemoth; Silvania,
Mons Ferrata, Neptunia and Aurelia Colossus. Seven cities, not three per stage. Replaces "three cities (baby,
adolescent, adult)" in DESIGN.

## 2026-10-31 · D-418 · Director · Seven continents on Tellus Nova
Same ruling set, the first act of the Overworld (plan rows F1-F4): the campaign is a hologram globe of the planet
Tellus Nova with seven continents, six conquerable and the capital Aurelia, ancient-Rome named: Ostia Minor, Carthago,
Thule, Silvania, Mons Ferrata, Neptunia, Aurelia. Each continent is one city mission. Changes D-212's "three cities".

## 2026-10-31 · D-417 · Director · Kaiju legs skin with centre-of-rotation; adult thighs thickened 1.3x
On the thigh deforming badly (thin tube, pinched at the belly, creased when the leg swings back): "Yes, build CoR".
Blend weights now pivot about baked centres of rotation (tools/kaiju_skin/cor.py, voxel_skin QLERP, render_opt
.kaiju_cor_skinning), which stops the volume collapse; the thigh stayed thin standing because the model is thin, so
"Thicken + keep CoR": thicken.py pushes leg_x0/x1 voxels out about the femur, tapered to the knee and into the hip
(tuning skin_bake.thicken). Of 1.0/1.15/1.3/1.45 side by side the director picked "1.3".

## 2026-10-31 · D-416 · Director · Purple electricity crackles on the water before the rise, not spray
Seeing spray rise before the head broke the surface: "why would there be bubbles coming up / instead, have the waters
surface start crackling with purple electricity / then, as he emerges ... incorporate the same purple electricity into
the water burst". The pre-rise spray column is removed; arcs of the kaiju's purple bolt (D-357) skate over the water,
more as the rise nears (scenes/intro_crackle.gd, tuning intro.water crackle_*). At the break the burst is thrown up
round his body and the same arcs climb it; on "the lightning lingers way too long" they thin to none 0.5 s after he
surfaces (burst_arc_seconds). "Yes, ship it". Amends D-414's fountain.

## 2026-10-31 · D-415 · Director · Stand-in boxes show the real facade; the swap is invisible
A streamed building's stand-in box shows the building's real windows (the same lit and dark windows as its voxels), so
the swap to voxels has no pop-in. He chose a hard swap that "should be invisible" (no dither fade), the playable city
only (the far skyline keeps its shader pattern), and a longer load: "i dont really care if the load screen goes for
10-15 seconds as long as the gameplay is smooth" (replaces his earlier "Up to 3 s"). The facade is baked at load
and cached on disk; he accepted that only the first visit to the largest city bakes longer (stage 3: 32 s cold, 0.19 s
cached).

## 2026-10-31 · D-414 · Director · The water is real liquid: waves, run-up, splash, a massive fountain; no flooding
Asked for real physical water (waves, lapping at the shore, splash physics, ripples, no flooding, water still puts out
fire, the kaiju emerging in a massive fountain), replacing the looks-only water of D-244/D-122. A shallow-water sim
(sim/water_sim.gd, 2 m cells, seeded) carries every wave; his body displaces it, stomps and the rise throw splashes.
Water never floods the city. The painted swash is removed ("Yes, remove it"): the waterline is where the sheet passes
under the sand, with a wet sand band above it. On a sand bar he chose "Steeper near shore": the seabed drops 1.2 m in
the first 10 m, then to wading depth 2.5 m by 40 m. Final shoreline: "Yes, ship it".
## 2026-10-31 · D-413 · Director · Boats slow enough to catch; rock that shows
"Retune, then reclip", then "Yes, ship it" on the 1080p dusk river clip. A boat fled his wake at up to ~8.8 u/s, he
walks ~2.5, so none ever capsized in play. data/tuning.json boats: flee_push 6 -> 2, drag 0.5 -> 1.0 (top speed
~1.5 u/s), wake_rock_deg 22 -> 35. Clip camera: "Fixed side camera" (tools/capture/capture_boats.gd --side).

## 2026-10-31 · D-412 · Director · The Lightning Breath is a purple column that chains over what it hits
"Make the lightning breath look like a dragon fire lamp": a dense purple column that pools and chains along the ground
and climbs the buildings it strikes. Sheet at dusk: "looks good". The sim's damage stays (a measured breath fells two
18-19 floor towers whole and slices seven more).
Asked "does it damage what the VFX touches?": the bolt is now cut where it meets a chunk the sim left standing, so
it is drawn only through what the strike broke (frame-by-frame audit: 0 of 94,612 points in standing chunks). Same PR: the breath gets its own input bit (BREATH 4 -> 8); since
#455 it shared the dash bit, so every breath also leapt and the croc floated ("why hes floating in the air").

## 2026-10-31 · D-411 · Director · The tail lash winds up 1.5 s, then lands; cooldown 3.5 s
The keyed fix3 lash ("looks great … looks shippable") curls the tail round for ~1.4 s before it strikes. Asked whether
the button keeps instant damage or plays the curl first: picked "Full windup (Recommended)". The press emits
tail_windup, the hit lands lash_windup (1.5 s) later with the keyed strike; lash_cooldown 1.2 -> 3.5 s. Adult and baby
play the Cascadeur take (lash_r, mirrored lash_l); the adolescent keeps the code whip until its y7 skeleton ships.
Proof waived by the director ("i dont care for the proof just merge it").

## 2026-10-31 · D-410 · Director · Reference motion may be copied exactly onto our rigs
"you can copy the examples EXACTLY if thats best practice, dont be obtuse, its still an invisible skeleton in an
original model". Godzilla, T-rex and other reference motion is retargeted key for key onto our original kaiju; no
licence check and no credit needed for the motion. Replaces D-302's licence line for motion references.

## 2026-10-31 · D-409 · Director · Keyed stomps are judged on the take, not the procedural bars
Wiring the Colossus Cascadeur stomps (roadmap row 1), the take missed four croc_standing bars written for the code-built
stomp (lift 0.31 < 0.4 hip, toe 0.023 hip off at the footfall, body 0.020 hip off calm 0.3 s on, six stomps identical).
Asked: change the take or the checks? "Change the checks": lift > 0.3 hip, toe and body within 0.03 hip, no
variation bar (one take plays the same each time). Landing inside STOMP_WAIT and alternating feet stay.

## 2026-10-31 · D-407 · Director · Colour-blind cues move to after the demo
"push colour blind fixes to after demo". The check found #229's options carry no colour-blind setting; the threat
meter (#234) already reads by segment count. The colour-blind pass is a post-demo roadmap row, not a demo gate.

## 2026-10-31 · D-406 · Director · The demo ships in English only; only English is checked
His words (10-31): "remove the chinese test checks, we only going to ship the demo with English", then "remove checks
for all languages other than english". strings.py checks only the en column (CHECKED); check_i18n.sh no longer runs
subset_cjk.py --check and lint.yml no longer fetches kaiju_cjk.ttf. The seven columns stay in the table.

## 2026-10-31 · D-405 · Director · Time's up is an AIRSTRIKE: a jet run of Tripo olive jets
His words (10-31), on "killed by the final strike": "i hate the copy, all deaths are from the final strike technically
so its just meaningless babble, change it". Picked headline "AIRSTRIKE", strike "Jet run" (D-263's railgun volley is
dropped), jet model "Tripo, olive drab": J01, task 7536acba-0e5f-45dd-9f08-e06a93959859, 65 credits from the 1,500-credit
consent (D-400), balance 5,240 after. At time's up three jets cross the screen through him and carpet-bomb his street
(FinalStrike, death.airstrike), then he dies as before. The subline "The army ran out of patience" is the lead's
wording, for the director.

## 2026-10-31 · D-408 · Director · Rubble casts no shadows
"Ship shadows off", after 1080p stills on vs off (bulldozer frames 1800 and 2600). Rubble heaps, strips and thrown
chunks (RuinYard) stop casting shadows: data/tuning.json destruction.ruin_shadows = 0. Peak ruin: GPU p50 22.0 ->
21.2 ms, shadow draws 2,442 -> 2,123 (docs/research/2026-10-31-cpu-profile.md).

## 2026-10-31 · D-404 · Director · Boats are Tripo models, up to 300 credits
His words (10-31), on the boats DESIGN.md specs (moored, they rock, capsize and flee his wake): "Tripo models";
moored at "Harbour piers, Bay where he rises, River"; budget "Up to 300" credits, taken from the 1,500-credit
consent of 10-30 (D-400). Generated 10-31: trawler, tug, yacht, launch, 260 credits
(provenance C:/Users/DANTE/cascadeur_bridge/city_boats/provenance.md). Spectacle only: nothing reaches the sim.

## 2026-10-31 · D-403 · Director · Touched suites run locally; a PR runs lints and the sim suites; engine suites go to main
"im sick of the CI purgatory". Three rulings. (1) Relaxes D-383: before a push, run the suites nearest the change
locally, `python tools/run_touched.py` (walks back from each changed file to the first suites that reach it; `--all`
for every suite that reaches it, `--engine` adds touched engine suites). (2) The suites are split: 21 that need the
full engine (a scene, camera or capture; the `engine` line of tools/ci_timings.txt, picked by a .tscn, Camera3D,
viewport or texture read in the runner or its tests/lib helpers) and the sim suites (the rest). (3) A pull request runs
the lints, the compile preflight, the native build and the sim shards (heaviest ~322 s); the engine suites join the
D-382 slow job on main, and the harness self-test and engine log smoke block `test` on main only. A new suite counts as
sim until it is added to `engine`; moving one is a decision here. Changes: tools/ci_timings.txt,
tools/plan_ci_shards.sh, tools/ci_retime.py, tools/run_touched.py, .github/workflows/tests.yml, CLAUDE.md.

## 2026-10-30 · D-402 · Director · Grown railgun locks last longer, so the eased walk-off still dodges
With the 1.3 s walk-start ease (D-355) a Behemoth stepping at the lock was only 2.2 from it after 1 s and was hit. Asked
what gives: "Longer grown lock (Recommended)". `taskforce.railgun.lock_seconds_by_stage` 0.6 / 0.75 / 1.0 becomes
0.6 / 1.0 / 1.3; the ease stays 1.3 s. The dodge test waits the stage's lock, not a fixed second.

## 2026-10-30 · D-401 · Director · The tail lash takes the signature button; the breath gets Q / pad X
Building the D-280 lash (the render plan is done, so D-329's wait is over). Asked: the breath fired from the signature
button, so where does it go? "Breath on a new button"; which keys? "Q / pad X" (photo mode's Q and X stay, as E
already shares). Where is the ring? "Behind-and-around" (the half ring behind and beside him). The automatic whip goes
and its nodes (r_tail, r_shear, the Colossus tail nodes) upgrade the lash (D-328). Animation: "Cascadeur clip first",
for "All three stages": the lash does not ship until the young croc, Behemoth and Colossus each have a lash clip; the
procedural whip stands in until they land. Amended the same day: "Merge now" (the lash merges with the
procedural whip; the clips follow).

## 2026-10-30 · D-400 · Director · The 20 Tripo street props ship, at half the buildings' cube
His words (10-30), on P01-P20 (D-266): "theyre good, ship"; cube size: "Half (~19 cm)". Every prop is its baked
`.kvox` (`tools/street_props/bake.sh`) at voxel 0.0625, half the buildings' 0.125: pavement furniture along every
playable street, a traffic light at each lit crossing, the lamp model on every streetlight, Tripo cars among the
parked and stopped ones (the decor's own car keeps the rest). All crushable. Tuning `city.street_props`. His
1,500-credit Tripo consent (10-30) stays in reserve: this ships with 0 credits spent.

## 2026-10-30 · D-399 · Director · The rise bar is removed
His words, on D-384: "remove this rule / it makes no sense its claude gibberish". The city suite no longer times
the walk from the rise to the first beachfront hotel: city_rise_forms goes and SpawnView keeps only its stand-in
check. Replaces D-384 (and the 10 s rise bar it carried from D-131).

## 2026-10-30 · D-398 · Director · The kaiju gets his own hide grain
Flat surfaces P3, part 3: the kaiju is textured with his OWN hide grain, not the city's block grain
(`scenes/hide_grain.gdshaderinc`: scutes with dark crevices, a tone shift per scute, a few flecks, in the hide's rest
space so it rides the bones; seeded). Numbers in `data/looks.json` `kaiju_hide_*`; `kaiju_hide_on` is the on/off
switch the onelook check flips. The look itself is his call on the stills before it lands.

## 2026-10-30 · D-397 · Director · Plane lights and skyline lamp heads are lights, not surfaces
"Exempt as lights": the aircraft's blinking lights and the skyline lamp heads join `vfx_exempt`, so the flat-surface
rule does not apply to them; they leave KNOWN_FLAT (flat surfaces P3 part 2, cap 3).

## 2026-10-30 · D-396 · Director · The tree screen is a bio lab, built in full
Roadmap item 1, "Tree screen skin": "bio lab aesthetic". On the first, palette-only version: "I dont even know what you
changed, looks identical, this isnt a small job, this screen is pivotal to the games appeal. it is a dopamine goldmine,
it needs a lot of vfx, sfx and beautiful UI design". So the screen is a specimen plate with glass cells that fill with
Special K, tubes that surge and bubble, motes from the biomass counter, a rim flare when a ring opens, lightning on an
evolution, a scanner sweep, a lab readout for the side panel, and its own sounds. "go straight to the build" (no mockup
board); "500 credits sure": ElevenLabs sound effects up to 500 credits for this screen (precedent D-237). The ElevenLabs
connector was not in the building session, so #445 ships the four tree sounds synthesised in `tools/sfx/build_sfx.py`
(0 credits); the 500 stay approved for replacing them from a session that has it. The kaiju himself, at his current
stage, turns at the empty centre of the rings: "yes". Tuning `tree.skin` and `tree.skin.fx`; `fx.enabled` is the
on/off switch the fixture flips.

## 2026-10-30 · D-395 · Director · The feedback link is the Itch page
His words (10-30): "https://veniceissinking.itch.io/kaiju". The thanks screen's LEAVE FEEDBACK opens it (tuning demo.feedback_url); replaces the placeholder D-148 left.

## 2026-10-30 · D-394 · Director · The landmark pool's named entries
His words (10-30): "giant donut that will detach and roll"; "large church"; "airport"; "a theme park with rides and a
ferris wheel"; "a castle (tourist destination)". With "Spire + megatower" (built in code, free), these join the
stadium and wheel in the D-375 pool. Rings (lead table, director "sounds good"): donut and church medium; castle and theme park big; airport biggest. The donut's roll is new sim behaviour and gets its own task. Big and biggest share the outer ring (no fourth ring): Q: a ring of its own for biggest? A: "they can arrive with the spire".

## 2026-10-30 · D-393 · Director · The graphics preview lifts the menu frame cap
A: "Yes, lift it": while Settings (with the comment #90 preview) is open, menus run at the player's own FPS cap, not
menu_fps 60, so the frame rate the preview shows is the real one; closing Settings restores the menu cap.

## 2026-10-30 · D-392 · Director · Six languages plus Chinese: Simplified Chinese, Spanish, Italian, French, Russian, German
Roadmap item 1. Fonts: "Draw + Noto SC": accented Latin and Cyrillic are drawn into the four Kaiju faces
(tools/fonts/glyphs.py); Simplified Chinese falls back to Noto Sans SC (SIL OFL 1.1), subset to the game's characters.
Translations: "Claude now, review later": Claude writes every language into `data/i18n/strings.csv`; a native
check before release is a separate spend question. The language is a button on the Accessibility page.

## 2026-10-30 · D-391 · Director · The roadmap moves to a Claude Doc
A: "Yes, redirect it": the roadmap lives at https://claude.ai/artifact/CvbnH4ZPRZDLha74homA8Q; `docs/ROADMAP.md`
points there; the old file is frozen as `docs/archive/ROADMAP_2026-10.md` for detail agents cannot get from the doc.

## 2026-10-30 · D-390 · Director · The baby roar's jaw is judged in the game, not on Cascadeur's mesh
Q (10-30, after the lip slit and three weight fits left Cascadeur's mesh at 18-22 head flips on the baby roar, bar 6):
"Accept game result". In the game the baby's mouth already opens as a slit (the bake's hinge rule, #356): at a 38 deg
gape every parting is jaw|head1 along the mouth, none at the corner or throat, red mouth voxels shown. The mesh bar is
dropped for the baby roar; no edge loops are added. Changes: roadmap row 1's baby jaw is done with #426.

## 2026-10-30 · D-389 · Director · River bridges carve on cells
Q (ROADMAP 4, "carve is universal"; river bridges were flat decks CityGround drew, never broken): they picked "Carve,
spans drop" and "Keep deck, add piers". Each river bridge (CityRiver.bridges) is now a row of buildings, one per span
(tuning bridge.span, sim/bridge_layout.gd, the railway's pattern): an asphalt deck at street level, a stone parapet
each side, a pier to the riverbed at each end. A piece's floor 0 is the riverbed, bed floors under the street
(Building.base), so a deck cut off its piers drops or tips into the river. CityGround keeps only the abutments; the
Rect2s still feed quays, decor, roads and pathing. Bay bridges and the diagonal deck stay flat decks. The spread
suite's "1.5x city razes a smaller share" check goes (he picked "Drop share check": with bridges breakable it read 40%
vs 39%, a balance number under D-385); its bigger-city and replay checks stay.

## 2026-10-30 · D-388 · Director · Landmarks carve on cells
Q (ROADMAP 4, "carve is universal", director 2026-10-26): landmarks broke by chunks only (Carving.takes skipped them).
Now a landmark promotes to its LandmarkCells grid on its first hit and blows carve its cells like any building's. A
ring landmark's arcs (the stadium) keep the chunk rule on cells: once an arc has lost arc_shed_cells cells, its
section above the stub comes down as one topple over the stub's edge (rim outward, stands inward) before the support
settle. Landmarks keep their cut side (D-387). Bay bridges still render as decks (river bridges carve, D-389).

## 2026-10-30 · D-387 · Director · b2-5: topples fall in a seeded mix of directions
Q (b2-5, "buildings seem to ALWAYS collapse toward our kaiju ... make the collapse directions more varied"; D-099 sent
every topple to its cut side, and a base eaten whole toward the kaiju, so most fell onto it): they picked "Seeded mix":
each topple draws its direction from the run's seed, its cut side 40%, either side of that 25% each, away 10%
(data/tuning.json destruction.fall_dirs). Replayable; some towers still land on the kaiju. Landmarks keep their cut
side. Amends D-099 (the cut side is now the likeliest way, not the only one). Not chosen: mostly sideways, fully
random, away mostly.

## 2026-10-30 · D-386 · Director · A PR re-push re-runs only failed, unrun or touched suites
He approved: a pull request's re-push runs the suites that failed or never ran on its last run, plus every suite whose
code changed since (tools/ci_select_suites.py: a changed .gd/.tscn/.tres in the suite's res:// or class_name
closure, autoloads included); any other changed file or any doubt runs everything. Main still runs everything: a
main push reuses only a PR run that tested every suite. Why: re-testing passed suites cost an hour per fix.
