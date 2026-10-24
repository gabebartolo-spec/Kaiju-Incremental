# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. Only the merge role edits this file, from the "Board and log" section of merged PRs.

## 2026-10-25 · D-230 · Director · Mecha boss approved: cobra robot R2b; rig it in Cascadeur

Shown the seven-view board of the remade mecha boss (D-227; Tripo c8b72f25 multi-view Smart Mesh, tail root re-posed in Blender, file `cascadeur_bridge/mecha/remake/mecha_cobra_c8b72f25_tex_r2b.glb`/.fbx; 270 of 400 credits). Asked whether the tail showing between the legs from the front (like Godzilla's) is fine or should join higher up the back: "Yes, rig it". Next: rigged and animated in Cascadeur after the Komodo clips.

## 2026-10-25 · D-229 · Director · Komodo arms hang at his sides; clips made whole in Cascadeur

Arm pose, asked with the v15 and v16 walk frames: "Hang at his sides" (hands near the hips, a loose swing against the legs; not held out, not tucked). On v16: "idk these all look anatomically broken", so the arm rig is pose-tested on the grey mesh before any new clip. On the method: "last night you were nailing animations first try, today you failing 20x in a row", then "yeah, do it right". Every clip is made whole in Cascadeur (full body posed together, physics over the whole body); a fix re-poses the clip, never patches one part onto a finished clip. Critics judge the whole body at game speed first.

## 2026-10-25 · D-228 · Director · Animate in Cascadeur; tail, jaw and tongue keyed in Blender

He asked the animator: "didnt we already decide to do all animations in Casc?" (D-199, D-216; the Komodo idle had been keyed in Blender since idle v4), then "id like you to try to animate it all in Cascadeur". The Komodo rig has no Cascadeur points for the tail, jaw or tongue, so he chose: body in Cascadeur; tail, jaw and tongue in Blender. Blender also does the ID pass, renders and measurement.

## 2026-10-25 · D-227 · Director · Mecha boss remade: humanoid robot, cobra head, reptile tail, white with blue lights; Tripo spend up to 400

The director sent two of his own reference images for the mecha boss: "model it like this, a human, with a reptilian tail and cobra head, but its a robot". Answers: the images are his ("It's mine, upload it"); colour "White with blue lights" (lab-white armour, glowing blue hood slats; keeps look B, D-217); spend "Yes, up to 400" Tripo credits from the D-204/D-213 budget (reference, model tries, texture). Tripo makes the model only; rigging and every animation stay in Cascadeur, as for every titan. Replaces the D-217 look-B 3D model.

## 2026-10-25 · D-226 · Director · Komodo walk arms, idle tail, skins earned, roar and attacks next

Asked four questions with the adult Komodo walk clip (v10): walk: "the actual walking is fine, and the tail is fine. but his arms are jolting strangely in a robotic way" (only the arms are reworked); calm idle tail: "Slow gentle sway"; how players get the new skins (D-220/D-224): "Earned by playing" (as D-205; which milestone unlocks each is asked later); the animator's next work: "Komodo roar and attacks" (before the croc animations).

## 2026-10-25 · D-225 · Director · The Komodo adult idle is calm: slow breathing, an occasional tongue flick

Shown the adult Komodo idle (v26: breathing, head-up tasting with three tongue flicks, tail sway with a whip flick): "its so so so bad. why is his body convulsing like that. just have him breathing slowly with the occasional tongue flick". The idle is rebuilt calm: slow breaths, one tongue flick a loop, a slow gentle tail sway (D-223), nothing else moving. Critics judge the overall feel at game speed first.

## 2026-10-24 · D-224 · Director · Croc and serpent skins: Pale Banded croc, Copper and Albino serpent

Shown the croc and serpent skin palettes that passed two critic rounds (adult at game size; croc White and Black and serpent Black failed twice and were dropped): "All three new". The croc ships with today's olive plus Pale Banded; the serpent with today's olive plus Copper and Albino. Recoloured from CC-licensed photo regions (skins/*/SOURCES.txt); how a player gets a skin is not decided.

## 2026-10-24 · D-223 · Director · Tails are a living limb: behaviours plus physics

Asked "whats the plan for the tail": "all tails shouldnt be stiff, they are like an extra limb and should have their own behaviours as well as physics". Behaviours chosen (all four): a balance swing (side to side against the hips each step; leads into a turn, then drags and whips round after it); mood signals (lazy S-curls and tip flicks at rest, lifted and stiff when alert, lashing when angry before an attack or ultimate); attack wind-up (coils or cocks before a tail whip or swat, then snaps through with weight); ground contact (the heavy base drags and scrapes, the tip lifts, a small bounce off cars and buildings it passes over). Every titan's tail is an authored behaviour layer with physics follow-through on top, in every clip. Whether the tail's bumps damage what they touch is not decided (presentation only until asked).

## 2026-10-24 · D-222 · Director · Teen Komodo: steady head, smaller feet

Shown the teen Komodo walk (v11, physics tail, 60-frame cycle): "his head wobbles too much, makes him look like his neck is too floppy. I also think his feet are too large". The teen's head is held steady like a predator's (the neck absorbs the body bob) in every clip, and the teen's feet are scaled down (about 80%, lead's call) across its walk, idle and turn.

## 2026-10-24 · D-221 · Director · Sleek adult croc ridge kept; blue Komodo skin dropped

Shown the remade adult croc (D-219, adult3 a3174b0f): its medium ridge of pale plates and dark spikes, "Keep it". The Blue Monitor skin failed two rounds of Tripo text texturing (D-220): "Drop it"; the Komodo ships with Melanistic Black and Bone White. Haze and shadow boards did not show a difference he could see ("today and half haze look identical, bad screenshots", "no screenshots for me to compare"): both stay as today, no change.

## 2026-10-24 · D-220 · Director · Komodo skins: Melanistic Black and Bone White, plus Blue by a new method

Shown the four skins that passed (A Wild Olive, B Young Banded, C Melanistic Black, D Bone White) after he called eight rounds on the other two "what a waste": picks "C Melanistic Black, D Bone White". The two that never passed: "pursue only the blue one". Sand Monitor is dropped. Blue Monitor gets a new method, Tripo's own texturing from a text prompt (the CC BY-SA photo stays a critic reference only, never an input), not more recolour rounds; two failed rounds of it go back to him. The lead broke D-188 here (tweak rounds after two failures); the method change is now forced at round two.

## 2026-10-24 · D-219 · Director · The adult croc is remade sleek and athletic

Shown the adult croc's back-plate options, his words: "I REALLY hate our croc, why is he so fat and bulky, hes meant to be sleek and athletic>?". DESIGN agrees (the croc is "the athletic fighter", the Komodo the bulky brawler); the Tripo re-run adult (10148dd5) came out heavy (chest 0.43 of its length vs 0.27 before, the teen 0.24) and critics checked defects, not the build. Answer: "Teen's build, grown up": a new adult from a fresh turnaround, the teen's lean long-legged frame scaled up with a heavier jaw, thicker tail and the back plates, measured as slim as the teen before any critic (Tripo spend inside D-204/D-213). The plates choice (A tall / B medium / C flat tiles) is re-asked on the new body. Every critic brief for a titan model now checks the build against DESIGN's archetype words.

## 2026-10-24 · D-218 · Director · Serpent size stays; fix the hood seen from above

Shown the serpent at the game camera (A today, B thicker, C closer camera): "A Today". Then: "gotta fix the frill on the snakes neck though, looks terrible from above". The serpent keeps today's girth and the shared camera; its hood is reworked to read as a cobra hood from the game camera above.

## 2026-10-24 · D-217 · Director · Mecha chimera look: lab-white prototype

Shown four concept looks for the D-211 final boss (A military steel, B lab-white prototype, C battle-worn steel, D obsidian with a DNA core): "B Lab-white prototype". The 3D model is made from B (Tripo, inside D-204/D-213); full game only (D-212).

## 2026-10-24 · D-216 · Director · Cascadeur stays the animation tool

Offered animating the Komodo teen and baby in Blender (no per-model Quick Rig setup, Blender output ships free, unlike the Pro trial's under D-194). His words: "what about the bridge?", then "but the animations look so much better in Casc". Cascadeur stays the animation tool for every titan; Blender layering only for what Cascadeur cannot do (blend-shape breathing, the tongue). A new character's Quick Rig is first copied from the adult's through the script bridge; if that fails, the session maps it by driving Cascadeur's window with computer use ("You drive it on my screen"). The trial-licence limit (D-194) is unchanged: keepers need the paid licence before release ("Later").

## 2026-10-24 · D-215 · Director · Tripo sessions may use Claude in Chrome

Asked whether the serpent's Tripo session may use his Chrome (Claude in Chrome) to upload reference images, since the built-in browser cannot upload local files and the cobra hood and rattle had failed six rounds of word-only prompts. His answer: "Yes, for all Tripo work". Every Tripo session may use Claude in Chrome whenever it needs to (uploads included), in a new tab, never touching his other tabs; sign-ins stay his; Private on every generation. Amends the rulebook's built-in-browser default for Tripo work only.

## 2026-10-24 · D-214 · Director · A Cascadeur animation session

His words: "create another session to make animations in casc". Answer to what it animates first (all four, in this order): the Komodo idle redo (the dragon's D-210 idle: heavy steady breathing, tongue darting, drool, snorting steam) and sharper predator turns and steering (D-208); the Komodo baby and teen (rig, walk, idle, turn); Komodo attacks (the moves DESIGN.md names; any new move is asked first); the new croc stages as their models land. Still the Pro trial, test only (D-194): keepers are remade under a paid licence, and buying Indie stays "Later". Clips reach him only after the lead's motion critic passes them.

## 2026-10-24 · D-213 · Director · Spend: Tripo budget extended by another 5000 credits

His words: "can have another 5k if you need it". Extends D-204's 5000 to 10,000 credits in total for the reptilian models goal (D-209). Drawn only once the first 5000 is spent; the per-session caps set by the lead still apply inside it. Credits already sit on the paid plan, so this is permission to spend, not a purchase.

## 2026-10-24 · D-212 · Director · Scope: demo, full game, expansion

His words: "my vision for the game: demo: full croc gameplay minus the mecha boss fight / full game: all 3 reptilians and mecha boss / if the game is doing well and if i can be bothered we would do an expansion with a mammal, an avian, an aquatic". Answers: the mantis and the octopus stay stretch goals ("keep as stretch goals, this is all ideas for later"); building your own kaiju from preset configurations moves to the expansion ("Expansion"). Consistent with the demo scope (D-050, D-145, D-156: the croc, all three cities); the mecha chimera (D-211) is full game only.

## 2026-10-24 · D-211 · Director · Final boss: the mecha chimera

His words: "get working on a strange chimera hybrid of all three, in a mecha form as the final boss / it should posess battle abilities of all 3 reptiles, im thinking snake head, croc body and athleticism, dragon massive size and power and it shoots a tribeam of corrosive acid, lightning and poison out of its mouth". Answers: a full machine, a giant robot ("A full machine"); built by the military from DNA harvested from your rampages, the ultimate weapon made to kill you ("Built from your DNA"); faced in the "last city after 100% unlocking every upgrade for all reptilians" (not in the demo); concept art starts now as free image edits, no 3D credits until he picks a look ("Yes, concepts now"). Stretch goal, same day: "after you unlock 100% of the achievements you unlock a secret: you can play as the mecha kaiju". The game has no achievement list yet; it gets designed with him later.

## 2026-10-24 · D-210 · Director · The reptilians' idle states

His words: "idle states: snake curls up into a defensive position, tongue flicking dangerously / croc hunches guardedly, prepared to leap at anything nearby / the dragon breathes heavily and steadily, tongue darting, drool dripping, snorting steamy gusts from its nostrils". The Komodo's Cascadeur idle is redone to match; the serpent's stop settles into the defensive coil (slither builder); the croc's comes with its new model. His sound ideas the same day (roadmap) pair with these: the croc's clicking growl, the dragon's nostril snorts and tongue flicks, the serpent's hiss.

## 2026-10-24 · D-209 · Director · Goal: all nine reptilian models and their skin mockups, soon

His words: "ok bring me models to look at / i want to see all models soon: croc baby, croc teen, croc adult, dragon baby, dragon teen, dragon adult, serpent baby, serpent teen, serpent adult / and i want to see skin mockups for all of them / get working, set a plan in motion to complete that". Answers: a concept that passes its critic goes straight to 3D without his pick ("Straight to 3D"; amends D-204's pick-first rule; a disliked model wastes about 130 credits of the 5000); a second Tripo session runs so the croc and the serpent are built at the same time ("Yes, two in parallel"; amends the one-asset-session rule for this goal). Plan: tripo-komodo finishes the Komodo baby and makes the three new croc stages; tripo-serpent makes the three serpent stages (D-206); the lead recolours every textured model in Blender into about six palettes per titan, the same palette across baby, teen and adult (D-205), critic first, then boards to him. Tracked on the "Reptilian models" page and the ROADMAP.

## 2026-10-24 · D-208 · Director · Exceptional turning and predator feel; carving stays; contact always damages; the serpent's climb button

His words: "with our beautiful new models and animation abilities, i expect the sideways motion and predator feel to be exceptional / and our carve destruction must still work / any contact a kaiju has with a building will damage it, only the serpent can hold down a button which instead lets you climb freely up buildings". Asked what sideways motion means: "Turning and steering" (how each titan swings its body round when you change direction: weight shifting, tail counter-swinging, no spinning on the spot). While the climb button is held the building takes no damage ("None"); letting go leaves the serpent coiled where it is ("It stays coiled where it is"). Every new model and animation keeps the carve destruction working.

## 2026-10-24 · D-207 · Director · Kaiju Creation: the new-game opening, in the demo

His words: "Kaiju Creation (aka NEW GAME) / laboratory setting, zoomed in petrie dish / you select which reptile genome to place in the dish / then you inject the KAIJU juice into the dish and a brief animation vfx moment shows the kaiju genome taking over the reptilian genome / camera rapidly zooms in into a black screen (the sound of an egg cracking is heard) / the first baby run begins". Answers: the rack shows the croc genome with the Komodo and serpent genomes greyed and locked, and the scene replays to create each new titan when it unlocks ("Croc, others locked"); after the black screen the baby rises from the river as now ("Rises from the river"); built for the demo ("In the demo").

## 2026-10-24 · D-206 · Director · The serpent is a hybrid: spitting cobra, then rattle, then constrictor

His words: "i want the snake to be a hybrid. starts off as a viper but can develop constrictor python traits in its skill tree". Asked what the starting snake looks like: "i meant cobra, but new idea just struck me: starts as a spitting cobra, as the skill tree develops and it grows into adolescence you unlock the rattle, which gives off a discombobulating vibration which bursts people who hear it and causes rumble damage to nearby buildings, when it reaches adulthood it grows more powerful and gains constrictor powers. all these are gated by the unlock tree and evolution". The body visibly morphs as it gains the traits ("Yes, it morphs"). Python traits: constricting and crushing buildings, and the tail that grabs helicopters ("Constrict and crush buildings, Tail grabs helicopters"); climbing is not one of them. Mixing: "yes, viper, python and cobra gated through the tree". The adult, told to the Tripo session: "final stage is python body, venom spitting cobra head, viper rattle vibrating grabby tail". Replaces D-197's "Python from baby" and ends the python-versus-cobra concept pick.

## 2026-10-24 · D-205 · Director · Skins: three colour palettes for each reptilian titan

His words: "we also want skins for each reptilian, 3 different colour palletes to begin with for each titan". Answers: earned by playing ("Earned by playing": goals such as finishing a city with that titan, set by him later); look only, no stat change ("Look only"); the lead drafts about six palettes per titan from real animals as free image edits and he picks three ("I draft, you pick 3"); a skin carries through every growth stage, baby to Apex ("Yes, baby to Apex"). Komodo first (its model is approved); croc and serpent once he has picked their concepts.

## 2026-10-24 · D-204 · Director · Spend: Tripo budget extended to 5000 credits

His words: "budget is extended 5000", replacing D-196's 1000-credit cap (about 330 spent so far, balance 16,575). Read as 5000 in total for the Tripo session's approved work (Komodo young stages, the new croc, the serpent); each new 3D model still waits for his pick of the concept. Asked whether it is 5000 total or 5000 more and what it covers; he moved on without choosing, so the smaller reading holds until he says otherwise.

## 2026-10-24 · D-203 · Director · Interview: the three reptilians' kits, unlocks and trees

He asked: "interview me". Answers, each to a question with the game impact stated:
- Dragon death roll: "option 1 AND poison saliva spirals out of his mouth as he rolls": he clamps a building in his jaws and spins his whole body, wrenching it apart in one twist (tanks and helicopters in reach caught too), a button with a cooldown, his signature; venom sprays out in spirals as he rolls.
- Dragon saliva: "A torrent that leaves poison": a heavy gushing stream swept by steering; where it lands, poison pools slowly rot buildings and hurt the army over time.
- Dragon fast move: "A charge": head down, slow to start, unstoppable once going, bulldozes in a straight line, hard to turn.
- Croc: "Leap onto a building": a long leap that lands on a building and crushes it with a shockwave toppling neighbours; "Leap replaces the dash". Lightning breath as today; tail whip stays (D-202).
- Snake acid: "Spat in arcing globs", like a spitting cobra: aimed globs splash and melt buildings from the top down, with dripping, smoking holes (new melting VFX).
- Snake climb and constrict: "Spiral up, then squeeze": it coils up a tower; wrapped, it squeezes and the building cracks and collapses inward; from the top it can spit acid on the streets.
- Snake tail: "Swats attackers on its own": when a tank, helicopter or Taskforce agent hits it, the tail lashes at the attacker by itself and can snatch helicopters from the sky.
- Unlocks: "Finishing a city": destroying the first city with the croc unlocks the dragon; the next city unlocks the snake.
- Trees: "Fully separate": each reptilian has its own tree, powers and progress.
- Ultimates: "Croc beam, dragon torrent, snake acid rain": the croc's long sustained lightning beam; the dragon's unending poison torrent leaving a spreading toxic swamp; the snake rears up and sprays acid in a wide arc that rains down and melts whole blocks.

## 2026-10-24 · D-202 · Director · The three reptilians: their own trees, unlock order croc -> dragon -> snake, and their kits

His notes: "different upgrade trees for each reptilian. Croc will still be our first titan, then dragon, then snake. dragon is our bulky brawler archetype, he has a death roll and poisonous saliva torrents. croc is our athletic fighter, can leap and crush, shoot lightning from his mouth. snake shoots caustic acid (new vfx needed for melting buildings), climbs and constricts, its tail acts as an autonomous limb in self defence". Asked: the order is the "Unlock order" (a new save starts with the croc; the Komodo dragon unlocks next, then the serpent); the demo ships "the croc" (replaces D-197's "whichever looks best"); the croc's autonomous-tail node "moves to the snake. but the crocs tail whip still in the game". Details of each kit: the interview that followed (D-203).

## 2026-10-24 · D-201 · Director · The heavy Komodo moves only as fast as his animations show

Two motion-critic rounds on the Komodo test build failed on the game's procedural layer, not on the Cascadeur clips: the sim turns faster than any clip can show (a ~120 deg body swing in under 0.5 s when the beam fires) and the game's foot-locking re-plants both feet within a frame (a double thud). Asked: "Yes, animations lead". His turns, starts and stops are capped to what his clips show (a 90 deg turn takes about his turn clip's time); the game stops re-planting his feet on its own and lets the clips' steps land. He steers more heavily, as the lumbering colossus (D-197); the beam still sweeps fast with his head (D-200). Applies to the heavy class first; the croc and serpent get their own answer when their clips exist.

## 2026-10-24 · D-200 · Director · Beam sweep on the heavy Komodo: the head aims, the body follows

The Komodo test build's turn snap (motion critic: ~70-90 deg in 0.25 s) is the breath beam's sim turn rate (0.6 turns a second whatever the size; the gait follows at up to ~290 deg a second), not the turn clip. Asked how the heavy Komodo should sweep his beam: "Head aims, body follows": the beam keeps today's fast sweep (gameplay unchanged); the head and neck do the fast aiming, up to about 60 deg either side, while the body swings round after it at a heavy pace. Owner: lead (test branch claude/komodo-test, the presentation layer).

## 2026-10-24 · D-199 · Director · Adopt the Cascadeur pipeline: every kaiju gets its clips from it

Shown the Komodo in the game (test build claude/komodo-test dd5918ec: his Cascadeur walk, idle, roar and a keyed walking turn, played by the game's clip layer; game and side camera clips; motion critic SHIP as the prototype). Asked whether it beats today's croc walking enough to be how all kaiju move (the D-193 test): "Yes, adopt it". Every kaiju (Komodo, the new croc, the serpent's special moves) gets its clips from this pipeline. Next, the polish list: weight on each footfall (camera dip, dust, thud), a slower in-place turn, tail lag and arm swing in the clips, the roar's head and snout. Before anything from Cascadeur ships, a paid licence replaces the Pro trial (D-194; Indie, $144 a year, under $100k revenue): a spend for his written yes then.

## 2026-10-24 · D-198 · Director · Serpent slither: a wide S-curve, quick turns, sidewinding as its dash; prototype now

He: "the challenge will be making the snake slither in a satisfying way, research should be done". Research (scratchpad research_serpent_slither.md): a kinematic trail body (each segment follows the head's path, so it never slides or cuts corners) with the S-wave laid in by distance travelled, weight from the response (acceleration, turn limit, the head leading), helix climbing and constricting, no physics chain, no Cascadeur for a limbless body. Asked: sweep "Wide, ~6 m each side" (on a ~40 m body; the bends scrape street edges); a 90 deg turn "About 1.5 s"; sidewinding "Yes, as its dash"; the prototype "Yes, now": a stand-in segmented body slithering, turning and stopping at the game camera, one ~6 s clip, then climbing, constricting and the tail grab step by step.

## 2026-10-24 · D-197 · Director · The reptilian family: Komodo (heavy), croc (medium), serpent (light), picked from the baby stage

After the Komodo model ("i love this komodo model"): "i think we should make it a choice from the baby stage". Asked what it is: "its still considered a Reptilian. Reptilian: Croc (we will remake his body to be more horizontal, a trex/croc hybrid), Komodo dragon, Serpent. We keep octopus and insectoid as stretch goals; another stretch goal is to build your own kaiju from preset configurations." Each plays differently: "all differ and have different mobility; in simplified terms: dragon - heavy, croc - medium, serpent - light. Dragon is our lumbering collosus now. Our new croc will be athletic and aerodynamic, while still posessing incredible power. The serpent will be more of a specialist." Serpent: "i wanna be ambitious with this one, I want it to be an actual serpent, meaning it needs to slither, i can picture it spiraling up towers and spitting acid, grabbing helicopters from the sky with its tail (the serpent will be our octopus stand in), constricting buildings and crushing them". Demo: "it should just be 1 option in the demo, we pick whichever looks best later". Replaces D-171's heads unlocked with the Colossus (python and Komodo heads). Next: "Komodo baby and adolescent" (Tripo, about 130 credits each, inside D-196's 1000).

## 2026-10-24 · D-196 · Director · A full Komodo dragon kaiju from Tripo, upright, for the Cascadeur pipeline; up to 1000 credits

During the Cascadeur walk test (the croc's legs re-rigged to its mesh: forward knee, backward hock; "ok holy shit this is promising") he asked whether to make new models first. Recommended finishing the walk test on the current croc; he chose: "Make the Komodo dragon model now in tripo". Asked: "A full Komodo dragon kaiju" (head and body, not the croc body with the D-164 Komodo head), "Upright on two legs" like today's Behemoth, credits "Up to 1000" (stop and ask when spent). Made animation-ready for Cascadeur (rest pose with limbs clear of the body, a mouth that can open), Private, six-viewed, logged in docs/provenance/tripo.md. Also: "Yes, fix the game's croc leg rig as part of bringing the Cascadeur walk into the game".

## 2026-10-23 · D-195 · Director · Cascadeur stays; he clicks to apply AutoPhysics

Crux test (D-194): agents can switch Cascadeur's AutoPhysics on and run it by script (the croc's body moved up to 1.6 m from the keys, solve under 0.5 s), but applying the result always opens a "Which frames?" box (all frames, every frame keyed first, one frame at a time: each asked). Cascadeur's Python has no answer for it and Windows cannot reach its buttons. Offered: research other tools first, keep Cascadeur with his click, or ask Nekki. He chose "Keep Cascadeur, you click": "i can click ofc". Agents do everything else and tell him when a box is up; he clicks All Frames.

## 2026-10-23 · D-194 · Director · Cascadeur Pro 14-day trial to test the animation prototype; nothing from it ships

For the D-193 pipeline he asked about Cascadeur's 14-day trial; its licence forbids commercial use ("This licence type prohibits any Commercial Use", cascadeur.com/agreement, Pro Trial), so nothing made in it could ship. Offered Indie ($12 a month billed yearly, $144; commercial use while revenue is under $100k a year; FBX export; no retargeting): "ok lets try indie", then "no i will get the pro 14 day trial". He signs up and owns the account; Claude installs and drives it to test whether it can animate the croc. The trial forbids commercial use, so nothing made in it ships: any clip we keep is remade under a paid licence (Indie under $100k revenue a year, else Pro), which needs his yes then. No spend now. New croc models for Cascadeur, if ours do not suit it: "Im happy to let you make new models if these ones are not ideal for Cascadeur"; on Tripo credits: "you have my consent".

## 2026-10-23 · D-193 · Director · A new animation pipeline from a commercial animation tool; animation tuning stops

He: "Im sick of wasting time and usage on animation problems. It is sisyphus shit. We need a new pipeline. That UniMate one looked promising." UniMate's code is MIT, but its trained models are CC BY-NC 4.0 (non-commercial, which the licence rule bans) and its animal data has disputed origins. Asked how to get such animation legally: "Commercial tool only". Asked whether the kaiju should play finished moves from the tool (the clip moves him) or the game keep placing each foot: "seems like a huge decision that I am not equipped to make", so it is the lead's call: a prototype first, the Behemoth walking, turning and stomping with the tool's finished moves; it replaces today's foot placement only if it beats it, and he judges the feel at the playtest. Kaiju animation tuning (turns, breathing, the claw arm) parks until the pipeline is in; the D-192 turn branch parks unmerged.

## 2026-10-23 · D-192 · Director · The big forms keep the short-step turn (A); the 10 s shore bar stays

Asked with the A/B clip he wanted (D-187: "show me them both"). Both turn the same on screen and neither stops: the body keeps about walking pace while stepping round a planted foot, and A and B end about 1.4 u apart. He chose "A: short steps" (turn_slow 0.1), which passes every walk and turn check; B fails the motion gate (the Colossus turns about his middle). Asked whether the Behemoth may take 12 s instead of 10 s to flatten the first shore buildings after rising (one of three test maps): "what the hell, no? what are we doing here". The 10 s bar of D-131 stays, and the builder meets it without changing the turn. Never ask him to loosen a bar he set (rulebook).

## 2026-10-23 · D-191 · Director · Atmosphere: all five weathers, haze and sky that follow the ruin, gulls and pigeons, fleeing boats, the whale

Asked in the atmosphere lead's session (A1-A16), after it found that #167 built only the weather pick and nothing draws any weather. Weather (D-155): "All five" in M1 (clear, overcast, fog banks, rain, thunderstorm) at all four times of day. Rain: "Heavy, kaiju clear" (downpour streaks and splashes, thinned round the kaiju and the screen centre). Fog banks: "Low, he towers above" (fog rolls through the streets; buildings and his head and back rise out of it). A storm by day: "Yes, near dusk-dark" (lit windows, fires and breath glow). Storm lightning: "Same lightning, far off" (the croc's bolt look, thin and distant in the clouds). Wet streets: "Yes, a wet sheen" in rain and storms (roads darken and catch fire and lamp light; no screen-space reflections). Clouds: "Soft, like the smoke", shown to him as labelled stills before going further. Escalation (D-154): "How much is destroyed" drives it (haze and orange sky follow the share of the city ruined); by day "Yes, softer by day" (smoky amber-brown, the sun dims; full orange at dusk and night); blackouts "Dusk and night only"; against the weather "Ruin wins late" (the orange haze shows through any weather at the peak of the ruin). Sky and sea life: "Gulls and pigeons" (gulls over the water, pigeons off the roofs, both scatter at roars and tower falls); boats "Flee and rock" (they speed away when he is near; his wake rocks them and can tip one; spectacle only, no biomass, no game rule); the whale (D-168) surfaces and spouts "Two or three times" a run, far out; at a roar "Whale dives, boats flee" (a surfaced whale goes under with a tail slap, nearby boats scatter). Order: "Escalation first", then weather, then sky and sea life. Owner: atmosphere lead.

## 2026-10-23 · D-190 · Director · Fire is smooth realistic flames; a slow chest-and-neck breath; the claw swipe stays straight ahead

Asked in the VFX lead's session. Fire (the fire board of D-188's reassessment, blocky voxel flames against smooth ones): "Smooth flames": tall, tapering, realistic flame shapes on every fire, the one effect that is not blocky; the question flagged the style mix and he chose it (the one-style-per-frame rule allows a mix he approves). Breathing while he stands still (D-165): "Slow chest-and-neck heave": neck, shoulders and flanks rise clearly every 6-8 s, deep and slow, as the default idle (replaces the movement caps set after "way too much ... too fast"). Claw swipe seen from the camera behind him, where his body hides it: "Keep it straight ahead": the swipe stays on the snout line in front of him, its trail and sparks strengthened so it reads from behind; the side-hit idea is dropped. Owner: VFX lead.

## 2026-10-23 · D-189 · Director · Interview: atmosphere starts now in a third session; music opens low; helicopters never block the view; 6 builders

He said "interview me". M1 (D-146, D-155) waits for all its items and several had not started; asked when he plays it: "start them now, create a third session". Asked what it owns: "Atmosphere": a third lead session owns M1's atmosphere end to end (sky and sea life with clouds, birds, small boats and the whale, D-168; weather looks; the rampage escalation of D-154: haze, orange sky, spreading blackouts), with its own builders and critics; the VFX lead keeps fire, explosions and the kaiju's motion; the lead keeps the game rules, music and city sound and builds the layered music now. Builder cap: "6 in total": two engine builders per session (amends the "Fit the PC" cap of about 4); drop back if the CPU pins at 100%. Music (D-125): "Low and creeping": a rampage opens on low strings and bass only, drums join at the first big collapses, brass and the full theme at the peak of the ruin. Endless mode: "Colossus track, fully built" (the Colossus city's track, layering as usual). A rampage's end: "Fade under the results" (the layers drop away over about 2 s into the results screen, leaving the low strings; no new music). Helicopters (D-183's "They still keep off the camera's side"): "Never block your view": they may pass briefly on the camera side while repositioning, but never fly between the camera and the kaiju.

## 2026-10-23 · D-188 · Director · Visual reviews keep going until the critics pass; repeated failure changes the method

He asked "are we in clip making purgatory again?" (the fire and helicopter look at round 7, the new breathing failed its first review as invisible at the game camera, the walk fix failed twice on the swivel). Asked how visual reviews run until M1, he chose "Keep going until critics pass": no round cap; critics keep failing merely acceptable work, so the M1 build shows finished visuals. Then: "but if something has failed 7 times in a row then our method is wrong, and needs to be reassessed": two failed rounds in a row (CLAUDE.md rule 8) mean the owner stops, finds why each round failed and changes the approach before the next round. The fire and helicopter look is reassessed before any round 8. Not chosen: two rounds then M1; fewer clips with the same rounds.

## 2026-10-23 · D-187 · Director · The big forms turn heavier and slower

The walk fix failed its motion review on the swivel he named ("he swivels rather than turns"). Measured: the sim turns the Behemoth and Colossus at peaks of 260-311 degrees a second, each step's yaw squeezed into its planted window, so the body snaps round on planted feet; the snap also swings his position 8-13 units about the planted foot (the lunge that lets him catch helicopters). Asked: "Heavier, slower": turns grow slower with size, spread evenly over the steps. The lead first quoted today's U-turn as about 1.2 s and offered 1.5 s / 2.5 s; measured, today's is 0.95 / 1.63 / 1.80 s (young croc / Behemoth / Colossus), so it re-asked: "Behemoth 2 s, Colossus 3 s" (the motion critic's bar: at least 4 alternating real steps in a 180, each over 0.3 foot length and at most 40 degrees). The young croc keeps its smooth turn (D-131) and small corrections stay smooth (D-130); amends D-130's "the turn rates stay as they were" for the two big forms. The lead re-checks the 10 s rise-point bar (D-131); a clip comes before it merges. Not chosen: same speed without the snap; keep as is.

## 2026-10-23 · D-186 · Director · GitHub runs the long test suites

He asked: "is there a way we can get things done faster without compromising quality". The lead measured: builders ran hour-long local chains of up to 11 suites before pushing, while GitHub runs the whole suite in 4 parallel shards in about 15 minutes, free (the repo is public); the PC sat at 57% CPU with 6 engine jobs. Asked: "GitHub runs long suites": a builder runs on this PC only the one or two suites it is iterating on, then pushes and lets GitHub run every other touched suite and the full suite. Same tests and bars; amends D-159's "touched suites locally". Not chosen: a fifth builder (the cap stays about 4). The lead also starts every task on a fresh builder and writes the design and pass bars before code.

## 2026-10-23 · D-185 · Director · The claw swipe becomes a heavy raking arc

"the claw swipe animation for our kaiju looks really really odd, the way his arms dart out is reminiscent of a wind up toy or somebody doing the chicken dance, its laughable, not dangerous"; "his arms dart out upward diagonally very suddenly, defying his anatomy, it looks terrible". Asked: "Heavy raking arc": his shoulders and body twist into it, the arm loads back, then sweeps low and wide with the claws raking through and a heavy follow-through; a slower wind-up, a fast strike, like a bear's or Godzilla's swat, within a croc's forelimb range. The hit lands at the same moment the sim deals it (presentation only). Owner: the VFX lead, under the D-177 motion checks at all three growth steps.

## 2026-10-23 · D-184 · Director · The music ships: the 1954-Godzilla theme G1 on the menu and, re-arranged, in every city

After "now the songs are too whimsicial, almsot Harry Potteresque, go harder on the Godzillla reference", the lead made four takes in the style of the 1954 Godzilla score (G1, G2 a heavy march; G3, G4 "he appears", slow with silences). He: "ok the music is much better, ship it, but make a note in the roadmap to revisit music later". Asked: "download them all, but use G1 for the main menu"; the three cities get Suno Covers of G1 ("Cover it per city now", source "G1"), each a step heavier with the city (D-181, D-172). Then he made a Suno remaster of G2 (song 798f3c13): "use this one", asked: "Menu and cities": the remaster replaces G1 on the menu and as the Covers' source. Menu: the theme plays over the city sound ("Over the city sound"), which amends D-141's "no music, city sounds only" on the title. All four takes are downloaded as WAV; stems (Auto Split) only for the city tracks, which play in layers (D-125). A later music pass is on the ROADMAP. Takes, settings and credits: docs/provenance/music.md.

## 2026-10-23 · D-183 · Director · Helicopters fight as stand-off gunships, moving gracefully

"helicopters are hovering way too close to our kaiju, its completely unrealistic and looks odd how twitchy they are like an orbiting fly, they should move logically, strategically, gracefully". Cause (code): each helicopter's position was an offset pinned to the kaiju every step (snapping with his every move), a 14-unit circle diving to a fifth of that twice a lap, reversing at the ends of its arc. Asked: "Stand-off gunships": they hold firing positions well beyond his reach, glide between them with smooth banking turns (their own speed and turn limits, never pinned to him) and pull back when he advances; the breath, beam or a thrown tank reaches them, and an occasional strafing pass brings one within claw reach. They still keep off the camera's side. Motion first (D-177) applies.

## 2026-10-23 · D-182 · Director · Music references: Jaws, Godzilla, the Imperial March, Isengard; not modern "epic"

"the songs are sounding too 'epic', too Nolan Batman, should be more like Jaws or Godzilla or even Star Wars Imperial March sounding", and "peak reference": The Lord of the Rings, Isengard Theme (youtube.com/watch?v=KXVtpOHQqvY). The theme is a classic acoustic orchestra with a simple, menacing low motif and a march pulse (a stalking two-note figure, a villain's minor-key march, an anvil-struck five-beat war-machine rhythm), never modern hybrid trailer music (synths, braams, drones). References name qualities only; prompts never name or copy the works.

## 2026-10-23 · D-181 · Director · One menacing theme, re-arranged per city with Suno's Cover

"are you aware the suno tracks youre making all sound more or less the same city to city" (the lead's three prompts differed by a few words; Suno ignores that). Asked: "Same theme, new arrangement": one menacing theme heard in every city, re-arranged (baby city sparse and creeping, adolescent driving, adult full orchestra, dissonant and huge). "Cover from one take": he picks the take whose theme he likes; each city is a Suno Cover of it in its own arrangement, so the tune carries across. Then: "i need more menace": theme takes now ask for predatory, stalking horror (tritones, clusters, roaring low brass, heartbeat drums) and exclude warm, hopeful and pretty. Amends D-172's "one mood, growing" (now one theme, three arrangements).

## 2026-10-23 · D-180 · Director · Skins: a cohesive range, not big recolours; each skin sets his eye glow

On the r6 skins board (Obsidian, Abyssal, Albino): "they all need work. the colouring is just way too much, they read as 'black' 'white' 'green', rather than a cohesive new skin range". Skins become variations within the croc's own family, not full-body colour swaps; none goes forward as is. Asked: "Yes, per skin": each skin also recolours his eye glow (breath, charge and effects). After the demo (D-119); owner VFX lead, after motion work.

## 2026-10-23 · D-179 · Director · The balance run moves to GitHub's machines

Asked (the hour-long tools/pacing.gd run was killed twice today by his Godot pauses): "Yes, run it on GitHub": a manual GitHub workflow runs the pacing run and keeps its output, so balance answers no longer need his PC (D-159 "GitHub runs them"). Owner: lead.

## 2026-10-23 · D-178 · Director · A Taskforce squad locks on together and fires in turn

Asked (sim review of PR #170: as built each gunner locked on separately, so one dash dodged only one shot and a slowed croc took several hits per squad): "Lock together, fire in turn": a squad's aim lines lock at the same moment and its shots land 0.6 s apart, so one dash saves him from the whole squad, and standing still he takes at most about 2 hits a second from a squad (D-166, D-175 per squad).

## 2026-10-23 · D-177 · Director · Motion and destruction come first; a motion gate on every body or movement change

"motion, alongside the destruction mechanics, is the most important element of our design. If we cant sell the fantasy of piloting a Kaiju then the game wont be fun" (after the adolescent's twitchy walk). Asked: "Motion first": the gait fix lands now, then a motion pass on every growth step (walk, turn, stop, dash, stomp, standing still) with measured pass bars and a fresh motion critic at game speed; the living predator (D-165) moves ahead of the one-look work (the night-glow fix carries on). "Yes, always": any change to his body, speed, steps or animation passes foot, step and turn checks at all three growth steps before merging (a CI suite built from the gait probe). DESIGN Pillar updated.

## 2026-10-23 · D-176 · Director · Music: darker, not heavier, menacing like the classic Godzilla score

On the first brooding takes: "theyre all a bit too 'heroic', I want them to be darker (not heavier), more menacing, reminiscent of the Godzilla theme". The briefs now ask for a sinister slow march in the 1950s Japanese monster-film style (a repeating low ostinato, low piano and contrabass, timpani, dissonant low strings and brass), and exclude heroic, triumphant, uplifting, fanfare, major key and choir. The theme is described by its qualities, never named or copied. Cities grow in fullness, not heroics.

## 2026-10-23 · D-175 · Director · Damage on impact: per-squad volleys, the breath aims at the strike, the beam starts at the strike, the dash stays instant

Asked after the audit of pressed attacks (D-166). Volleys: "Per squad": at most about 2 railgun hits a second from each squad (0.6 s gap); several squads lined up can still land more. Breath: lands 0.8 / 1.1 / 1.4 s after the press (young / Behemoth / Colossus), "Where he faces at the strike". Thunder Beam: "When the jaws open": its full 4 s starts at the strike, 1.4 s after the press; he slows from the press. Dash: "No, shown as he launches": the crouch is view-only, the dash still moves on the press (it is the escape from a locked railgun, D-161). Standing stomp lands 0.45 s after its tick, with the foot.

## 2026-10-23 · D-174 · Director · Claude makes the Suno takes in the browser, up to 800 credits; he picks by ear

"surely you can operate suno in your browser the same way you use tripo". Asked: "Up to 800 credits" on his Suno Pro plan for the three city tracks (D-169, D-172 briefs), run by the lead in the built-in browser after he signs in; each run's cost read off the Create button, stop at 800. "You pick by ear": the lead sends each city's takes, he names the winner, and only that take is split (Auto Split) and downloaded. Every take, its credits and the pick go in docs/provenance/music.md.

## 2026-10-23 · D-173 · Director · A helicopter wreck also kills Taskforce agents perched on the roofs it smashes

Asked (PR #166: the crash reached only floors 0-2, and nothing reached perched agents): "Yes, them too". A wreck kills tanks, army squads and Taskforce jetpack agents on any building it smashes, whatever the floor, like toppling their roof (D-161, D-166 swat); still never the kaiju (D-140, D-167). Crash only: stomps and bites keep their current reach.

## 2026-10-23 · D-172 · Director · Music: brooding and building, one mood that grows heavier each city

His first Suno takes from the old briefs: "the songs are way too intense based on the prompts youve provided", and the guide "doesnt really seem to marry up to their interface". Asked: "Brooding, building": low and slow (deep drums, low strings, sub bass, sparse low brass), the city's sound in front, swelling only as the city falls. "One mood, growing": every city shares one sound, each a step heavier (same tempo and key), replacing the briefs' sly / industrial / epic moods. docs/audio/music-briefs.md rewritten to Suno's current Create form (Custom, v6, Instrumental, Styles, Advanced Options: Exclude, Weirdness, Style Influence; Auto Split stems; WAV download).

## 2026-10-23 · D-171 · Director · New heads come after the demo, unlocked with the Colossus

Asked (the VFX lead is fitting the Komodo head, D-164): "After the demo": the Komodo head (and later the python) stays out of the Itch demo; model and fitting work may go on, nothing head-related enters a demo build. "Unlocked with the Colossus": when he becomes the Colossus, the evolve screen offers the croc, Komodo or python head (a look only, D-166). Owners: VFX lead (head swap and re-fit), lead (evolve-screen picker), after the demo.

## 2026-10-23 · D-170 · Director · Tools and spend: a 100-credit rig test, Tripo in the browser only, no local AI yet, a second concept round

Asked at the interview (from the AI-3D pipeline research). Rig test: "Yes, up to 100": up to 100 Tripo credits, taken from what is left of D-162's 8000, to try Tripo's quadruped and "others" rig on the croc's tail; it does not change the croc's look. Tripo API from a script ($10 cap): "Browser only": Tripo stays in the built-in browser (rulebook unchanged). Local ComfyUI: "Not now"; revisit after the rig test. Next concepts: "Yes, iterate": a more serpentine python head and an albino skin from the D-162 budget left (6500 of 8000), boards to the director. Owner: the VFX lead's asset session.

## 2026-10-23 · D-169 · Director · He makes the Suno music this week; M1 ships with it

Asked (M1 waits for every item, D-155): "I'll make them this week". Prompts in docs/audio/music-briefs.md (one per city, instrumental, "Get Stems", about 2 takes each). The lead cuts the loops, sets the layers (D-125) and registers each track in docs/provenance/music.md.

## 2026-10-23 · D-168 · Director · The whale swims in the water between the play city and the distant city

Asked by the demo-end session (river vs a new bay). He: "we already have a river/bay between the play city and the distant city"; confirmed: "Yes, that water": the whale (one per run, untouchable, D-155) surfaces and spouts there, well away from where the kaiju rises. No map change, no new water.

## 2026-10-23 · D-167 · Director · Pacing and city: a cheaper Thunder Beam, Endless regrowth, wrecks crush the army, five weathers

Asked at the interview. Pacing (the last unlock measured at 2.62 h after the three growth steps, D-156 asks about 2 h): "Cheaper Thunder Beam": its three levels cost less so the last unlock lands at about 2 h; nothing earlier changes. Amended the same day: the beam alone cannot reach 2 h (a free beam still ends at 2.11 h; the four other Colossus upgrades take about 33 runs); asked, he chose "Beam at a third, ~2.25 h": only r_beam, at about 30% of its price, the Colossus keeps a full act of about 1 h. Endless (D-156): "About 5% a minute" of the flattened city comes back, with the army worsening forever. Helicopter wrecks: "Also the army": a crashing wreck razes and burns buildings and also crushes tanks and rooftop squads below it; it still never hurts the kaiju (amends D-140's "only the city"; PR #166 goes back to the first build). Tall towers: "Keep it": the Colossus takes about 1.5x as long on the tallest towers of the wider city. First baby city: "Leave it": a new baby may not reach the eerie quiet. Weather: "Five, as built": clear, overcast, rain, fog banks, thunderstorm.

## 2026-10-23 · D-166 · Director · Play: damage lands on impact, rare claw swats, staggered railgun volleys, heads are looks first

Asked at the interview. Wind-up: "Damage lands on impact": a big attack wrecks when the jaws or foot land, a visible beat of about 0.5-1.5 s after the press (a sim change: the damage waits for the strike). Claw swat on jetpack agents: "Rare lucky swat": as now (about 1 in 85 swipes); toppling their roof stays the real answer. Railgun volley: "Stagger the shots": one squad never lands more than about 2 hits' worth in a second, which leaves the dash time to save you (D-161). New heads: "Look only first": a head is picked as a cosmetic on the evolve screen until he decides its play (D-124); how heads unlock stays his call.

## 2026-10-23 · D-165 · Director · The croc is a living predator standing still

Asked with the idle audit (it barely breathes, only the tail sways, it stops dead): "Living predator": slow heavy breaths seen in the back, shoulders, flanks and tail (the camera sits behind him), weight shifting from foot to foot, the head drifting and glancing, an occasional jaw crack and blink, slower and heavier as he grows. Not: panting after big attacks ("No"), or eyes tracking prey ("No"). Stride: "Heavier as he grows": each step about 3x longer at full size while ground speed still rises. Footfall: "Tail, throat, jowls swing" slowly; belly and flanks barely move. Dash: "Yes, a short crouch" before it. All presentation, never the sim. Owner: the VFX lead.

## 2026-10-23 · D-164 · Director · Heads and skins: the Komodo with its own shape, a more serpentine python, Obsidian, Abyssal and Albino

Asked with the D-162 boards. Heads: "C Komodo, own shape" ("the komodo looks incredible though"): a short, deep, heavy jaw; bites, roars and hit size are re-fitted to it. The python: "isnt quite serptentine enough, it still has croc teeth?": another round with a snake's head, jaw and fangs, no croc teeth (D-170). Skins: "B Obsidian", "D Abyssal" and "albino too" (a new concept). Method: a colour table per body region (back, belly, spines, claws, eyes, teeth), tunable in Aseprite, 0 credits; not a Tripo re-texture. Owner: the VFX lead.

## 2026-10-23 · D-163 · Director · One look, built from blocks: far blur, cool shadows with warm fire, fine-block ground

Asked after the voxel-look research and boards ("im worried that theres a mix match of art styles"). "Keep blocks, one look": buildings keep breaking where you bite; cars, trees, props, ground, fire and blasts are brought into the city's look. Close shots: "Blocks everywhere": no separate smooth croc for the title, intro, load screens or end card; they get the same skin and light upgrades as play. Depth blur: "Far blur only", locked on the kaiju, with haze carrying the depth (no tilt-shift). Colour: "Cool shadows, warm fire". Ground: "Fine blocks like the city" for roads, lawns and pavements. Confirms D-111. Owner: the VFX lead.

## 2026-10-23 · D-162 · Director · Tripo: 8000 credits for snake and Komodo heads and skin concepts, shown at the interview

Said before sleeping (2026-10-23, about 03:25): "feel free to spend some time and tripo credits as well get some models for the alternative heads, snake and komodo dragon", "concept some different Skins too", "come up with a few skins, and a couple options for the heads, include it in the interview when i return from work we can iterate more", "tripo budget is 8k credits". Covers a couple of head options each for the snake (python, ROADMAP "Reptilian head evolutions") and the Komodo dragon, and a few recolour skin concepts of the croc (ROADMAP "Achievements and skins", D-119). Owner: the VFX lead's asset session. Every model Private, six-viewed, logged in docs/provenance/tripo.md; stop at 8000 credits. Concepts only: labelled boards go to the director at the interview, where he iterates; how the heads unlock and what they change in play stay his call (D-124).

## 2026-10-23 · D-161 · Director · Railgun and frost rules

Asked (the non-author sim review of PR #161 found these agent-added): the railgun has to hit the body's middle (a shot that only crosses the tail or snout misses), so a step aside as the line locks dodges it in the open; while smashing through a building or slowed by frost a step is too slow and only the dash saves you (the dash also shatters the ice): "Only the dash saves you". The shot pierces buildings, no cover. Armour softens railgun hits like every other hit. Frost grenades land only on a kaiju standing still, so moving dodges them.

## 2026-10-23 · D-160 · Director · The Taskforce first joins after a few minutes in the adolescent city

Asked (PR #161 gated the first arrival per rampage, after about 150 chunks plus 6 s: agent-added): "arrives a few minutes into the adolescent city" (D-152) means total time there, not each rampage: "After a few min there". The player's first rampages as the Behemoth are army-only; once they have spent about 3 minutes of rampage time in the adolescent city (a play-time counter carried between rampages, in the save), the Taskforce joins every rampage after, and squads still come faster as more of the city falls (D-152). Never the baby city. The 3 minutes is the lead's pick inside "a few minutes", one data value.

## 2026-10-23 · D-159 · Director · The team fits the PC; full tests on CI; clean code as you go; measure sim speed

Asked "whats the best way for us to get stuff done on this project? tell me if this workflow is suboptimal" and "is our architecture sound? can it be improved". The lead measured: 14 engine jobs on 16 CPU threads at 100%, helpers mostly waiting on local test runs, a 2-hour balance run taking about 2 hours, 6 open PRs (rule: 3). Code on look-options 70ef2ac5: the sim is clean (no Node, input or clock), seeded streams, the six fixed autoloads, versioned saves, size caps enforced by lint; weak spots: 20 files packed at 390-400 lines, 77 grandfathered long functions (ratchet baseline), slow balance runs. Asked: "Fit the PC": about 4 engine-running builders at once in total, the lead's and the VFX lead's together (readers and critics that run no engine do not count). "GitHub runs them": builders run only the suites their change touches; the full suite runs on CI before merge, never locally. At most 3 open PRs (the standing rule). "Yes, as they go": builders split a crowded file at a natural seam and shrink a grandfathered long function whenever their work touches it. "Yes, after current work": the lead measures where the sim's step time goes so a balance run takes minutes; any game change it suggests goes to the director first.

## 2026-10-23 · D-158 · Director · Title camera tilts up so the Colossus towers

Asked by the VFX lead with the current title still: the title camera tilts up until the Colossus head stands 1.5-2x the tallest centre tower, the full head silhouette stays in frame, and the water band gets about a third thinner (accepted) with the fire reflections still visible in it. Amended 2026-10-23: the title builder measured that no tilt reaches 1.5-2x the 163 m centre tower with any water left (the head stood 1.15x the 102 m tower under it, 0.8x the 163 m one). Asked: "Bigger + lower tower": the Colossus grows (140 to about 185 m), the camera tilts about 7 degrees so the water band is a third thinner, and the 163 m tower is lowered on the title only, so nothing on screen is taller than the Colossus; its whole head stands 1.5-2x the tallest tower left in frame.

## 2026-10-23 · D-157 · Director · The army's stray shells count as the kaiju's destruction

Asked (sim review of PR #159 found it agent-added): when a tank's missed shell smashes part of a building, it all counts: the kaiju earns the biomass, the city's ruin rises, and the army escalates as usual (the army wrecking its own city in a panic feeds the predator). The D-066 damage budget is measured with helicopters on, including that escalation.

## 2026-10-23 · D-156 · Director · The demo ends when the whole upgrade tree is unlocked; endless mode

Asked what triggers the thanks screen; then he changed it: "i think we should measure until the upgrade tree is fully unlocked (2 hours roughly)". The thanks screen appears when the player buys the final upgrade; costs are tuned so that takes about 2 hours (D-152 window). "After they unlock the final upgrade they can unlock an endless mode maybe, where the city regenerates slowly and enemies escalate; otherwise players can feel free to replay the normal mode with their maxed out kaiju as many times as they want." Asked: endless mode is in the demo. Replaces D-153's free play in the ruined city and the old trigger (buying the Behemoth evolution). Then: "the game's balance will not be determined by endless mode. the normal mode is still the main way to play and all balance questions ultimately will be decided on whether it makes normal mode better" (DESIGN Progression).
## 2026-10-23 · D-155 · Director · Atmosphere joins M1; weather; music and city sound; version; end confirm

"keen to get stuck into the atmospheric stuff soon". Asked: all four parts, and all are part of M1 (M1 waits for them): rampage escalation (D-154: haze, orange sky, spreading blackouts), sky and sea life (clouds, birds that scatter, small boats, one untouchable whale per run; comments #63-64, #71), weather, and sound atmosphere. Weather is looks only: rain, fog banks, thunderstorm, overcast or clear; picked at random per run with the time of day, never the same twice in a row, with an options toggle to fix it. Music: the lead writes one short brief per city (style, tempo, mood, stems), the director generates in Suno (D-114) and the lead cuts and layers the stems (D-125). City sound: panic then eerie quiet (crowds and sirens swell early, then fade as people flee; the late city is fire, wind and military). Version tag: "DEMO 0.1", rising one step per milestone (M1 0.1, M2 0.2, M3 0.3), the Itch release is the 1.0 demo. End rampage in the pause menu asks "Are you sure?" first.

## 2026-10-23 · D-154 · Director · Visual direction (12 answers in the VFX lead's session)

Asked by the VFX lead (recorded in docs/VFX_STYLE.md "Visual direction", PR #154): fire is cinematic (deep orange-red, black smoke); as a rampage escalates the haze thickens and the sky turns orange; collapse dust walls may swallow the camera for 2-3 s (an exception to D-018); a big stomp's wave ripples through the blocks (cars hop, windows burst); debris rains for 2-4 s; rare split-second slow motion on the biggest moments; glass breaks into glittering shards; night blackouts spread as the city falls; crushed people are a bloodless puff; enemy kills are mostly small crushed pops; the croc's spines and throat crackle with white-hot lightning on charge, stronger with each evolution; Taskforce energy is clean, precise tech.

## 2026-10-23 · D-153 · Director · Demo free play, version tag, tester count

Asked. After the thanks screen the adult city stays ruined and the military and Taskforce keep arriving in waves to be eaten (endless free play). The demo shows a tiny "DEMO 0.x" label in a corner so screenshots and reports name the build. About 10-20 invited testers. Gamepad plus keyboard and mouse reconfirmed (already D-004/D-040): every new menu (title, pause feedback, thanks screen) must work with a pad.

## 2026-10-23 · D-152 · Director · Milestone logistics, Taskforce tuning, demo end

Asked ("ask me a lot of questions"). Milestones: builds go to Desktop\Kaiju Builds, one subfolder per milestone; each survey is a private web page with fields (sliders, ticks, comment boxes) whose answers the lead reads back; M1 waits until every M1 item lands. Demo length: 90+ min, about 2 hours at most. Taskforce: agents first appear a few minutes into the adolescent city, never in the baby city; frost halves the kaiju's speed for about 4 s; each agent fires its railgun about every 12 s; an agent kill pays about a tank's worth; a walking mech dies to one stomp or swipe; a gas cloud lasts about 8 s and is about one street wide; up to 2 gunships at once in the adult city. Demo end: the thanks screen shows buildings destroyed, people eaten and fled, military destroyed (every unit type), time played and biomass earned; after it the tester can keep rampaging the adult city. The Itch demo is Windows only. Low health warns with the red pulse only (no heartbeat).

## 2026-10-23 · D-151 · Director · Effect family rulings (asked by the VFX lead with a labelled board)

Asked in the VFX lead's session (look sheet, PR #154): an explosion is a sudden tall burst of the game's own fire ("Fire's tongues"), then that fire stays burning; chemical gas is soft tinted smoke (the smoke family, also the Taskforce gas look); smoke is lit from below by its fire everywhere (game and title); on the title, burning floors' windows turn fire-orange; the Lightning Breath / Thunder Beam effect rework is IN M1; the Taskforce owns one electric blue nobody else uses (the tank-deflect flash becomes white); blasts and Taskforce hits use the same street dust as everything else; the VFX lead fixes the base mismatches now (tail-sweep yellow ring, tree-puff sprite, plain shell sparks) in #154.

## 2026-10-23 · D-150 · Director · Title menu column stays high

Asked (4K still shown) where the logo-and-buttons column sits vertically: keep it high, as in his mockup; the calm water below stays as deliberate space.

## 2026-10-23 · D-149 · Director · The leader's escape helicopter, after the demo

"roadmap item: "the president/prime minister/king/etc" attempts to escape in a fancy helicopter, you get a big payout if you kill him but its a fast helicopter". Asked: after the demo; it happens at a random time in any city; the rank grows with the city (Mayor in the baby city, Governor in the adolescent, President in the adult); the payout is about a city block's worth (worth chasing, never more than the rampage); the kaiju can bring it down with the breath or Thunder Beam, by grabbing it as it passes low, by throwing a tank or car at it, or by toppling a building into it at lift-off; about 15 seconds from lift-off (it circles once, then speeds to the map edge); a ticker headline and a distinct rotor sound only, no markers (as D-143); if it escapes only the payout is lost, with a mocking headline; look: white and gold VIP (a labelled board when built).

## 2026-10-23 · D-148 · Director · Demo feedback link goes to the Itch page comments

Asked where the demo thanks screen's feedback link (D-145) should send testers: the invite-only Itch page's comments (no new service to set up). The pause-menu bug report stays a local file (D-145).

## 2026-10-23 · D-147 · Director · Threat Dossier (bestiary), after the demo

"roadmap item (after demo): a beastiary (name must be thematically appropriate) to describe the multitude of enemies you encounter in the game". Asked: named the Threat Dossier (the Kaiju Plan organisation's classified files on every force sent against your kaiju); an entry's name and silhouette appear on first sight, its full stats, weaknesses and lore after the first kill; opened from the main menu and the pause menu. After the demo.

## 2026-10-22 · D-146 · Director · Playtest milestones replace per-change clips and approvals

"we are wasting our time making so many clips, its better for you to build, then i play and you give me an exhaustive survey to fill"; then "not NO more clips, but not so many, and i dont want to play every single update, you need to identify milestones in the roadmap that justify my playtest and craft a survey for that game state". Picked 4 milestones (ROADMAP "Playtest milestones"): M1 feel pass, M2 Taskforce agents, M3 demo complete, M4 Itch release candidate. Builds are exported .exe files in a fixed folder. The lead merges green, critic-passed work without a director gate.

## 2026-10-22 · D-145 · Director · Demo is all three cities, ~90+ min; more Taskforce rules; roars, names, time of day

Asked 2026-10-22 ("ask me 20 questions"). Demo: includes the adult city (DESIGN's "hatchling to Behemoth" demo line is superseded); a first playthrough runs 90+ minutes; the end shows a thanks screen with rampage stats and a feedback link; the pause menu has a bug/feedback button that writes a report file with version and screenshot (no network calls); demo saves do not carry over to the full game. Taskforce: gas locks special powers only, the dash and every physical attack still work, and the cloud does no damage; mech bombs hit the kaiju and the city; the railgun line tracks the kaiju then locks shortly before firing, so a late step dodges it; several frost grenades refresh the slow, never stack; the dash shatters the ice early; gunships strafe with a blue laser cannon; squads arrive faster as more of the city falls; a destroyed mech blows up and damages nearby buildings; every railgun hit fires the post-effect colour fringe. Post effects: the red low-health pulse starts below 25% health. Title: one fixed view (not the player's current city); keep the BREAKING ticker. Layout: "move our main menu buttons achored to left of screen, keep the most visually apealling scene elements to the right of screen"; the logo sits above the buttons as one left column. Then his own layout (2026-10-23 mockup): a settings gear top-left; under the logo one row, a wide "Continue Game: <species>, <n> rampages" plus a smaller "New Kaiju?" (with no save, one wide "New Kaiju"); an exit button "Run for your life!?" bottom-right above the ticker; buttons in the worn industrial plate look. Colossus: "occasional explosions should reveal the sillhouette of the reptilian colossus obscured in the inferno" (supersedes the earlier silhouette removal); about every 12-20 s, and it moves slowly in step with the footfalls between reveals. Then: "the colossus silhouette could look a bit better though, more distinctive but less of a solid outline, give him red glowing eye (faintly) through the smog". Helicopter crews sometimes bail out by parachute. Load screens: a thin hazard-stripe progress bar. The signature beam is called "Thunder Beam for now but thinking of a better name". No roar button, but the kaiju "should roar more often, perhaps when he uses his ultimate power and/or a dash". Time of day: "the time of day will be randomised each run (a toggle available in the options menu to set a fixed time if players prefer)": random per run replaces D-106's rotation, with an options toggle for a fixed time; "random but cannot do the same time of day twice in a row".

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
