# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. The lead owns the wording; a decision goes in the PR that acts on it (any PR may carry it).

## 2026-11-03 · D-455 · Director · One roadmap, rebuilt; stale docs bashed
"stale and wrong; fix the cause; update the roadmap fully; clean up old docs." Cause: open rows lived in Claude Docs
one account could not open, and done work was never marked. Rule: docs/ROADMAP.md is the only roadmap; add an item
by PR the same day it is named, and mark it done in the PR that does it. Rebuilt ROADMAP.md from main at #561;
archived lead-howto, DEMO_PLAYTEST, the tentacle research; archive banners; cephalopod, role and skill refs fixed.

## 2026-11-03 · D-454 · Director · Globe LAUNCH starts the real city; unplayable titans hidden on the rack
His rulings: (1) LAUNCH on the globe starts the real city where one exists, at the continent's stage: Ostia Minor
today's beach, bay and river city, Carthago the cothon harbour, Thule the fjord (D-435 tuning). The other continents
keep the stand-in WIN / LOSE mission. A real city's rampage over returns to the globe and resolves as the stand-in did
(conquest on WIN, D-421, D-422). No rule yet says what wins a city (D-436: "Ostia's own win condition is to come"), so
until he rules the city's end opens the stand-in's WIN / LOSE. (2) The Komodo and serpent stay hidden on the creation
rack, vial and button, until their species are unlocked and playable (CreationRack "selectable": a species the build
has in species.json and allows); the croc unchanged. Changes: continents.json real_city (Ostia Minor, Carthago, Thule);
Campaign.real_city / city_stats (size = stage + 1, continent set); GlobeMissions starts a Rampage and hides the globe;
CreationRack.shown. Tests: tests/run_globe_mission_tests.gd, tests/run_creation_tests.gd _check_rack_hides_unplayable.

## 2026-11-03 · D-453 · Director · Calmed civilians never walk back toward the kaiju
Follows D-450 ("civilians sometimes flee toward the kaiju"). Remaining cause: a runner calmed past calm_radius (32 m)
and its plain walk picked any corner at random, often back toward the kaiju, to re-panic at 25 m: it read as fleeing
at him. A: new street.wary_radius (64 m, scaled like calm_radius); within it no walker takes a corner toward the kaiju
while another is left (else it goes back only if that leads away, or stands). GDScript only (KaijuWalk calls
Pavements.next_corner). tests/run_flee_tests.gd _check_calmed_keep_away (worst 0.016 m closer before, 0 after).

## 2026-11-03 · D-452 · Director · Dusk grade copied from Shin Godzilla
Reference: Shin Godzilla GKIDS trailer, frames A C D H I (director's pick; frames stay local). Base grade copies
A/C/D, measured with grade.py: black 0.003-0.070, mid 0.17-0.38, white 0.52-0.84, sat ~0.20, warm olive
highlights (h48-63), cool/green-grey shadows, hazy sky over a darker city. Concrete look: sky aaa688->c4bd9c /
horizon d6cfae, ambient 0.8 colour 667a78, sun e2dcb4 at 1.2, fog 7e8274 at 0.005, saturation 0.7, agx_contrast
1.7, post_contrast 1.0, new key exposure 1.2 (tonemap_exposure), sand aaa080. Game stills land black 0.06-0.16,
mid 0.27-0.33, white 0.82-0.84, sat 0.18-0.19, highlights h46-49. H/I breath violet: no change (fx.bolt is
already purple). Details: docs/research/shin_godzilla_grade.md.

## 2026-11-03 · D-450 · Director · Fleeing civilians never step toward the kaiju
Q: "civilians sometimes flee toward the kaiju; they must never do that." Causes: a runner's corner was checked only at
the startle, so once the kaiju moved (or a wreck survivor spawned fleeing) it kept running at it; at a corner it took the
linked corner furthest from the kaiju even when every one was nearer (a dead end sent it back past him). A: each frame a
runner whose corner lies toward the kaiju turns back (one dot product, GDScript and KaijuWalk alike); at a corner it
takes only a pavement whose first step leads away (a straight one then only gets further), else stands. tests/run_flee_tests.gd.

## 2026-11-03 · D-451 · Director · Closer read of the D-447 skips: three more identical trims
Under D-032. Rain smears rewrite only slots that were visible last tick (the rest already hold the hidden
values), and the lamp walk stops once lamp_max is reached. CarvePhysics reads live_bodies() once per tick, not
twice (a pure read; nothing changes in between). DebrisField returns right after advancing its clock when no
body, queue or head is left (the last _draw already zeroed every mesh; no RNG drawn). Skipped: crowd
lose_cells/_bury (already O(1) when idle; the only trim saves ~4 has() calls a second).

## 2026-11-03 · D-449 · Director · The leap never vaults a tower above his shoulder
Bug: the kaiju leapt onto the tops of extremely tall buildings. D-361 kept such roofs off the leap's target,
but LeapArc raised the arc over every building on the flight path, so a tower between him and a low roof (or
the open-ground landing) was cleared and he came down on or over its top. Now Dash.aim_at asks LeapArc.wall
for the first building on the path taller than his shoulder (the existing per-stage leap "shoulder" share x
drawn height, D-361; no new number) and makes it the target, taken in its side as D-361 does. Roofs at or under
the shoulder still land (Leap suite: _check_no_vault, _check_low_roof).

## 2026-11-03 · D-448 · Director · Falling buildings hit neighbours and the kaiju, never pass through
Q: a falling building passed through its neighbour and through the kaiju. Cause: a fall is a scripted pose (ToppleFx
tilt, CityFalls drop) checked against nothing until it landed; the kaiju had no physics body. A: FallContact (sim)
poses each falling part as the view draws it every tick and samples its chunks. A neighbour's live chunks it reaches
take a landing's blow (carved); one that survives stops it. The kaiju's hide (a rigid capsule, tuning fall_contact)
stops it at the first touch (bisected in the tick). It shatters there into DebrisField fragments thrown from outside
the hide. KaijuHide (AnimatableBody3D) follows him, so fragments hit and slide off. Max overlap (fall_contact
suite): neighbour 0.48 to 0.11, kaiju topple 1.03 to 0.00, drop 0.96 to 0.00. What a part touched as it began (the
base he chewed, a shared wall) and a topple's shudder never count. Rooftop fixture floor 1.0 to 0.9 volleys/s (1.09
to 0.97: roofs fall sooner). Not done: settled debris vs neighbours.

## 2026-11-03 · D-447 · Director · Per-frame CPU trims (no visual change)
Under D-032 (looks first): CPU-only savings, identical output. LightPool.repick walks the group once and tests
the near set by dictionary, not Array.has (O(n) not O(n^2)). Fire pushes base_y/fire_xz to its flame shader only
when it moves. TaskforceView reuses its per-frame id dictionaries. Skipped: weather rain smears, carve debris
totals, crowd lose_cells/_bury, debris early-outs (not trivially identical; need a closer read).

## 2026-11-03 · D-446 · Director · The counts run keeps the kaiju alive to the route's end
Main's `counts` suite was red since #536 (army harder, D-437): the army killed the kaiju at step 3307 of 3360
(over=true), so "the route played all steps" failed. The bar counts FxPool peaks over the whole route, not the
army, so bench_lib takes `hp` and counts sets 1,000,000, as the military and fire suites already do.

## 2026-11-03 · D-445 · Director · W walks forward: the stick turns with the camera
Q: "WASD controls dont work, seems like theres no way to walk forwards." Since D-330 the camera turns to sit
behind the kaiju, but the stick still pointed at fixed map directions (W = north, -z). At the rise he faces +z, so W
walked him back toward the camera. A: the stick is now camera-relative: it is turned by the camera's yaw and swing
(Rampage.view_turn). Probe after the rise, 3 s of W: before, 4.1 m backwards (-z); after, 8.1 m forwards (+z).
Holding A or D now turns him in a circle, as in any third-person game. Scripted and autoplay input stay in map
directions.

## 2026-11-03 · D-444 · Director · The roadmap is docs/ROADMAP.md in the repo, not the Claude Doc
Q: the Claude Doc roadmap opens from one account only. Should the repo file replace it as the source of truth?
A: "Yes, repo file". docs/ROADMAP.md is the roadmap. Roadmap changes go in it through a PR. The Claude Doc is
frozen and no longer updated.

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

## 2026-11-01 · D-436 · Director · Every city is the adult city at every stage
Asked why the city grows with the kaiju (D-039, D-254 half-widths 75 / 120 / 225 m), his words: "just make every city
the same size (adult kaiju city)"; "if our baby kaiju cant destroy the whole city, thats not a problem, thats a design
decision we can set different win conditions for Ostia other than 'level the city'"; "the grind is the game, the skill
tree matters more than anything our city/level structure is just to give more narrative structure and momentum". Q:
should the baby start in the full adult city, with all districts and 40 m towers? A: "Yes, full city". So every stage
runs the adult city (tuning.json city: half 225, coast 295 m north, towers to 40 m, tower chance 0.65, the adult
skyline cores); a stage keeps only its fog and haze (the camera still scales with the kaiju), army and air. Every
landmark spot stands from stage 1. Replaces D-039's growing city and D-254's per-stage widths; Ostia's own win
condition is to come.
Same day, Carthago's 13 deg spokes now cross the adult city's outer streets under the road rule's 20 deg; he picked
"Drop sharp street bits": spokes keep 13 deg and full length, a street piece a spoke crosses at under
city.diagonal_min_cross_deg (20) is left out and the blocks either side abut (CityLineFit.sharp_cells). Such a steep
spoke drifts too slowly for the line fit (3.5 m per 15 m block), so its crossing of a street beside a grid junction
is left out too (no "close" junctions). Roads suite on/off fixture: Carthago with 20 vs 0.
11-02, Q: every outer stand-in now lies past the 200 m roof-gear reach, so the far skyline shows no rooftop
tanks at any stage (as the Colossus skyline always did); raise the reach to 300 m or keep it? A: "Keep as Colossus".
The far-tank tally check retires; the playable roofs keep D-352's mix (city_roof_tanks).

## 2026-11-01 · D-435 · Director · Each demo map has its own layout and emerge: Ostia beach, Carthago harbour, Thule fjord
Overworld plan row C1. Tuning the grid per continent (two diagonals and a plaza for Carthago, longer blocks for Thule)
was built and shown at 1080p; his words: "they all look pretty much identical. the layouts should be completely
different. we will have to craft unique 'emerge' scenes for each map. only one map should have the water layout like
that". His picks: Ostia Minor keeps today's layout (sea and beach, harbour, river band, rises from the bay; D-381);
Carthago a circular harbour (a round naval harbour mid-city, streets radiating from it, the kaiju bursts up out of
it); Thule a fjord through ice (a narrow fjord cuts the city lengthways, the kaiju breaks up through its ice). Each
map is shown first as a 1080p top-down plan from the sim (streets, water, emerge point) for his yes, then built. He
added: "we will probably need to make more buildings and landmarks, we have tripo and meshy for that" (each spend
still needs his written yes and cap here; Meshy enters LICENSING_REGISTER before its first model). On the plans:
Carthago's harbour alone was "a random inner city lake": it "has to somehow be connected to the edge of the map". Of
one canal south, two (north-south) or four (a cross), he picked one canal south, 14 m wide, to the map's edge.

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
