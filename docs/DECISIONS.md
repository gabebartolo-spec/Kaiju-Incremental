# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. The lead owns the wording; a decision goes in the PR that acts on it (any PR may carry it).

## 2026-11-01 · D-430 · Director · Globe continent states: grey coastline locked, pulsing yellow available, green conquered
Overworld plan row G3, his picks: "Grey / yellow / green" and, for locked, "Coastline only". A locked continent draws
only its coastline in UiKit LOCKED grey, no fill; an available one fills in ACCENT yellow and pulses slowly (one
breath every 2 s); a conquered one fills steady in UiKit GOOD green. Which continents are available follows D-420 and
D-422 (Campaign.states, read from the save's conquered list). The mission markers stay yellow on all seven.

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

## 2026-10-30 · D-385 · Director · Tests guard behaviour and bugs, not balance numbers (rank 1 now)
Q (audit of all 76 suites on fb5e3adbc: which checks freeze tuning or old measurements so polish turns CI red with
nothing broken?): he picked "A: rank 1 now" (rank 2 as each check next breaks, rank 3 when convenient). Implementation
and polish come before balance tuning. Rank 1 now: military parked-in-range floor over hand-picked seeds becomes "a
tank that parks sits in the band"; motion gate steps-per-second bands go (footfall = clip stride and no slide stay),
foot lift one range for every stage, knee jerk one shared ceiling; gait's young route pinned to 1 mm becomes a turn
rule plus two runs match; pinned fingerprints (street, cells, landmark cells, destruction trace and island sizes)
go, run-vs-run matches stay; menu checks by exact wording and pixel gaps become overlap / on-screen / reachable rules;
species lists come from the data. Kept: slide, catch steps, knee pops, locked legs, NaN, overlaps, determinism, saves,
text size and contrast. Report: the audit's REPORT_tests_too_strict.md. Replaces motion_gate.json's "never widen".

## 2026-10-29 · D-384 · Director · The rise bar counts to his first hotel down, sand walk included
Q: with the fixed front (D-381) sand lies between where he rises and the hotels, so the old bar (every building within
12 m of the rise down in 10 s) has nothing in reach. His answer: "Hotels hit in 10 s": keep 10 s, counted from when he
stands up out of the sea to his first beachfront hotel down; the walk across the sand counts (the sand gets umbrellas
and crowds to smash on the way). Changes the city suite's spawn-view and rise-forms checks; the river look's
landing-nearness part goes, the bar covers it. Replaces D-131's 12 m reach, keeps its 10 s.

## 2026-10-29 · D-383 · Director · No local test runs: push and CI is the test (relaxed by D-403)
Q: why run locally the same suites GitHub runs ("ok so remove that rule from existence becasue i hate it")? A:
a change runs only the cheap local gates (lint, schemas; no Godot), then is pushed and CI runs every suite. No
local Godot suite run to check a change before it goes up, not even the suites it touched. Replaces the last
clause of the archived local-prepush decision ("builders still run locally only the suites they iterate on").
Probes that measure something a fix needs still run locally.

## 2026-10-29 · D-382 · Director · A pull request skips the slow second-angle suites; they run on main
His words: "which of these, if any, can we remove, or is it necessary for us to run them all for EVERY patch? its a
real bottleneck for dev time"; on the list: "Yes, write D-382". No suite is deleted. Thirteen slow suites that check the
game from a second angle run on every push to main only (the `slow` job, 3 lanes, never blocking): streamview, load,
counts, crowd, empty_space, roads, heliflight, skyline, city_audit, demoend, croc_standing, slowmo, results (4,365 s of
8,802). Everything else, motion and smoke included, runs on every PR (until D-403: engine suites moved to main too). The list is the `pr_skip` line of
tools/ci_timings.txt; moving a suite in or out is a decision here. Why: the last green PR run took 18 min, shard 1
alone 17.5 (12 suites had no timing row, flow@2/2 was 592 s); re-measured and with flow in 4 parts the heaviest shard
plans at 527 s, with the skips 322 s. Changes: tools/ci_timings.txt, tools/plan_ci_shards.sh (--slow hands a split
suite over as its parts), tests.yml slow job (native library, 60 min, logs), tests/README.md.

## 2026-10-29 · D-381 · Director · The beachfront is one fixed, bespoke place; the random city joins it
His words: "build this as a bespoke, fixed location, its always the same, just have the randomzied map connect to these
fixed roads and environmental positions"; board v4: "Yes, build it". So: the front the kaiju rises from is the same at
every seed and stage (CityHarbour; tuning `harbour`): a decently long sand beach curving along the sea, promenade, beach
road, hotel blocks on pavement between fixed side streets, and past the beach's east end a separate port bay with a
man-made seawall, breakwater, piers and quay yard. The random map connects to its roads. The sand gets crowded later
(volleyball nets, umbrellas, lounge chairs, people). Replaces D-377's one bay size per stage: the front no longer grows.
The front sits north of the arena's centre (back street z -7, sea line z -80; director "Push front north"), so every
stage keeps a city behind it and the young arena still shows a strip of sea; he rises just outside the young arena and
wades in. Port picks (director 10-29): STS crane A2, container stacks B1, sheds C1. Built (10-30) as pool models
P01-P03 authored in code (tools/port/build_port.py, no Tripo spend), district "port", role "fixed": CityPort stands
the same 4 cranes, 3 sheds and 29 stacks on the quay and yard in every city, where the real band reaches (stage 3).

## 2026-10-29 · D-380 · Lead (director "idc") · Stage 1 shows the east landmark spot only
Q: the bay start leaves the west landmark spot ~0.5 m past the baby's band (it cannot move north: the river
row). A (lead call A, director "idc"): stage 1 shows the east spot's landmark only; both spots from the
Behemoth. Bars name spots, never landmarks (spots fixed, the landmark in each rotates, director 2026-10-29).
Stadium-driven tests (flow, crowd) play the stage-2 city.

## 2026-10-29 · D-379 · Director · Rulebook, shared memory and personal skills removed; two rules kept
His words: "i want to straight up delete the rulebook"; "no spend without your yes / only you judge art / these are
the only things i want". On shared memory: "Archive it + stop refills (Recommended)" ("a good idea in theory but not
practice"). On skills: "can we delete all our skills, i dont think we need them"; Q: what should happen to the
skills? A: "Delete all outright". So: RULEBOOK.md no longer loads; `~/.claude/memory-shared` moved to
`~/.claude-archive/memory-shared-2026-10-29` and the stop hook no longer asks for lessons; the 14 personal skills in
`~/.claude/skills` are deleted (app-synced Anthropic skills untouched). `~/.claude/CLAUDE.md` keeps "straight to me",
no spend, end-with-state and write-concisely. Replaces D-378's rulebook and skill mentions.

## 2026-10-29 · D-378 · Director · Sessions boot on a small core; history is searched, not read at start
His words (~03:0x): "90% of them are pointless. really we could cull almost everything. no wonder our context is always
so high". Q: how hard to cut startup reading? A: "Core only (Recommended)". A session boots on its handoff, the CLAUDE.md
files, the rulebook and the DESIGN sections its task touches. Handoffs hold current state only, max 80 lines; their
history moves to `~/.claude/handoffs/kaiju/archive/`. The co-lead playbook, roadmap chapters and archives are grepped when
a task needs the why, never boot reading. Nothing is deleted. Changes: RULEBOOK (Session start, Context), kaiju-handoff
and game-studio-lead skills; lead handoff cut from 253 to ~60 lines.

## 2026-10-28 · D-377 · Director · The bay is a fixed block on the north edge; the city is laid around it
His words (~23:5x), after the cut-in bay kept leaving stubs and slivers: "instead of just throwing shit at the wall and seeing
what sticks why dont u make an implementation plan for the beach front"; "if its easier the bay can always be in the same
positon on the map, fixed location". Q: the plan (`C:/kt/beach_plan/PLAN.md`)? A: "Go (Recommended)". The bay is a
rectangle of whole blocks centred on the north edge, one size per stage in data; streets are pinned to its sides and a
coast road runs along its south side; the crescent sand, water and quays are drawn inside it; landmarks, parks and plazas
are never placed in it; the rise is at the bay centre. Player bars stay. Serves D-270, D-373; the beachfront pieces (D-277)
take fixed spots from it.

## 2026-10-28 · D-376 · Director · Windowed Godot runs start by GPU load check, not one at a time (replaces D-340's rule)
His words (10-28 ~22:1x): "that wasnt something i told you to codify though, it was something specific for that time, i
never told you to make it a rule". Q: what replaces it? A: "Load check (Recommended)". `C:/kt/gpu_slot.sh` admits a
window when under 3 Godot windows are open, >=3 GB video memory free, GPU use <85%, <80 C, 20 s after the last start
(logged in `C:/kt/gpu_slot.log`); gq runs up to 3 window jobs. D-340's "don't cook the GPU" aim stands.

## 2026-10-28 · D-375 · Director · Landmarks are drawn at random from a pool into designated spots, tiered by stage
His words (10-28 ~21:xx), on the stadium placement clash between D-270 ("south, past the river") and D-271 (reachable
from stage 2) once the bay moved the start: "so i want maps to be randomised as you know, but if we need to make certain
constants like stadium is west, wheel is east, thats ok, as long as the rest of the city is random"; "as long as you are
also considering that landmarks will be picked at random from a pool of many"; "so the stadium and wheel are no
certainty to appear"; "we can have designated landmark spots though". Q: tier the spots by stage? A: "Tier per stage
(Recommended)". So: each street plan keeps a few designated landmark spots; each run fills every spot with a random
landmark from a large pool, drawn from the tier that spot's stage reaches (near the beach medium, stadium and wheel
size; the next ring big, spire size; the outer ring the biggest, megatower size), so every stage still reaches something
bigger. The stadium and wheel are two pool entries, not certain to appear; when drawn, the stadium takes the west spot
and the wheel the east one, inside stage 2's reach. Everything else stays random per seed (D-263). Replaces D-071's fixed
four in order and D-270's "south, past the river with the Ferris wheel"; D-271's reach holds.

## 2026-10-28 · D-374 · Director · The Colossus rig gets hip and knee helper joints; every skeleton is checked over its full move range
His words (10-28 ~18:4x), on the knee/thigh crumple in charge, emerge, hlt, run, slam and leap, which skin weights alone
cannot fix: "add the joints, i asked you to make sure the skeletons were ready for animation, you failed, do your job
properly do not do lazy work". So: corrective helper joints at the hip and knee keep the big poses (no smaller-swing pose
bar); the young croc and Behemoth skeletons get the same full-range check and fix now; the Colossus drafts are
retargeted onto the new rig in Cascadeur (D-199).
