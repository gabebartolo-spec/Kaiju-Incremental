# Interview audit (2026-10-26)

Director 2026-10-26: "there must be record of my interviews, find them, read them, then make sure EVERYTHING from the
interviews is reflected in the roadmap"; "ive been saying node ideas throughout our interviews" (D-272). Every interview
answer and director message in the Kaiju session transcripts, 2026-10-16 to 2026-10-26, was checked against ROADMAP.md,
every roadmap chapter, DECISIONS.md and its archive, and DESIGN.md by four readers. Leads add each new comment to a
chapter the same day; this chapter closes the backlog.

Checked: 782 items. decision only 294, in roadmap 372, missing 39, superseded 52, unsure 25.
Status: IN ROADMAP and SUPERSEDED items are not repeated here. Owner for every open row: lead (briefs it in queue order).

## 1. Node ideas for the upgrade trees (56)

Every node idea he has given, by species. The tree expansion (ROADMAP E, b2-28) builds these first; a node needing a
system that does not exist yet is written as data with its effect key and a roadmap row.

**Croc build list (the demo species; tree-expand builds these first, in this order):**
1. Frenzy: the stomp plays 20% slower; the node brings it back to 10% slower (D-264).
2. Tail whip: automatic, from a tree node (ch 2026-10-26 #6). The autonomous tail limb moved to the snake (D-202).
3. Eating heals, unlocked by a node (ch 2026-10-26 #7); Regeneration, a slow heal during a run (D-136, ch21 #77).
4. Thrown vehicles: Ricochet and Domino (ch 2026-10-26 #4).
5. Death blast, a 3-node branch: shards rain down at first; the nodes add a blast radius that collects biomass; shards
   smash what they land on; the top node is a ring round his body about one block wide (10-26 01:50-04:12, new here).
6. Rampage timer: 60 s growing to 3 min through timer nodes (ch 2026-10-26 #1).
7. Fire: the five headline nodes City Ablaze, Five-Alarm, Fire Front, Ember Rain, Firestorm (D-126).
8. Ultimate: a tree node with its own button (D-037, D-040); the croc's is the beam (D-203).
9. Sharpened Claws: the claw swipe (D-095).
Dragon/Komodo (paused): size lengthens the stride, speed unlocks a heavier gait (D-245); death roll with poison saliva,
the torrent, the charge (D-203). Snake: spiral up then squeeze, tail swats attackers, acid, rattle, constrictor traits
gated through the tree (D-203, D-206). Fire for species without breath: tree augments such as "searing venom" (D-115).

### Croc

| date | his words | topic | status | where |
|---|---|---|---|---|
| 10-17 13:36 | "increase the mobility of the tail, it reads as very rigid right now, I want it to be a powerful tail capable of crushing skyscrapers" | croc tail | in roadmap | DESIGN: tail "autonomous extra limb that shears buildings (a tree node, b2-2)"; ROADMAP A "b2-2 ... tail swipe"; D-223 for the mobility |
| 10-17 16:01 | Q: city-growth balance? A: "Apply D (Recommended)" (all costs x1.27, insectoid Leap Slam nerfed, reptile breath buffed) | pacing balance | superseded | D-049; pacing since reset by D-087, D-098, D-156 and later retunes |
| 10-18 00:37 | Q: merge #36 (army grows inside each stage; Regeneration later in the tree)? A: "Merge it (Recommended)" | army scaling, Regeneration node | decision only | D-069, D-069a, D-086 (built) |
| 10-19 16:49 | Q: baby and young croc balance? A: "A: steady upgrades (Recommended)" | upgrade cadence | in roadmap | D-098; playtest row 8 |
| 10-20 09:31 b15 | "tail sweep upgrade text says 'cutting a band of floors', dont use 'floors' like that" | upgrade copy | in roadmap | build2-playtest #15 |
| 10-20 09:31 b2 | "tail swipe doesnt seem to be occuring? it should be acting autonomously, like an extra limb, make it a part of the upgrade tree" | tail as autonomous limb node | in roadmap | build2-playtest #2; ROADMAP E (tail node, b2-2); DESIGN "tail autonomous extra limb" |
| 10-22 07:21 | Regeneration: a skill-tree node that slowly heals you during a run -> Keep | Regeneration node | in roadmap | ch21 #77; D-136 (healing is also a tree node in ch26 #7) |
| 10-25 16:53 | Q4 thrown-vehicle nodes: "Ricochet, Domino" | croc tree nodes | in roadmap | ch 2026-10-26 #4; ROADMAP D R 22.4 |
| 10-25 16:54 | Q6 claw rake: "Stays automatic"; Q7 tail whip: "Automatic, from a tree node" | claw, tail | in roadmap | ch 2026-10-26 #6 |
| 10-25 16:54 | Q8 eating heals: "A tree node unlocks it" | healing | in roadmap | ch 2026-10-26 #7 |
| 10-25 18:11 | Q: croc Frenzy node? A: "Frenzy becomes your speed-up" (stomp 20% slower, node returns it to 10% slower) | tree node | decision only | D-264 |
| 10-26 01:50 | rain down at first, add nodes to the skill tree which add a blast radius which collects biomass | Death-blast nodes | missing | no doc |
| 10-26 01:51 | Death-blast nodes: 3-node branch; shards smash what they land on | Death-blast branch shape | missing | no doc |
| 10-26 04:12 | How big at the top node? -> Smaller: a ring round his body (about one block) | Death-blast top-node size | missing | no doc |

### Dragon

| date | his words | topic | status | where |
|---|---|---|---|---|
| 10-23 16:13 | "some gameplay notes: different upgrade trees for each reptilian / Croc will still be our first titan / then dragon / then snake / dragon is our bulky brawler archetype, he has a death roll and poisonous saliva torrents / croc is our athletic fighter, can leap and crush, shoot lightning / snake shoots caustic acid, climbs and constricts, its tail acts as an autonomous limb in self defence" | reptilian trees and kits | decision only | D-202, D-203; DESIGN l.1801; ROADMAP has no kit/tree rows (only unlock order at l.519) |
| 10-23 16:16 | Dragon death roll: "option 1 AND poison saliva spirals out of his mouth as he rolls"; saliva "A torrent that leaves poison"; croc "Leap onto a building"; snake acid "Spat in arcing globs" | species moves | decision only | D-203; DESIGN l.1801 |
| 10-23 16:19 | "Leap replaces the dash"; ultimates "Croc beam, dragon torrent, snake acid rain"; dragon fast move "A charge" | leap, ultimates | in roadmap | leap: 10-25-unlanded-audit row "Leap replaces the dash" (D-259); ultimates and dragon charge: D-203 only |
| 10-25 07:03 | Q: size/speed upgrades vs walk pace. A: "Size lengthens stride; speed unlocks a heavier gait" | Komodo tree nodes | decision only | D-245 |

### Snake

| date | his words | topic | status | where |
|---|---|---|---|---|
| 10-21 10:21 | Q: what starts fires for species without a fire breath? A: "fire augmentation possible in the upgrade tree, i.e. insectoid 'searing venom' cephalopod 'flammable oil spray'" | species fire nodes | decision only | D-115 holds it; ROADMAP Fire only says "a spark source for non-breath species" as an open question |
| 10-23 14:28 | "Python from baby, i wanna be ambitious ... an actual serpent, meaning it needs to slither ... spiraling up towers and spitting acid, grabbing helicopters from the sky with its tail (the serpent will be our octopus stand in), constricting buildings and crushing them" | serpent kit | decision only | D-197, D-202, D-203; DESIGN l.1801; no ROADMAP row for the kit |
| 10-23 16:14 | Q: order means? A: "Unlock order (Recommended)"; demo "Yes, the croc"; croc tail node: "moves to the snake. but the crocs tail whip still in the game" | unlock order, demo, tail node | decision only | D-202; ROADMAP l.519 has the order; the tail-node move (croc loses the autonomous-tail node, tail whip stays) is not in ROADMAP/b2-2 row |
| 10-23 16:18 | Snake "Spiral up, then squeeze"; tail "Swats attackers on its own"; unlock "Finishing a city"; trees "Fully separate" | snake kit, unlocks | decision only | D-203; DESIGN l.1801 |
| 10-23 16:26 | "i want the snake to be a hybrid. starts off as a viper but can develop constrictor python traits in its skill tree" | serpent progression | superseded | by his own correction at 16:29 (cobra, rattle, constrictor) |
| 10-23 16:29 | "i meant cobra ... starts as a spitting cobra, as the skill tree develops and it grows into adolescence you unlock the rattle, which gives off a discombobulating vibration which bursts people who hear it and causes rumble damage to nearby buildings, when it reaches adulthood it grows more powerful and gains constrictor powers, all these are gated by the unlock tree and evolution" | serpent tree | decision only | D-206; ROADMAP l.528 cites "three serpent stages, D-206" but not the rattle burst/rumble or the gating |
| 10-23 16:29 | Python traits: "Constrict and crush buildings", "Tail grabs helicopters"; body "Yes, it morphs"; mix: "viper, python and cobra gated through the tree" | serpent traits | decision only | D-206 |
| 10-23 16:40 | "with our beautiful new models and animation abilities, i expect the sideways motion and predator feel to be exceptional and our carve destruction must still work / any contact a kaiju has with a building will damage it, only the serpent can hold down a button which instead lets you climb freely up buildings" | turning feel; contact damage; serpent climb button | in roadmap | ROADMAP l.531-533 (D-208) |

### Any species / tree-wide

| date | his words | topic | status | where |
|---|---|---|---|---|
| 10-16 12:21 | Q: insectoid hover? A: "Hold jump to glide (Recommended)" | insectoid glide | decision only | D-037 (insect now stretch goal) |
| 10-16 12:21 | Q: how do ultimates relate to signature attacks? A: "part of the upgrade tree, you forgetting this is an incremental, not a kaiju simulator" | ultimates are tree nodes | decision only | D-037, D-040; ROADMAP E tree rows carry the ultimate nodes |
| 10-16 13:10 | Q: ultimates own button or replace signature? A: "Own button (Recommended)" | ultimate button | decision only | D-040; DESIGN controls (built) |
| 10-17 16:55 | Q: scripted player reaches first evolution in 35 min; keep D? A: "Keep as is (Recommended)" | balance keep | superseded | D-049; D-087 first evolution at ~15 min |
| 10-17 17:13 | Q: growth screen title after EVOLVE: Behemoth? A: "BEHEMOTH (Recommended)" | evolution reveal title | decision only | D-051 (built) |
| 10-17 18:07 | "i dont like the concept of 'rubble' as currency" | currency | decision only | D-056 BIOMASS; DESIGN loop (built) |
| 10-18 00:43 | Q: upgrade tree stats panel shows 12 raw numbers; trim? A: "Trim to what changes (Recommended)" | tree stats panel | decision only | D-077 (built); ROADMAP F tooltip rows (b2-23) |
| 10-18 00:52 | Q: scripted player dies 28 of 31 early runs; too punishing? A: "Soften the young stage (Recommended)" | early difficulty | decision only | D-069a (built) |
| 10-18 07:17 | Q: how long should the baby stage last? A: "About 15 min (Recommended)" | first evolution timing | decision only | D-087 |
| 10-18 11:44 | "need a charge/dash" | playtest 4, dash | in roadmap | playtest row 4 (#90); DESIGN dash |
| 10-18 11:44 | "my first death only got me enough biomass for one upgrade ... my second death let be buy around 8 upgrades ... the cadence is wrong" | playtest 8, biomass cadence | in roadmap | playtest row 8 (young-retune, D-098 option A) |
| 10-18 11:54 | Q: stadium smash worth? A: "1.5x (Recommended)" | landmark bonus | decision only | D-090 (built) |
| 10-19 14:17 | Q: how should Claws earn its place? A: "Give Claws a new job" | Claws node | in roadmap | D-095; DESIGN claw swipe; ROADMAP D line 103 (b2-1 claw swipe) |
| 10-19 14:18 | Q: what should Sharpened Claws do? A: "Claw swipe (Recommended)" | Claws node | in roadmap | D-095 |
| 10-19 15:06 | Q: swipe vs toppling towers? A: "Swipes undermine towers (Recommended)" | Claws and towers | superseded | D-096; replaced by D-099 real physics (23:14 below) |
| 10-20 09:31 b16 | "repetitive text in the upgrades: 'moves faster... moves faster' ... less scientific, more humorous or referential, e.g. 'Long Stride > gotta go fast > Move faster'" | upgrade copy | in roadmap | build2-playtest #16 |
| 10-20 09:31 b17 | "'towers now fall to you' - this sentence makes no sense and is an over explain" | upgrade copy | in roadmap | build2-playtest #17 |
| 10-20 09:31 b23 | "when you highlight the ULTIMATE ATOMIC BEAM in the upgrade tree, the whole shape of the screen changes because the size of the tooltip is wider" | tree tooltip | in roadmap | build2-playtest #23 |
| 10-20 09:31 b24 | "copy issue: 'reptilian branch capstone', over explain, stop explaining every single thing in opaque language the player wont understand" | tree copy | in roadmap | build2-playtest #24 |
| 10-20 09:31 b27 | "what is the meaning of 'reptilian branch' on the upgrade tree? the entire upgrade tree is reptilian..." | tree branch naming | in roadmap | build2-playtest #27 (see D-197 three separate trees) |
| 10-20 09:31 b28 | "we need a lot more upgrade nodes, ideally double or even triple" | node count | in roadmap | build2-playtest #28 (ROADMAP E) |
| 10-20 15:16 | "research how to make the upgrade tree beautiful and with pathing unlocks which set the pace of the game ... maximise the feeling of constantly gaining power" | upgrade tree pacing | in roadmap | chapter 2026-10-21-director-comments #10; research/16-upgrade-tree.md; ROADMAP E |
| 10-21 00:07 | "im still interested in Fire as a source of lighting and gameplay (perhaps natural flame that can spread (unlockable in skill tree) and add to your biomass collection)" | fire spread node | in roadmap | ROADMAP Fire section (R 26); chapter 2026-10-21 #15; D-126 |
| 10-21 10:24 | Q: customisation? A: "skins and mutations as a stretch goal" | skins, mutations | in roadmap | D-119 (stretch); skins in ROADMAP achievements/skins (D-180); mutations: stretch only |
| 10-21 10:54 | Q: water city / octopus? A: "One of the 3, for all"; "Octopus fast, others normal"; "Speed plus submerge" | water city | in roadmap | D-123; chapter 2026-10-21 #35 (the two speed answers conflict; D-123 says others normal) |
| 10-21 12:06 | Q: fire unlock? A: "Tree node"; burn-out pays "A bit less, ~60%"; node names "yeah but less AI slop names, more kaiju themed" | fire nodes | in roadmap | D-126; ROADMAP Fire; chapter 2026-10-21 #42 |
| 10-21 12:07 | Q: fire node names? A: "Disaster headlines" (City Ablaze / Five-Alarm / Fire Front / Ember Rain / Firestorm) | fire node names | in roadmap | D-126; ROADMAP Fire ("five headline-named nodes") |
| 10-23 02:15 | Q: how to get a new head? A: "Unlocked with the Colossus (Recommended)" | head unlock | decision only | D-171 (superseded in part by D-197: head chosen at the baby stage); ROADMAP row says only "after the demo" |
| 10-23 16:41 | Sideways = "Turning and steering"; climb release "It stays coiled where it is"; climbing damage "None" | climb rules | decision only | D-208 gives the headline; release and no-damage detail not in ROADMAP |
| 10-25 16:53 | Q1 run length: "60 s up to 3 min" | rampage timer | in roadmap | ch 2026-10-26 #1 |

## 2. Missing from every doc (36), now roadmap items

| # | date | his words | topic | home | status |
|---|---|---|---|---|---|
| M1 | 10-21 05:03 | Q: run a headless check whether the tail passes through the bay bridge as he rises? A: "Yes, run it (Recommended)" | tail vs bridge check | A | open |
| M2 | 10-21 06:01 | Q: what should a clumsy-army miss look like? A: "Land beside him (Recommended)" | tank strays | D | open |
| M3 | 10-21 13:02 | "feel free to build some models for other UI elements like the numbers, or even menu buttons within the main menu, settings etc" | Tripo UI models | F | open |
| M4 | 10-22 07:49 | 18 old folders hold unsaved work: Back up, then remove (backup/<name> branches) | Backup branches then remove | Engineering upkeep (hygiene) | open |
| M5 | 10-22 13:56 | create a document, with visuals and interactive features that tracks the development of Kaiju Incremental from start to finish, basically a roadmap journal | Roadmap journal page | Engineering upkeep | open |
| M6 | 10-22 14:00 | Journal: Repo page regenerated; spine Roadmap phases; Highlights only; Captures per day + Progress charts | Journal spec | lead to place | open |
| M7 | 10-22 14:02 | Journal tracking: lead keeps a small table; page shows questions waiting; journal PR on claude/look-options; for you only | Journal tracking spec | lead to place | open |
| M8 | 10-23 14:35 / 14:36 | "are we using 3d enhance on tripo? should we try it?" / "i dont care what it costs, worth a try just to see" | Tripo 3D enhance | tools | open |
| M9 | 10-24 04:12 | "the snakes eyes being comic white dots is also very ugly" | serpent eyes | Reptilian models chapter, serpent redesign | open |
| M10 | 10-24 17:26 | "you did a pretty bad job overall, why not use tripo? can you connect directly to tripo with api" | Kaiju Creation props; Tripo API | Kaiju Creation chapter / tools | open |
| M11 | 10-25 02:09 | "remove the yellow bar at the top / make the 'new kaiju' button significantly smaller. / shift the settings button further into the corner" (02:30: "remove yellow bar at top") | title/menu UI | F (UI redesign) | open |
| M12 | 10-25 03:54 | "raindrops splash horizontally onto vertical surfaces which looks silly" | rain splash | atmosphere (D-191 weather) | open |
| M13 | 10-25 05:06 | "the tongue should begin from the back of his mouth toward his throat, and emerge from between his front teeth and lips, flick once naturally, then retreat back into his mouth" | Komodo tongue flick spec | D / Reptilian idle states (D-210) | open |
| M14 | 10-25 05:10 | Q: tongue colour? A: "A yellow-orange (Recommended)" | tongue colour | D / Reptilian idle states | open |
| M15 | 10-25 06:33 | "rain droplets are looking too big, the scale of the drops reads like a bucket of water hitting the ground. overall its a little too loud. i think a lighter misting effect upon impact would be more elegant" | rain look | atmosphere (D-191 weather) | open |
| M16 | 10-25 13:37 | "I also saw some weird spots where two roads met, like a seam between them rather than a seamless join" (road round 5) | road joins | B / Flat surfaces P0 | open |
| M17 | 10-25 18:08 | Q: stomp button? A: "Left click / F, pad X"; stomp clip "Good, merge it" | stomp binding | F (controls) | open |
| M18 | 10-26 00:29 | Lamp post and litter bin: 'Not all green' (black/dark steel); vending cart stainless steel + bright umbrella; power pole: Concrete or steel pole | Prop colour calls | Flat surfaces programme P3 props | open |
| M19 | 10-26 00:39 | Should a city ever have a six-way crossing? -> No, split them apart | No six-way junctions | lead to place | open |
| M20 | 10-26 01:19 | we should incorporate our threat meter into that destruction bar (A: the bar is the threat, five segments) | Threat bar = destruction bar | Interviews 2026-10-26 chapter row 10 | open |
| M21 | 10-26 01:49 | an elegant solution to the dying animation would to have them have a sort of self destruct, they could become overloaded with kaiju energy, crackling up, turning them to stone then exploding into shards (all kaiju; short agonised stagger; Special K violet crackle) | Energy-overload death | Interviews 2026-10-26 chapter row 32 | open |
| M22 | 10-26 02:17 | A narrower diagonal doesn't shrink the blocks -> Bigger blocks everywhere; and: Narrower diagonal (4 m) | Six-way fix | lead to place | open |
| M23 | 10-26 02:23 | Colossus flattens young city (retune: Yes); evolving destroys a Bigger share of the city | Balance bars on the bigger city | lead to place | open |
| M24 | 10-26 02:30 | Traffic islands: where the diagonal meets avenues (2-3 per city) | Traffic islands | lead to place | open |
| M25 | 10-26 04:21 | Yes, add the pre-push check and require it before any merge is armed | Pre-push check before merge | Engineering upkeep | open |
| M26 | 10-26 04:24 | Rail: A loop round the city; tunnel under river: Smash the portals | Rail loop and tunnel | lead to place | open |
| M27 | 10-26 04:36 | Elevated freeways: Part of the city, smashable (with cars that fall) | Freeways in the city | lead to place | open |
| M28 | 10-26 04:44 | When does the city change? -> Every rampage; every random city similar size (within ~10%) | New city each run, equal size | lead to place | open |
| M29 | 10-26 04:48 | Which real-world city model? -> Real-world rules, one city (river and harbour city playbook) | City-building playbook | lead to place | open |
| M30 | 10-26 04:57 | get 2 reasearchers going: 1 performance without compromising visual splendour AT ALL 2 look better without compromising performance; a third digests into 10-15 actionable things | Render research and plan | lead to place | open |
| M31 | 10-26 05:08 | we dont need 4 train stations in the young area, maybe just 1, and the train disappears into the locked areas, then teen area 2-3 stations, then 4-5 in the adult area | Stations per stage | lead to place | open |
| M32 | 10-26 06:05 | Performance items that change nothing on screen: Start now (overrides D-032 looks-first) | Perf before looks | lead to place | open |
| M33 | 10-26 06:17 | ok get started on THE RENDER PLAN (and: Render plan first for the next free slots) | The Render Plan | lead to place | open |
| M34 | 10-26 06:37 | Slower, harder stomp makes hatchling destroy ~15% more. Keep that? | Hatchling stomp strength | lead to place | open |
| M35 | 10-26 06:55 | i think the egg cracking should be more drawn out, a crack, a few moments pause before a couple more cracks, another pause, then ROARR | Intro egg cracking pace | lead to place | open |
| M36 | 10-26 06:57 | Delete the 10 replaced branches; land the Komodo clips; drop rubble smoke; key the croc breathing in Cascadeur; park Komodo mouth; redo claw hit effect; keep heli fall 2.2 s | Unmerged-branch rulings | ch 2026-10-25-unlanded-audit | open |

## 3. Decided but no roadmap row, work still open (165)

| # | date | his words | topic | decision | home | status |
|---|---|---|---|---|---|---|
| W1 | 10-16 01:46 | Q: which engine and platform? A: "Godot, PC + web (Recommended)" | engine, web export | D-002a; the web export itself has no roadmap row | Phase 2 / H | open |
| W2 | 10-16 09:09 | "our kaiju models look so good that they make the buildings look shitty can we up their fidelity at all" | building fidelity | D-028; now carried by Tripo district buildings D-256/D-257 (decision, ROADMAP has no district-building row) | H or new chapter "Tripo district buildings" | open |
| W3 | 10-16 09:11 | "could we have real cities with real layouts? i.e. use photos and google maps to route out exactly layouts ... imagine how fun it would be to destroy your own city" | real cities | D-029; DESIGN line 92 "tabled" | H (post-slice) | open |
| W4 | 10-16 09:14 | "we arent going to do this, we can just patch cities into the game whenever we want, we dont need players importing their own cities in" | no player-imported cities | D-029 (tabled); DESIGN 92 | H | open |
| W5 | 10-16 09:48 | "table the real city for work once your agent reaches a comfortable pause spot, focus on proofing the game" | tabling real cities | D-029 / DESIGN 92 | H | open |
| W6 | 10-17 16:35 | Q: which kaiju can the demo player choose? A: "Croc titan only (Recommended)" | demo scope | D-050; ROADMAP Phase 2 line 21 | Phase 2 | open |
| W7 | 10-17 18:02 | "night looks terrible, so white" | night lighting | D-057 (kept current); later comment 2026-10-20 #13 "night a bit lighter" in 2026-10-20-director-comments | B | open |
| W8 | 10-18 00:47 | Q: do jet strikes wreck buildings? A: "Yes, and it pays you nothing (Recommended)" | jet collateral | D-072; DESIGN 109 | H | open |
| W9 | 10-18 00:47 | Q: which stage brings jets? A: "Colossus, after the demo (Recommended)" | jet timing | D-072; ROADMAP 228 lists jets after the slice | H | open |
| W10 | 10-18 05:50 | Q: jet warning longer for bigger kaiju? A: "Warning scales with size (Recommended)" | jet warning | D-080; DESIGN 109 | H | open |
| W11 | 10-18 05:57 | Q: #50 fails again: wait or ship tonight? A: "One more round, then ship (Recommended)" | #50 tank AI | D-082, D-088 (military AI follows in a later exe) | D | open |
| W12 | 10-18 05:57 | Q: what first after the demo playtest? A: "Fixes from your playtest (Recommended)" | post-demo order | D-083; ROADMAP Phase 2 "playtest fixes first" | Phase 2 | open |
| W13 | 10-18 12:39 | "the buildings shouldnt be too strong for our little kaiju, it should just take him longer ... hes more than capable of tearing the roots out and toppling the large buildings" | baby vs buildings | D-091 (the walk-in check, ROADMAP A mentions); #88/#89 | A / C | open |
| W14 | 10-21 05:15 | Q: kaiju rises under a street bridge, which fix? A: "Burst through (Recommended)" | bridge over the rise | DESIGN "he bursts up through [the deck] and breaks it"; no roadmap row or D-id found | A | open |
| W15 | 10-21 05:36 | Q: how big is the rise bay? A: "Fit the biggest possible" | bay size | DESIGN "the bay fits the stage's biggest possible body"; no D-id or roadmap row | A | open |
| W16 | 10-21 10:16 | Q: low-health heartbeat sound? A: "You make it in ElevenLabs" | heartbeat sound | D-116; ROADMAP has only the visual heartbeat (R 15.3), no sound row | F / sound | open |
| W17 | 10-21 10:16 | Q: fire wind? A: "Fixed per run (Recommended)" | fire wind | D-115; ROADMAP Fire still lists wind fixed/rotatable as an open question | E | open |
| W18 | 10-21 13:16 | Q: Tripo text-to-motion first? A: "Soldiers and crowd (Recommended)" | motion test | D-128 | animation | open |
| W19 | 10-22 05:17 | What should today's Tripo credits go on first? -> HUD icons first | Tripo spend order | D-127 / D-134 | Post-demo plan (Tripo spend) | open |
| W20 | 10-22 10:40 | dusk could be fine if you doctor the image a bit, remove the glare; Both, then pick (night and cooled dusk) | Title time of day | D-140 (build night and glare-free dusk, he picks) | Playtest milestones M1 (title) | open |
| W21 | 10-22 10:43 | Taskforce: kill agents by Topple their building; Black tactical, glowing gear; arrive Jetpack in from the edge; Squads of 3-4, up to ~12 | Taskforce look, arrival, squad size | D-139 (ROADMAP:308 has only the topple-the-perch half) | Post-demo plan 'Your adversaries' / M2 | open |
| W22 | 10-22 10:44 | ice crust on the legs, but that means that the grenades must always be launched at his legs. we cant have them hit his head but freeze the legs | Frost on the legs | D-139 | Post-demo plan 'Your adversaries' | open |
| W23 | 10-22 10:44 | Railgun: Beam line plus charge whine; agent kill: Bonus cash per agent; heli crash hurts kaiju: No, only the city | Railgun warning, bounty, heli wreck | D-139 / D-140 |  | open |
| W24 | 10-22 10:46 | Frost grenades launched at street level; graphics preview small live city scene; load art kaiju in most shots; loading screen tip -> No text, art only | Taskforce frost launch, load-screen rulings | D-139 / D-140 (ROADMAP #90/#92 rows lack 'no tip text', 'kaiju in most shots') |  | open |
| W25 | 10-22 10:47 | First demo item: Anti Kaiju Taskforce; heli deaths decided by How it was hit; textures: Building walls and roofs first; flying agents: Yes, a swipe can swat them | Build order, heli death rule, texture order | D-139 / D-140 |  | open |
| W26 | 10-22 10:48 | Taskforce: railgun About 8% of health; first appearance Headline plus jetpack trails; find agents: No markers | Railgun hit, arrival fanfare, markers | D-143 |  | open |
| W27 | 10-22 10:50 | Title fire: Fire from windows, thick smoke; water: Reflections shiver on footfall; title music: No music, only the city; wreck: starts a fire | Title fire/water/music; wreck fire | D-141 (also VFX_STYLE.md) |  | open |
| W28 | 10-22 10:51 | Taskforce: agent dies Falls flailing with the debris; swatted agent Spins into a building; load shots: Board of ~20 you pick 12; textures: 3 styles on one building | Taskforce deaths, load-art and texture boards | D-141 |  | open |
| W29 | 10-22 10:58 | Taskforce adult city: Gas soldiers lock powers while inside the cloud; they fight from 'all Taskforce agents can jump from building to building with their grappling hooks and jetpacks'; mech Knee-high; Blue target rings | Gas cloud, soldier mobility, mech size/telegraph | D-143 |  | open |
| W30 | 10-22 11:00 | Mech destroyed by Stomp, Claw swipe, Topple a building, Thunder beam; 3-4 mechs at a time; tanks+helis keep coming; Add Taskforce gunships | Mech counters, count, army stays, gunships | D-143 |  | open |
| W31 | 10-22 11:03 | think smarter, not harder, the tank doesnt need to avoid the breath, just let it die | Tanks in breath just die | D-144 |  | open |
| W32 | 10-22 11:32 | Does the demo include the adult city? -> Yes (all three cities); gas cloud: you can still dash, all 'physical' powers still work just not special powers; mech bombs hit kaiju and city; railgun tracks then locks | Demo scope, gas lock rule, mech bombs, railgun dodge | D-145 (ROADMAP Phase 2 line 'Demo (D-050)... hatchling to Behemoth' is stale) | Phase 2 Demo line + M3 | open |
| W33 | 10-22 11:35 | Frost: several grenades refresh not stack; dash shatters ice; gunships blue laser cannon strafes; squads arrive Faster as the city falls | Frost/gunship/squad pacing | D-145 |  | open |
| W34 | 10-22 11:36 | Gas: Only locks powers; mech Blows up damaging buildings; every railgun hit triggers colour fringe | Gas damage, mech death, fringe on railgun | D-145 |  | open |
| W35 | 10-22 11:38 | Low-health red pulse below 25%; title one fixed view; keep BREAKING ticker; helicopter crew parachutes: Yes, sometimes | Title/pulse/parachute rulings | D-145 (ROADMAP:328 has the pulse but no 25% or parachutes) |  | open |
| W36 | 10-22 11:38 | Demo length 90+ min; Thanks screen, stats, feedback link; pause-menu bug/feedback button; no save carryover | Demo length, end, feedback, saves | D-145; ROADMAP M3 mentions 'demo end screen and feedback button' only |  | open |
| W37 | 10-22 11:40 | Loading screens: thin hazard-stripe progress bar | Load progress bar | D-145 |  | open |
| W38 | 10-22 11:40 | Thunder Beam for now but thinking of a better name | Signature breath name | D-145 | Post-demo plan (naming) | open |
| W39 | 10-22 11:40 | no but he should roar more often, perhaps when he uses his ultimate power and/or a dash | More roars (no roar button) | D-145 | VFX/animation (roar triggers) | open |
| W40 | 10-22 11:43 | move our main menu buttons achored to left of screen, keep the most visually apealling scene elements to the right of screen (logo above buttons) | Title layout | D-145 / D-150 (his mockup: gear top-left, one row, 'Run for your life!?') | M1 title screen row | open |
| W41 | 10-22 11:46 | in the city menu scene, occasional explosions should reveal the sillhouette of the reptilian colossus obscured in the inferno (every 12-20 s, moves in step with footfalls) | Title Colossus reveals | D-145 (supersedes earlier silhouette removal) | M1 title screen row | open |
| W42 | 10-22 12:54 | the colossus silhouette could look a bit better though, more distinctive but less of a solid outline, give him red glowing eye (faintly) through the smog | Colossus silhouette + faint red eye | D-145 | M1 title screen row | open |
| W43 | 10-22 12:56 | the menu buttons still look flat and theyre crowding the scene too much still / heres my idea for button placement in the main menu | Menu buttons crowd + his mockup | D-145 (mockup layout) | M1 title screen row | open |
| W44 | 10-22 13:03 | On first launch no save: One wide 'New Kaiju' button | No-save title row | D-145 |  | open |
| W45 | 10-22 13:53 | Feedback link -> Itch page comments | Feedback link target | D-148 |  | open |
| W46 | 10-22 14:01 | Explosion fire built from the game's fire tongues; gas = soft tinted smoke; smoke lit from below everywhere; title windows orange | Effect family rulings | D-151 / VFX_STYLE.md |  | open |
| W47 | 10-22 14:03 | Menu column: Keep it high | Title column height | D-150 |  | open |
| W48 | 10-22 14:09 | Playtest builds to Desktop\Kaiju Builds; survey as a web page with fields; wait for all of M1; first playthrough about 2 hours max | Milestone logistics | D-152 (ROADMAP:331 says only 'fixed folder' and 'exhaustive survey') |  | open |
| W49 | 10-22 14:10 | Taskforce tuning: agents appear after a few minutes of rampage; frost half speed ~4 s; railgun every ~12 s; agent kill about a tank's worth | Taskforce numbers | D-152 |  | open |
| W50 | 10-22 14:12 | Mech: one stomp or swipe kills; gas ~8 s about one street wide; up to 2 gunships; no Taskforce in the baby city | Mech/gas/gunship numbers | D-152 |  | open |
| W51 | 10-22 14:12 | 12 VFX answers: cinematic fire; haze + orange sky escalate; dust wall may swallow camera 2-3 s; stomp ripples through blocks | Visual direction 1-4 | D-154 / VFX_STYLE.md |  | open |
| W52 | 10-22 14:14 | VFX answers 5-8: debris rains 2-4 s; rare slow-mo on huge moments; glittering glass; blackouts spread at night | Visual direction 5-8 | D-154 / VFX_STYLE.md. NOTE blackouts also in ROADMAP:336; ch26 #15 slow-mo only for landmark falls is a later narrowing |  | open |
| W53 | 10-22 14:18 | VFX answers 9-12: bloodless puff; crushed small pop for kills; charge-up crackle on spines/throat; Taskforce energy clean precise tech | Visual direction 9-12 | D-154 / VFX_STYLE.md |  | open |
| W54 | 10-22 14:19 | Thanks screen stats: buildings, people eaten/fled, military destroyed, time + biomass; Windows only; red pulse only | Thanks-screen content, platform | D-152 |  | open |
| W55 | 10-22 14:21 | Gamepad + keyboard; army keeps coming after; DEMO version label in corner; 10-20 testers | Pad, label, tester count | D-153 |  | open |
| W56 | 10-22 14:47 | Version tag 0.1 rising per milestone; End rampage asks 'Are you sure?' | Version tag, end confirm | D-155 |  | open |
| W57 | 10-22 14:55 | i think we should measure until the upgrade tree is fully unlocked (2 hours roughly) | Demo length = full tree | D-156 |  | open |
| W58 | 10-22 14:56 | After they unlock the final upgrade they can unlock an endless mode maybe, where the city regenerates slowly and enemies escalate; otherwise players can replay normal mode with their maxed out kaiju | Endless mode in the demo | D-156 / D-167 | M3 'demo end screen' row | open |
| W59 | 10-22 15:01 | Tank's missed shell counts: Yes, it all counts | Stray shells count | D-157 | Post-demo plan (army) | open |
| W60 | 10-22 15:06 | Colossus on title: Tilt camera up; 15:26 Bigger + lower tower | Title Colossus scale | D-158 |  | open |
| W61 | 10-22 15:57 | Taskforce arrival: After a few min there (play-time counter in the adolescent city) | Taskforce first arrival | D-160 | M2 row | open |
| W62 | 10-22 16:11 | Railgun hits the body's middle; only the dash saves you mid-smash or frozen; shot pierces buildings; armour softens it | Railgun rules | D-161 (ROADMAP:410 volleys only) | M2 row | open |
| W63 | 10-22 16:13 | Frost grenades: Moving dodges them | Frost dodge | D-161 |  | open |
| W64 | 10-23 01:52 | Q: claw swat on jetpack agents? A: "Rare lucky swat (Recommended)" | swat | D-166; no ROADMAP row | D | open |
| W65 | 10-23 01:53 | Q: Colossus 1.5x slower on tallest towers, keep? A: "Keep it (Recommended)" | tower toppling | D-166/D-167 era; no ROADMAP row | D | open |
| W66 | 10-23 01:53 | Q: baby never reaches "eerie quiet" in the wider city? A: "Leave it (Recommended)" | eerie quiet | D-166/D-167; no ROADMAP row | audio | open |
| W67 | 10-23 01:54 | Q: Endless mode regrowth speed? A: "About 5% a minute (Recommended)" | Endless mode | D-156 (endless), D-167; no ROADMAP row mentions Endless or regrowth | demo end | open |
| W68 | 10-23 01:54 | Q: clear and overcast two weathers? A: "Five, as built (Recommended)" | weather count | D-167, D-191; ROADMAP weather line lists "rain, fog, storm, overcast/clear" only | atmosphere | open |
| W69 | 10-23 01:56 | Q: set up a local ComfyUI? A: "Not now (Recommended)" | local AI | D-170 | tools | open |
| W70 | 10-23 02:37 | Q: breath aim: where? A: "Where he faces at the strike (Recommended)" | breath aim | D-175; ROADMAP l.408 has timings only | D | open |
| W71 | 10-23 02:37 | Q: Thunder Beam 4 s starts when? A: "When the jaws open (Recommended)" | beam timing | D-175; ROADMAP l.408 has timings only | D | open |
| W72 | 10-23 02:37 | Q: crouch delays the dash? A: "No, shown as he launches (Recommended)" | dash crouch | D-175 (dash then replaced by leap D-259) | D | open |
| W73 | 10-23 04:50 | Q: skins board, which go forward? A: "they all need work. the colouring is just way too much, they read as 'black' 'white' 'green', rather than a cohesive new skin range" | skins | D-180; ROADMAP l.402 says skins board waits for him but not the "cohesive range" note | VFX | open |
| W74 | 10-23 04:50 | Q: skin recolours eye glow? A: "Yes, per skin (Recommended)" | skin eye glow | D-180; no ROADMAP row | VFX | open |
| W75 | 10-23 09:02 | Q: Endless-mode music? A: "Colossus track, fully built (Recommended)"; run end: "Fade under the results (Recommended)" | Endless and end-of-run music | D-189; DESIGN audio line; no ROADMAP row | sound | open |
| W76 | 10-23 12:11 | Q: which animation tool? A: "cascadeur looks like it has a 14 day free trial can you investigate that" | Cascadeur trial | D-194 (trial, nothing ships), D-195; ROADMAP l.430-433 names "a commercial animation tool" | animation | open |
| W77 | 10-23 12:35 | "A new model would come from Tripo, so if it comes to that, I'll ask you about the credits first. you have my consent ... have a helper research Cascadeur / how to operate it with AI" | Cascadeur research, Tripo consent | D-194/D-196 | animation | open |
| W78 | 10-23 12:53 / 12:54 | Q: Cascadeur physics needs a click; A: "Keep Cascadeur, you click" | Cascadeur click | D-195 | animation | open |
| W79 | 10-23 13:04 | "Yes, fix the game's croc leg rig as part of bringing the Cascadeur walk into the game." | croc leg rig | D-196 (archive); no ROADMAP row | animation | open |
| W80 | 10-23 15:05 | Q: serpent S-curve? A: "Wide, ~6 m each side"; corner "About 1.5 s"; sidewind "Yes, as its dash"; prototype "Yes, now" | serpent slither | D-198; ROADMAP has only "coil on stop" (l.540) | species | open |
| W81 | 10-23 15:38 | Q: Komodo beam sweep? A: "Head aims, body follows (Recommended)" | beam sweep | D-200 | D | open |
| W82 | 10-23 15:56 | Q: movement limited to animations? A: "Yes, animations lead (Recommended)" | animation-led movement | D-201 | animation | open |
| W83 | 10-23 16:23 | "budget is extended 5000" (Tripo) | Tripo spend | D-204, D-213 | tools | open |
| W84 | 10-23 18:45 / 18:47 / 18:48 | "what about the bridge?"; "but the animations look so much better in Casc"; Q: who maps Quick Rig? A: "You drive it on my screen" | Cascadeur rig setup | D-2xx archive (Blender-for-teen offer, "what about the bridge?"); no ROADMAP row | animation | open |
| W85 | 10-24 03:20 | Q: mecha chimera look? A: "B Lab-white prototype" | mecha look | D-217; remade D-227, D-230 (ROADMAP 262, 544 still describe the older boss) | H (mecha boss) | open |
| W86 | 10-24 03:20 | Q: back plates for the adult croc? A: "I REALLY hate our croc, why is he so fat and bulky, hes meant to be sleek and athletic>?" | adult croc build | D-219, D-221; DESIGN croc (athletic); ROADMAP 529 only says "croc adult concept" | D / Reptilian models chapter | open |
| W87 | 10-24 03:21 | Q: how to remake the adult croc? A: "Teen's build, grown up (Recommended)" | adult croc remake | D-219 | Reptilian models chapter | open |
| W88 | 10-24 03:24 | Q: which Komodo skins? A: "C Melanistic Black,D Bone White"; "pursue only the blue one" | Komodo skins | D-220, D-221 (blue dropped) | Reptilian models chapter | open |
| W89 | 10-24 04:09 | Q: soft or sharp shadows? A: "no screenshots for me to compare" | shadows | D-221 (stay as today); no roadmap row re-asks with a proper comparison | B | open |
| W90 | 10-24 05:00 | Q: which tail? A: "all tails shouldnt be stiff, they are like an extra limb and should have their own behaviours as well as physics" | tails as limbs | D-223; ROADMAP D only has counter-swing and kick (R 14.3, R 11.3, line 137-141) | D / Motion first | open |
| W91 | 10-24 05:01 | Q: tail behaviours? A: "Balance swing,Mood signals,Attack wind-up,Ground contact" | tail behaviours (all four) | D-223; only balance swing is in ROADMAP (R 14.3); mood signals, attack wind-up and ground contact bumping cars have no row | D / Motion first | open |
| W92 | 10-24 06:20 | Q: which skins go in? A: "All three new (Recommended)" | Croc pale banded, serpent copper, albino | D-224; ROADMAP 325 skin picker, 2026-10-21 comments #95 | H skins | open |
| W93 | 10-24 14:13 | Q: which model is the white mecha-cobra reference for? A: "Mecha boss (Recommended)" | mecha boss remake | D-227, D-230; ROADMAP 262, 544 predate it | H (mecha boss) | open |
| W94 | 10-24 14:15 | Q: robot colour? A: "White with blue lights (Recommended)" | mecha colour | D-227 | H | open |
| W95 | 10-24 14:17 | Q: parts the Komodo rig lacks? A: "Body in Cascadeur (Recommended)" (tail, jaw, tongue in Blender) | Komodo animation split | D-228; ROADMAP 802, 822 cite it | animation audit | open |
| W96 | 10-24 15:19 | Q: is this the mecha boss you want? A: "Yes, rig it (Recommended)" | mecha boss rig | D-230; ROADMAP has no rig/animate row for the remade boss | H (mecha boss) | open |
| W97 | 10-24 15:27 | "looks ok but he jolts too much upon footfall, almost like he doesnt know how long his own legs are or something. doesnt read as natural predator" | footfall jolt | D-231 (cause: rig) | animation audit | open |
| W98 | 10-24 15:28 | "the way his torso sometimes contorts during a walking animation makes it seem like he has no ribcage or internal mass at all" | torso contortion | D-231 | animation audit | open |
| W99 | 10-24 15:29 | "see how the width of his waist changes so dramatically from one moment to the next as his leg moves forward" | waist width | D-231 | animation audit | open |
| W100 | 10-24 15:30 | "seems like we should be doing better skeletons and better rigging before we get to the animation" | rig first | D-231; ROADMAP animation audit mentions rigs but no "rig check before animation" row | animation audit | open |
| W101 | 10-24 15:31 | Q: every model passes a rig check before any animation? A: "Yes, rig first (Recommended)" | rig-first gate | D-231 | animation audit | open |
| W102 | 10-25 02:01 | "move the UI element so it isnt overlapping the art / fix the two abberate blotches in the petrie dish" | Kaiju Creation lab UI + dish | D-241 (shipped PR #192); ROADMAP Kaiju Creation row still says "not started" | Kaiju Creation section (update status) | open |
| W103 | 10-25 02:02 | "why is the petrie dish so patchy, it looks speckled" (02:10: "speckles") | dish look | D-241 | Kaiju Creation section | open |
| W104 | 10-25 02:07 | "call Kaiju Juice 'Special K'" | naming | D-236 (button reads INJECT SPECIAL K) | Kaiju Creation section | open |
| W105 | 10-25 02:37 | "we need nice, clinical sfx for this scene, lab sounds and high-tech precision machinery whirring" | Kaiju Creation SFX | D-237 (ten ElevenLabs SFX, 500 credits) | Kaiju Creation section | open |
| W106 | 10-25 02:41 | "scene set; click genome (injector rotates to the croc vial, drains it, moves to dish and puts croc gene into dish); click kaiju juice (injector ... repeats); i do NOT want the vials magically flying over to the dish and pouring" | Kaiju Creation choreography | D-236 | Kaiju Creation section | open |
| W107 | 10-25 02:42 | Q: injector? A: "Use image A whole"; Q: Special K vial? A: "Own canister on the bench" (Tripo ~55 cr); Q: dish? A: "Glass dish in the cradle" | lab props | D-236 | Kaiju Creation section | open |
| W108 | 10-25 04:43 | "looks great. change the black interior to a laboratory setting and its ready to ship" | Kaiju Creation room | D-241 | Kaiju Creation section | open |
| W109 | 10-25 04:44 | "also load the serpent and dragon serum into the vials, and ensure the clip is functional for all 3" | Kaiju Creation 3 serums | D-241 | Kaiju Creation section | open |
| W110 | 10-25 05:02 | "can you make the dish metal a little less blocky, less speckled, more smooth" (05:04: "change the dish to be a more clear glass, less brown dirt") | dish look | D-241 | Kaiju Creation section | open |
| W111 | 10-25 06:13 | "the drool is a non-negotiable aspect of the Dragon's design" | Komodo drool | D-239 (ROADMAP line on Komodo saliva drip is the older #: "id really like the komodo's saliva to drip") | D / Komodo para | open |
| W112 | 10-25 06:23 | Q: add dark mouth lining? A: "Add dark lining"; 06:29 "what is the maroonish colour inside his mouth as his jaws open? we should be able to see the air between his jawws" | mouth interior | D-243 (gape 35-40 deg, clear air); D-245 (real mouths) | D | open |
| W113 | 10-25 06:35 | Q: governor headline copy? A: "Punchier / mocking"; heli: "Same size, lit"; young croc arms: "Small swing"; intro skip: "1 s" | VIP + croc walk + intro | D-242 (ROADMAP intro text still says 1.5 s cut, R 20.4) | D / VIP section | open |
| W114 | 10-25 06:36 | Q: mocking headline pair? A: "COWARD / SWATTED" | VIP headlines | D-242 | Leader's escape heli section | open |
| W115 | 10-25 06:39 | Q: timing at kaiju scale "Slowed for mass"; night "Dark and moody"; critic vs approval "You win, critic notes" | look bar | D-242 | B | open |
| W116 | 10-25 06:43 | Q: trains near kaiju "Keep running"; derail pay "Big one-off bonus"; line "Elevated viaduct"; next playtest "After the flat-surface pass" | trains | D-243 (ROADMAP only has "trains derail and smash" in atmosphere text) | H / Atmosphere and city life | open |
| W117 | 10-25 06:44 | Q: roar jaws "35-40 deg"; claw rake "Faint, short trail"; VIP headline "3 s, play continues"; passengers "Yes, after a derail" | roar, rake, VIP, trains | D-243 | D | open |
| W118 | 10-25 06:45 | Q: trains API cap $60: "Yes"; young croc head bob: "Yes, slight bob"; survey: "4K TV only" | spend, walk, survey | D-243 | D | open |
| W119 | 10-25 06:47 | Q: governor escapes headline? A: "COWARD ... ESCAPES (Recommended)" | VIP headline | D-244 | Leader's escape heli section | open |
| W120 | 10-25 06:50 | Q: water affects play? A: "Looks only"; bay: "Gentle swell, whitecaps in storms"; 06:52 review "After each step" | water rules | D-245 | Phase D water (R 21) | open |
| W121 | 10-25 06:55 | Q: collapse leaves? A: "Pancaked floors + debris"; height "Well below his knees"; "Crunches flatter"; built "Right after ground" | rubble design | D-245 (not itemised in ROADMAP) | C | open |
| W122 | 10-25 06:59 | Q: hits leave marks on kaiju? A: "Yes, faint wounds (Recommended)" | wounds | D-245 | D / VFX | open |
| W123 | 10-25 07:00 | "the inside of the crocs mouth is also featureless, just black voxels, we should give all our models the same detailed, functional mouths with real anatomic features" (Q: order "Croc first, then Komodo, then serpent"; gums, rooted teeth, wet lining + moving tongue + throat and palate; "Its own real animal") | all-kaiju mouths | D-245 (later reordered: Komodo mouth first, D-247) | D | open |
| W124 | 10-25 07:02 | Q: Komodo walks 2x too fast. A: "Slow him to the clip (Recommended)" | Komodo speed | D-245, D-201 | D | open |
| W125 | 10-25 13:06 | Q: finished Komodo work (walk, idle, run): park or land? A: "Land it too" | Komodo lands | D-251 (animation-audit #1 lists landing) | A | open |
| W126 | 10-25 14:18 | "id like to expand the play area for all 3 stages" (Q: "1.5x wider") | play area | D-254 | C/H city | open |
| W127 | 10-25 15:00 | Q: lift open-PR limit while landing backlog? A: "Lift to 8 for now" | PR cap | D-252; ROADMAP Engineering upkeep still says 3 open PRs | Engineering upkeep | open |
| W128 | 10-25 15:03 | "double check the skeletons of our models are optimised ... im only interested in our reptilian skeletons ... optimised for natural, smooth animation" | rig audit | D-252, D-231 | D | open |
| W129 | 10-25 15:14 | "if the premade clips are better, then we use them ... there may be premade mixamo animations ... or other free animations" (Q: "New voxel poses") | human clips | D-255 | D / animation-audit People | open |
| W130 | 10-25 15:32 | "dont forget we neeed traffic lights in the city, powerlines and stuff too, sewer manholes, bins in the street, graffiti on walls, street lights, phone booths, food trucks, signs of life!" (Q: also hydrants, bus stops, benches, newsstands, bikes) | street life | D-255 | H city | open |
| W131 | 10-25 15:36 | "it would be cool if there could be a 'red lights district', a 'chinatown', and a docklands area ... a street crammed with bars and restaurants / a business district ... commercial areas with neon lights, big intersections like madison square with ... advertisements and sparkly things to destroy" | districts | D-255; ch 2026-10-26 #36 | H city | open |
| W132 | 10-25 15:37 | "can probably make the architecture as tripo models then voxelise it if that works?" (Q: districts "Grow by stage"; Tripo "Hero buildings, <=1500"; "Go to 40 filler") | district buildings | D-255, D-256 | H city | open |
| W133 | 10-25 15:39 | "id be happy for you to make like 30-40 buildings in tripo to act as filler buildings" | filler count | D-256 | H city | open |
| W134 | 10-25 16:03 | Q: HD Model for buildings? A: "Keep HD"; 16:06 "Yes, run the batch" (61 buildings) | Tripo buildings | D-257, D-256 | H city | open |
| W135 | 10-25 16:13 | Q: swap the new adult croc into the game? A: "Swap in the new adult" | adult croc model | D-257 | D | open |
| W136 | 10-25 16:45 | Q: review 62 buildings "One board per district"; skyscrapers "About 2x the croc"; "District palettes"; Chinatown signs "Real Chinese characters" | district look | D-257 | H city | open |
| W137 | 10-25 16:46 | Q: hero landmark pays? A: "Yes, a big bonus"; landmark bridge "Make a new one"; stomp "Its own button" | landmarks, bridge, stomp | D-257 (stomp button also ch 2026-10-26 #28) | H city / D | open |
| W138 | 10-25 16:48 | Q: civilians "Mixed panic"; hydrants "Puts out fires"; traffic "Yes, jams and pile-ups"; districts "Night only" | street life | D-258 ("Night only" then superseded by 17:06 "Random per run", D-260) | H city | open |
| W139 | 10-25 16:49 | Q: grapple "Buildings only"; swat agents "Yes, with a bonus"; hit agent "Gore splatter"; jetpack "Hover and fire" | Taskforce | D-258 (ROADMAP line 308 already says buildings only) | H Taskforce | open |
| W140 | 10-25 16:50 | Q: auto stomp? A: "Button replaces it"; demo scope "Baby to adult croc"; controls "Keyboard+mouse and gamepad"; demo end "[No preference]" | demo shell | D-258 | Playtest milestones M3 | open |
| W141 | 10-25 16:56 | Q14 earlier rampages leave scars? A: "Fresh city each run" | city memory | D-259 | H city | open |
| W142 | 10-25 17:10 | "Start with the croc kit: leap, charged stomp, snap bite, defeat collapse, then combo and timer." | build order | D-263 (chapter rows carry the items, not this order) | ch 2026-10-26 | open |
| W143 | 10-25 17:20 | "if we buy the license can we then use the clips we already have? and what happens if our subscription ends?" / "we still have more time on the trial why are you breaking my balls, continue" | Cascadeur licence | D-261 (trial clips DEV ONLY; Indie $144 before release; ROADMAP has no licence row) | A / licensing | open |
| W144 | 10-25 18:03 | Q: charged stomp "Rooted while charging"; snap bite "No, snaps mid-stride"; combo "Any kill or building break" | croc kit details | D-263 (rows #3, #8, #28 carry the features) | D | open |
| W145 | 10-25 18:05 | "wait no i want him to die" (time's up); Q: "Army's final strike"; "Yes, every death counts" | time's up | D-263 | D / F | open |
| W146 | 10-25 18:05 | Q: results "Headline per ending"; city order "Different per save"; red-light "Neon and signs only" | results, seeds, districts | D-263 | ch 2026-10-26 / H city | open |
| W147 | 10-25 18:10 | "im not sure, but it looks too fast, it makes it looks weightless rather than titanic" (stomp 20% slower; "Hold until slowed") | stomp speed | D-264 | D | open |
| W148 | 10-25 18:17 | "Prepare prototypes of animations": picked "Croc kit moves, Croc idle/walk/turn/roar redo"; 62 buildings "Yes, on by default"; "+2 builders tonight"; "Play area, then districts"; Q: End rampage kills him: "Yes, he dies" | overnight shift | D-265 |  | open |
| W149 | 10-25 18:19 | Q: Tripo street-life props credit budget? A: "Up to 1,500 credits" | props spend | D-266 | H city | open |
| W150 | 10-26 00:08 | How should the 16 grey street props get their colour? -> Recolour in Blender | Prop recolour | D-267 (Flat surfaces programme P3 props has no recolour row) | Flat surfaces programme P3 | open |
| W151 | 10-26 00:12 | Merge the slowed stomp into the game? -> Yes, merge it | Slowed stomp | D-264 / D-267 (PR #223) | Interviews 2026-10-26 chapter | open |
| W152 | 10-26 00:15 | Decision 5: four buildings too wide for a block -> Keep them shrunk | Wide towers shrunk | D-267 |  | open |
| W153 | 10-26 00:16 | he should carve right through what he hits in mid air and land with a smash (confirmed: Every leap) | Leap carves in flight | D-268 (ch26 #5 leap row lacks the carve) | Interviews 2026-10-26 chapter row 5 | open |
| W154 | 10-26 00:17 | Decision 7: play area 1.5x wider -> Same feel per street (density on built blocks only) | Density on wider city | D-267 / D-254 |  | open |
| W155 | 10-26 02:00 | not sure i like the flyscreen door effect for close buildings, id rather a solid bubble be around the camera (cut away cleanly) | Camera bubble | D-270 (partial: bubble target only) | Render plan / camera row | open |
| W156 | 10-26 04:43 | i want the city's layout to be "random", landmarks rotate in and out, positions change run to run / the river should be a different shape in each run / train stations in different places roughly / districts in different locations | Random city layout | D-261 + ch26 #36 (shuffled blocks on 2-3 street plans; river shape and station placement not named) | Interviews 2026-10-26 chapter row 36 | open |
| W157 | 10-26 06:14 | i dont care if the kaiju gets obscured by buildings, i just dont want buildings right in front of the camera | Camera cut-away rule | D-270 (quotes the rain-clip tower, not this line) | Render plan / camera row | open |
| W158 | 10-26 06:55 | the 'shoreline' wedge is also not working ... move it to the bay where a shoreline makes more natural sense ... deploy the kaiju from the bay rather than the river | Spawn from the bay | D-270 (sea bay; ROADMAP R 20/ch 10-25 still say river) | Run intro row (R 20) | open |
| W159 | 10-26 07:06 | so beachfront is officially our new district, we need bespoke buildings for it, get started on a tripo session (up to 1300 credits; towers, venues, beach structures, pier) | Beachfront district | D-269 | Districts (ch26 #36 area) | open |
| W160 | 10-26 08:41 | Sea bay: Crescent bay; Keyed rise out of the bay (Cascadeur) | Bay shape and keyed rise | D-270 |  | open |
| W161 | 10-26 08:41 | Rain round 1: Good, keep it | Rain | D-270 |  | open |
| W162 | 10-26 08:43 | Stadium and Ferris wheel: South, past the river; beach About half the edge | Stadium south, beach length | D-270 |  | open |
| W163 | 10-26 08:48 | Beachfront defects: Fix in Blender; stadium placement: havent we already agreed that this is random map seed reliant? | Beachfront fixes, seeded landmark placement | D-271 |  | open |
| W164 | 10-26 08:50 | so you can use Casc and blender now but no godot | Godot paused | D-272 |  | open |
| W165 | 10-26 08:52 | there must be record of my interviews, find them, read them, then make sure EVERYTHING from the interviews is reflected in the roadmap | Interview audit | D-272 |  | open |

## 4. Decided and already built, or a working rule (107)

Recorded for completeness; no work. Working rules live in the rulebook and CLAUDE.md.

- 10-16 01:43 founding premise: D-001; DESIGN "The game" (built)
- 10-16 01:46 session shape: D-003; DESIGN loop (built)
- 10-16 01:46 controls: D-004; DESIGN controls (built)
- 10-16 05:54 model source: D-012 (built; Tripo spend budgets D-204, D-213)
- 10-16 08:24 Tripo spend: D-016 (spent; later budgets D-204, D-213, D-266)
- 10-16 09:32 street layout: D-054 zebra only at one junction (built, #26)
- 10-16 12:18 octopus design: D-036 (octopus now stretch, D-212)
- 10-16 12:21 helicopters in army: D-037 (built; heli rework ROADMAP 489 / D-183)
- 10-16 12:44 octopus stage: D-033 (octopus stretch)
- 10-16 13:41 voxel vs smooth: D-041 (look test, C voxel cubes on skin); DESIGN 64
- 10-16 14:50 kaiju rendering: D-041 (built)
- 10-16 15:51 tool install: D-042 (tank modelled through it); standing note in RULEBOOK browser/tools
- 10-16 16:05 Blender window rule: focus-guard rule in RULEBOOK "Machine and screen"
- 10-16 16:06 Blender modelling: D-042
- 10-16 16:32 military vehicle size and colour: D-042; DESIGN 107 (built)
- 10-17 01:35 CI spend: D-043 (built)
- 10-17 03:22 reptile body: D-045
- 10-17 04:27 croc titan: D-046; DESIGN croc description
- 10-17 04:50 pause doomed work: RULEBOOK no-work-on-doomed-assets
- 10-17 10:15 croc arms: D-048 (short arms, built)
- 10-17 10:37 croc design: D-048 (built)
- 10-17 11:11 spine colour: D-048; DESIGN "charcoal spines" (built)
- 10-17 16:06 croc baby and teen: D-059, D-073 (built)
- 10-17 16:35 demo content: D-050, D-052, D-059 (built)
- 10-17 16:36 demo end card: D-050/D-055 (built)
- 10-17 17:19 demo SFX: D-052 (built)
- 10-17 17:19 worktree cap: D-053; tools/lint/worktrees.sh
- 10-17 17:25 croc stages: D-059 (built)
- 10-17 17:34 street look: D-054 (built)
- 10-17 17:34 evolution roar: D-055 (built)
- 10-17 18:11 lighting look: D-057; later D-104 Cinematic
- 10-17 18:13 UI fonts: D-058; DESIGN 140 (built)
- 10-17 18:35 menu sounds: D-064 (built)
- 10-17 18:41 greenery: D-065, D-075 (8%); DESIGN 75 (built)
- 10-17 18:46 army sounds: D-067 (built)
- 10-17 18:49 afk rule: RULEBOOK afk rule
- 10-18 00:39 sounds batch: D-070 (built)
- 10-18 00:39 audio mix: D-070 (built); ROADMAP audio buses (R 8.1)
- 10-18 00:41 croc stages, toddler pace: D-073, D-074 (built)
- 10-18 00:43 greenery share: D-075; DESIGN 75 (built)
- 10-18 00:43 rooftop density: D-076, D-076a (built)
- 10-18 00:43 helicopter threat: D-066 / D-066 follow-up (built)
- 10-18 00:47 octopus grabs jets: D-072 (octopus is stretch, D-212)
- 10-18 02:45 demo timing: D-082/D-084/D-088 (done; demo exe 1 shipped)
- 10-18 03:04 stadium matches: D-078; DESIGN 83 (built, #59)
- 10-18 03:05 sport choice per city: D-078 (random built); the deliberate-by-country part waits on real cities, no roadmap row
- 10-18 03:31 shell hit sound: D-079 (built)
- 10-18 11:19 demo stall: D-089 (built)
- 10-18 13:44 audio download: D-092 (done)
- 10-18 13:49 SFX generation: D-092 (done)
- 10-18 14:20 SFX take picks: D-092 (done; ingest in LICENSING_REGISTER)
- 10-19 14:11 local Godot rule: project CLAUDE.md "Machine and repo"; RULEBOOK
- 10-19 14:14 local Godot: D-095-era entry; CLAUDE.md
- 10-19 14:50 cleanup: ROADMAP 376 repo hygiene (done by lead)
- 10-19 16:25 explain terms: RULEBOOK "Explain an internal name in one plain sentence"
- 10-19 23:29 machine rule: project CLAUDE.md "Director away ... do whatever is fastest" (done)
- 10-20 01:51 carved slab colour: D-101 (8a8780, built in WP4), DESIGN "slabs colour 8a8780"; no roadmap row
- 10-20 09:36 team shape: not in the set; carried by the user rulebook (one Opus-low asset session)
- 10-21 05:09 / 05:10 doc consolidation: done: DESIGN.md header "the one design document"; process, no roadmap row
- 10-21 10:55 species order: D-124; ROADMAP carries no rule line
- 10-22 05:03 Model per task: RULEBOOK right-size-agents (not in decision log or roadmap)
- 10-22 12:53 Fire consistency: D-151 / VFX_STYLE.md / DESIGN.md:9
- 10-22 13:11 Visual pillars: DESIGN.md:9; VFX_STYLE.md:20; D-154
- 10-23 01:55 Tripo method: D-170 (rulebook: Tripo through the browser); no ROADMAP row
- 10-23 06:52 process: D-186 (rulebook Tests); not a roadmap item
- 10-23 17:13 Cascadeur licence: D-194/D-195 (rulebook: Cascadeur); no ROADMAP row
- 10-23 18:25 Tripo in Chrome: D-215 (rulebook allows Kaiju Tripo work in Chrome)
- 10-24 03:09 reference photo: RULEBOOK reference images rule
- 10-24 03:20 serpent size: D-218
- 10-24 03:23 rounds waste: RULEBOOK no-marginal-gains; D-188
- 10-24 03:26 afk, no marginal gains: RULEBOOK no-marginal-gains
- 10-24 04:09 haze: D-221 (no change); ROADMAP B haze thickens with stage R 2.5, line 446 "late-rampage haze unbuilt"
- 10-24 04:09 croc ridge: D-221
- 10-24 04:09 blue skin: D-221
- 10-24 04:32 teen Komodo walk: D-222 (built)
- 10-24 04:38 teen walk head: D-222
- 10-24 04:41 head recoil: D-222
- 10-24 04:59 teen walk: D-222
- 10-24 12:32 idle waiting: RULEBOOK work-while-waiting
- 10-24 12:42 browser clicking: RULEBOOK browser rule (built-in browser)
- 10-24 13:53 Komodo walk arms: D-226, D-229, D-233, D-234 (built, w29 approved D-251)
- 10-24 13:53 idle tail: D-225/D-226
- 10-24 14:14 mecha boss spend: D-227
- 10-24 14:19 self-serve references: RULEBOOK "Straight to him" / ask only what is his
- 10-24 14:33 Komodo arms: D-229, D-233
- 10-24 14:49 animation failures: D-231 rig first; D-188 change method
- 10-24 15:21 iteration waste: D-231, D-188; RULEBOOK no-marginal-gains
- 10-24 16:32 Nimbalyst developer: D-232
- 10-24 16:43 research when stuck: RULEBOOK "research how others solve it (web, docs, forums, repos)"
- 10-24 17:24 Komodo arms: D-233
- 10-24 17:26 Komodo arms: D-233, D-234
- 10-24 17:48 Komodo arms: D-234
- 10-24 17:50 Komodo arms: D-234
- 10-24 17:57 video reference: D-234 (reference sheet from the official Godzilla 2014 walk)
- 10-24 18:01 Komodo arms reference: D-234
- 10-24 18:19 Komodo arms: D-234
- 10-24 18:22 Komodo arms: D-234
- 10-24 18:35 Komodo arm pose: D-234 (w29 approved D-251)
- 10-25 02:51 reference downloads: RULEBOOK Machine and screen ("download without asking")
- 10-25 06:38 look bar: D-242; RULEBOOK look bar
- 10-25 12:05 no critics: D-249 (then D-250); RULEBOOK
- 10-25 12:21 context limits: D-248 (partly), RULEBOOK Context and handoff; ch 2026-10-25 #66
- 10-25 12:56 review method: D-250; RULEBOOK
- 10-25 13:33 team shape: D-252; RULEBOOK
- 10-25 13:46 model per task: D-252; RULEBOOK
- 10-25 14:19 landmarks and explosive sites: D-254 (ROADMAP landmark pool text D-133 has no spread rule)
- 10-25 17:04 river wading: D-260 (lead's call: can wade, no rule)

## 5. Unsure: process remarks or unclear rulings (25)

- 10-16 13:02 unspecified visual: "this looks bizarre" (image) (image only, no text; cannot tell what it referred to)
- 10-19 16:26 pacing bot validity: "are you sure our test player is playing it like a normal human would" (question implying the pacing bot must play like a human; ROADMAP only has the bot (line 163, 361, 488) and no row validating it against human play. Not sure it is a ruling)
- 10-20 04:39 lead working style: "its frustrating having to babysit you to make sure you're actually working. thats your job, do it properly" / "why are you working so slow, summon more helpers" (process, not a game item; no doc in the set carries it (user CLAUDE.md has "never idle"))
- 10-20 05:34 / 05:36 approvals, pace: "stop making me approve things. do it your self ffs" / "i dont care for your excuses. make it happen, now." (process complaint; not a roadmap item (rulebook/auto mode))
- 10-20 06:33 lead working style: "so much waiting around, get your hands dirty and get stuff moving" (process complaint, no roadmap item)
- 10-20 13:00-13:06 worker conduct: "if you have no task you should ask lead for one" / "you need to always ask him" (process; user CLAUDE.md carries "ask your boss for a task"; no roadmap item)
- 10-21 05:20 / 05:31 rule cleanup: "Yes, go ahead and trim the rulebook, global CLAUDE.md and the handoff hook output" / "Yes, make all four simplifications: merge the playbook into the lead skill, keep the rulebook as the only copy of (process rules for skills/rulebook, not game roadmap; no doc in the set carries them)
- 10-21 06:00 skill rule conflicts: Q: model views? "Six"; mixed art "Your call each time"; shared-data tests "Keep the exception"; critic words "SHIP / FIX / REJECT" (rulebook/skill rulings (rulebook now says six views; SHIP/FIX later changed by 10-26 straight-to-him), not roadmap work)
- 10-21 13:04 browser: "as a default always use your own browser" (rulebook rule (Machine and screen), not roadmap)
- 10-22 07:04 Plain-language reporting: also what is Stage 1 and Stage 4, dont use vague language (Communication rule; not roadmap work)
- 10-22 07:32 Never block on director: as i said, never leave something waiting on me, just ask me, i should NEVER be the bottleneck unless i say afk (RULEBOOK (questions-go-through-the-question-tool, afk rule); process not roadmap)
- 10-22 08:43 No archive / no 500k handoff: we dont do archiving anymore, we changed that last night. now we autocompact instead (RULEBOOK (Context and handoff); process not roadmap)
- 10-22 13:08 VFX lead role: need an opus builder in charge of VFX oversight ... builder, art critic, city destruction overseer, ability effect overseer, fire overseer. he should be your 2nd in command (RULEBOOK (Kaiju leads); team structure not roadmap)
- 10-22 14:51 Task list in every session: i want every session including you displaying a checklist that they MUST update regularly (RULEBOOK Working (update_plan))
- 10-23 03:46 pause: "no godot for 75min" (logistics, one-off pause (not a rule))
- 10-24 14:31 idle jaw morph: Q: adult Komodo idle OK? A: "his lower jaw morphs strangly right before the tongue comes out." (idle iterations continued to v43 (D-225, audit line 60); no row names the jaw morph or a pass bar for it)
- 10-25 06:28 claw swipe: "can you show me the baby animation from the front. colossus swipe looks great" (request + approval of the Colossus swipe; claw swipe is animation-audit #3 but "looks great" not recorded)
- 10-25 07:55 audio spend: "spend as much as u want / download them yourself" (train sound takes from ElevenLabs) (not in the decision log (D-243/D-247 hold only caps of 500 credits / $20 API); needs a written line)
- 10-25 13:13 upright posture (image from komodo-mouth worktree): "why is he standing upright? this is our t-rex/crocodile" (ROADMAP has "croc in a t-rex body"; rulebook says the Komodo is upright (D-196); unclear which model he saw)
- 10-26 01:16 Lab card centring: lab_card_k02.png text isnt centred (later: good) (Small art note; ch26 #34 covers the lab card; fix was accepted at 02:03)
- 10-26 01:27 Tripo Smart Mesh vs HD for buildings: told you we should have used the smart mesh... (Complaint after a Tripo performance finding; no explicit ruling. Ask: should future Tripo buildings use Smart Mesh?)
- 10-26 04:15 Clock/Colossus question rejected: i dont understand these questions. why would the colossus be in the young city? (Complaint; the 02:23 'Colossus flattens young city' premise was challenged and never re-ruled)
- 10-26 04:20 Red PR complaint: five red PRs. how has this become so frequent? you're meant to be vetting the merges to ensure clean github routines? (Process complaint; answered by the pre-push check below)
- 10-26 06:13 Open to a better bubble: we can always replace the camera bubble with a more elegant solution, if you have one (Permission only, no ruling)
- 10-26 06:41 Merge everything to main: you know i always want everything merged to main, right? (RULEBOOK 'BUILT MEANS IN THE GAME'; D-252 'merge everything')
