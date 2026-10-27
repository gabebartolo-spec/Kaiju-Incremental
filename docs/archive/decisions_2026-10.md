# Decisions archive, 2026-10

Rolled from docs/DECISIONS.md (cap 400), newest first, unchanged.

## 2026-10-26 · D-275 · Director · The croc tree uses the ring layout, with zoom-out and easy panning

The croc tree grew to 58 nodes (ROADMAP E, b2-28) and no longer fits the 8x6 grid on one screen. Shown three labelled layouts drawn from the real data (A rings from the centre, B a map growing upward, C today's grid widened, panning sideways), he picked "A but we need to be able to zoom out and pan easily": the baby's nodes sit in the middle, each growth stage is a wider ring outward, and the player can zoom out to see the whole tree and pan around it easily.

## 2026-10-26 · D-276 · Director · From 23:00, full focus on the render plan

Godot work resumes at 23:00 (paused earlier in the day). "at 11pm i want to switch full focus to the render plan": every builder slot goes to the render plan (baseline first, then batches P1a, P1b, P1c, then phase 2). Asked what happens to running non-render work, he picked "Let them finish": Tripo beachfront round 2 and the croc tree's ring layout code (D-275) finish, since neither uses Godot; their Godot tests and PRs, the run intro and the other open PRs wait until the render plan is done.

## 2026-10-26 · D-274 · Director · Rise and roar kept; beachfront regenerated (keep B01, S01, S02), up to 1,600 Tripo credits

Shown the Cascadeur clips on r11: rise out of the bay (hips float up while the hind legs tuck under, legs push the last part) "Keep it"; intro roar (inhale, head up, held gape, four throat pulses) "Keep it". Both go into the run intro via the game_r11 export (after #223). Beachfront board after the Blender fixes: "regenerate new building instead, these are mostly unusable. surf shack, beach tower, and apartment tower are usable" (kept: S02 thatched beach bar, S01 lifeguard tower, B01 apartment tower). What was wrong: "Messy or broken geometry", "Muddy, dark textures". Spend: "Up to 1,600" Tripo credits for the other 16 (balance about 7,320). The Blender fixes of D-271 are dropped. Also on the audit's conflict questions: the six-way question "didnt make sense to me then and doesnt now either", the ticker one "meaningless without context", Smart Mesh "idk you said it didnt matter at the time": the lead keeps what is built (bigger blocks with the 6 m diagonal, #243; the helicopter headline cut; HD unless a method test shows Smart Mesh fixes the geometry).

## 2026-10-26 · D-273 · Director · Sound-effect credits: no cap (recorded late, ruled 2026-10-25)

On 2026-10-25 at 07:55 the sound session reported its sound-generation subscription at about 2,071 of 40,000 credits used, the train sounds at about 430-450 under a 500 limit, and spending stopped. His reply: "spend as much as u want" and "download them yourself". This is his written yes for spending that subscription's credits on the game's sound effects; it does not cover Tripo or any other service. Found by the interview audit (D-272).

## 2026-10-26 · D-272 · Director · Godot paused, Cascadeur/Blender/code open; interview audit with 4 temporary readers

"so you can use Casc and blender now but no godot"; "and you can do coding tasks, im sure theres plenty of nodes for hte upgrade trees you need to implement". On node ideas: "ill be mad if you havent been adding my ndoe comments to the roadmap / ive been saying node ideas throughout our interviews"; "there must be record of my interviews, find them, read them, then make sure EVERYTHING from the interviews is reflected in the roadmap". Audit slots: "4 temporary readers" (close when done). Every interview answer and director message from all Kaiju transcripts (2026-10-16 to 10-26) is checked against the roadmap; missing items go into ROADMAP or a chapter.

## 2026-10-26 · D-271 · Director · Beachfront models fixed in Blender; landmark placement is per map seed

Beachfront Tripo board (19 models + pier retry, 1,300 credits spent): "Fix in Blender": all 20 kept; builders cut the shed fused to the pier span (P02/P02r), trim B02's ragged balconies, fill B05's blank facade from a good one, and model the missing parts (V02 string lights, S03 boat doors, S04 changing block) as simple pieces; V03's pole canopy and loose sign and B07's bridged twin towers are fixed or trimmed the same way. No new spend. Stadium and wheel "south, past the river" (D-270) is a seeded placement rule, not a fixed spot: "havent we already agreed that this is random map seed reliant?" (D-133, D-261). The stage-2 stadium bar stands; #245 only keeps landmarks off the sea bay; the full per-run shuffle goes with the random-city work.

## 2026-10-26 · D-270 · Director · Evening interview: rain kept, sea bay shape, keyed rise, stadium south, beach half the edge, bubble target

Back from afk ("im back, interview me", "pause godot work": every Godot run stopped and held until he resumes; picked "Stay paused"). Rain round 1 (adult, dusk, rain clip): "Good, keep it". Sea bay: "Crescent bay" (cut from the coast into the city's north edge, ending inside the play area; a sand beach at its city end, quays on its flanks; by rule on every city), over moving the whole coast in. Rise: "Keyed rise" (Cascadeur clip rise_bay: head first, shoulders, legs push last, then the roar; never a pose lifted in code). Stadium and Ferris wheel leave the north edge: "South, past the river". Beach length at stage 1: "About half the edge" (~50 m of ~105 m, grows each stage). Camera bubble: the OFF/ON clip showed no building near the camera ("man, theres already no buildings. both the clips are identical"); on the rain clip's tower filling the right of frame: "this in the rain clip is a perfect example of why i dont like the buildings coming into the camera". The next bubble clip uses that run and moment, OFF vs ON.

## 2026-10-26 · D-269 · Director · Beachfront district buildings from Tripo, up to 1,300 credits

"so beachfront is officially our new district, we need bespoke buildings for it, get started on a tripo session". Picked "Up to 1300" credits (about 20 HD models at 65; D-256's district budget had 670 left) and the set "Towers and hotels, Promenade venues, Beach structures, A pier". 19 prompts (7 towers and hotels, 6 promenade venues, 4 beach structures, a pier head and a repeatable pier span), HD Model H3.1 as D-256 ("Keep HD"), Private on each, six-view checked, voxelised into carvable cells like the district set, one board for the district to him.

## 2026-10-26 · D-268 · Director · Every leap carves through what it hits in flight and lands with a smash

Asked (the leap at a tower: the arc was blocked by the tower in its path): "he should carve right through what he hits in mid air and land with a smash"; then "Every leap", not only at towers. Replaces D-262's "nothing is hit in flight": the body breaks every building it passes through on the arc, then the landing smash hits as before. Owner: lead (sim + leap tests: "nothing hit in flight" becomes "carves what it hits").

## 2026-10-26 · D-267 · Director · Morning interview of the overnight calls: stomp lands, 1 in 8 per stage, real-strength badge, belly-down death, shrunk wide towers, density per built block, props recoloured

Asked one at a time on his return (D-265 afk calls). Stomp: "Yes, merge it" (PR #223 at 0.80x, D-264). Death rate: "Every stage": about 1 run in 8 (8-17%) at each growth stage, not pooled (D-259). Threat badge: "The army's real strength": its level follows the army's actual arrival rate, scaled per stage. Defeat: "Flat on his belly": he slumps straight down, chin on the street, after the rig fix (rig r11). Wide Tripo towers: "Keep them shrunk" to their lot. Density: "Same feel per street": buildings per m2 of built blocks only (parks, plazas, river, roads, rail left out), kept the same on the wider play area. Props: "Recolour in Blender": the 16 near-grey Tripo props tinted from real-world colours, Tripo's texture detail kept, originals untouched; he votes on the recoloured page.

## 2026-10-26 · D-264 · Director · The stomp plays 20% slower; a tree node brings it back to 10% slower

After the stomp-button clip (PR #223): "i think the stomp needs to be slowed down maybe 10-15%, maybe even slow it down 20% then a node on the upgrade tree can increase its speed to eventually 10% slower than i see in that clip"; "it looks too fast, it makes it looks weightless rather than titanic". He held #223 until it is slowed. Lead's fix: the stomp motion plays at 0.80x at every stage, and the stomp interval stretches with it (0.7 s to 0.875 s); the croc's Frenzy node ("Stomp more often", 4 levels) becomes that speed-up, his pick "Frenzy becomes your speed-up": each level lifts the speed 0.80 -> 0.825 -> 0.85 -> 0.875 -> 0.90x, never faster, the interval always the clip's length (other species keep Frenzy as it was).

## 2026-10-26 · D-265 · Director · Overnight shift; End rampage is a death

Going to sleep: "keep working": prepare animation prototypes to assess tomorrow (picked "Croc kit moves" and "Croc idle/walk/turn/roar redo": leap, charged stomp, snap bite, defeat collapse, and the everyday clips re-keyed in Cascadeur); "voxelise all our new buildings and implement them into the games city generation" (picked "Yes, on by default": he culls from boards and in-game shots tomorrow); "start building the districts, landmarks and explosive sites and codify the logic which generates their appearance in a seed" (picked "Play area, then districts"); audits: road layouts natural and realistic in all seeds, seeds meaningfully different, every asset appears often and none never; "keep working on things that dont require my eye, coding tasks, first drafts of visual items are also fine". Team: "+2 builders tonight" (five builders until he returns). Pause "End rampage" kills the kaiju ("Yes, he dies"): every run ends in a death unless the city falls. Note: D-263's red-light answer replaced D-257's "Suggestive signage"; the question did not quote the older ruling.

## 2026-10-26 · D-266 · Director · Tripo street-life props, up to 1,500 credits

"if you somehow run out of things to do, please start generating some streetlife props in Tripo"; picked "Up to 1,500 credits" (about 20 props, the most common street things first, every model Private). Balance before: about 9,855. Props go through the same six-view inspection and straight to him.

## 2026-10-26 · D-263 · Director · Interview of 9: charged stomp, bite, combo, time's up, results, city seeds, red-light

Asked ahead of the croc kit, shell and city queue ("ask me questions about jobs next in your queue too"). Charged stomp "Rooted while charging" (he plants and crouches until release). Snap bite "No, snaps mid-stride" (eating never slows him). Combo "Any kill or building break" keeps the ~3 s window going. Time's up: offered a retreat, he answered "wait no i want him to die": at zero the "Army's final strike" (one overwhelming jet run or railgun volley) kills him, he collapses in the street as on defeat, and "Yes, every death counts" (the specimen number goes up on every death). Results: "Headline per ending" (city falls / killed by the final strike / lost to the army). City order "Different per save" (each save slot's own seed plus the run index; replays and tests still reproduce). Red-light district "Neon and signs only" (nothing suggestive, original names).

## 2026-10-26 · D-262 · Director · The croc's leap arcs high and lands on the target's roof

The leap (D-259, replaces the dash) first flew a realistic low arc (about half to one hip height), lower than most buildings, so the body would plough through whatever stood between the croc and its target. Asked how the leap meets "a leap that lands on a building and crushes it with a shockwave", he picked "High arc, lands on roof": the croc springs high over the street and comes down on top of the target building, crushing it with the shockwave; nothing in between is hit. The reader's realistic apex bar (L5) no longer applies to the sim's flight path; every other leap bar stands. Player copy says "Leap", not "Dash".

## 2026-10-26 · D-261 · Director · Cities from shuffled building blocks; railgun warning fits the leap; more slots; trial clips in dev builds

City: today every run in a stage is the same city (fixed map_seed, building stream index 0), short of D-133's per-run landmarks. Ruling: "our city mostly randomised but with pre-determined blocks of buildings" (authored blocks built from the Tripo heroes and fillers, district by district, shuffled onto the street grid each run with the landmarks and explosive sites); streets "Shuffle within a few street plans" (2-3 tested plans per growth stage). "we can also create more districts if that helps". Railgun vs leap (D-178): the lock warning grows to fit the leap's crouch, "Longer warning, scaled by size" (about 0.6 / 0.75 / 1.0 s), so a leap at the lock still dodges the volley. Team: an extra builder slot "for the Shell work", and "open another slot temporarily for the road agent" ("dont leave work half finished"). Cascadeur: "we still have more time on the trial ... continue": trial animations may be used in development builds (register: DEV ONLY); the paid licence (Indie covers every feature we use) and a re-run of each kept animation come before any release; no more asking until then.

## 2026-10-26 · D-260 · Director · Interview of 20: biomass flow, tree rules, stomp charge, power grid, civilians, defeat, specimens

Asked 20 more (checked against the archive first). Biomass "Automatic, shown flowing to him" (a mote stream into the croc); "No refunds"; evolution "At once, with the reveal"; after results "The tree, with 'Rampage' one press away". Stomp "Tap to stomp, hold to charge" (about 1 s charge, bigger shockwave, a crouch and crackle tell); breath stays on its cooldown; the breath "surges the grid" (power lines and substations spark down the street, blow transformers, black out the block). River: no preference (lead's call: he can wade, no rule; healing stays the D-259 tree node). Civilians: "Small blood smear, no chunks" (replaces the archived "bloodless puff"; the gore toggle turns it to dust); they evacuate toward the edges over a run, with jammed exits. Army-wrecked buildings pay "full pay" (jet strikes stay unpaid). Defeat: "He collapses in the street". "+N" pops "Only for big payouts". Navigation: landmarks "Visible on the skyline, nothing else". Time of day stays random per run (D-258's "Night only" was the street-life answer, not the run's time). Specimens: the kaiju is "SPECIMEN K-01" and each death makes the next ("i meant 'dies'"), shown as a 2 s "Lab card + a short headline" (K-01 LOST · K-02 RELEASED) before the rise. No difficulty setting; the Taskforce commander mini-boss "After the demo"; pause has "End rampage" only (pays as on defeat).

## 2026-10-26 · D-259 · Director · Interview of 30: run length, combo, croc kit, defeat, districts, camera, options, demo shell

Asked 30 questions ("study all the features ... 30 pertinent questions"). Loop: rampage timer "60 s up to 3 min" (data rows, timer nodes); on defeat "Keep it all"; combo "a small, quick combo" (about 3 s window, cap about x2, pop on the biomass figure); throw nodes "Ricochet" and "Domino" (no wrecking ball). Croc kit: the leap that replaces the dash ships "in the demo"; claw rake "Stays automatic"; tail whip "Automatic, from a tree node"; healing "A tree node unlocks it" (eating heals once bought); an "automatic snap" bite eats people, cars and helicopters near the snout. Army: defeat "Rarely, about 1 run in 8" (replaces D-069a's softer target); "A small threat icon" (a 1-5 level badge near the timer, the one HUD addition); mortars "After the demo"; the city "falls" at 85% destroyed (the run ends on a win beat). City: "one signature hazard or prey" per district; a "Fresh city each run" (no scars). Shell: "Three slots"; camera "Limited swing, auto-returns" (about 60 deg, eases back); slow motion "Only when a landmark falls" (narrows the archived "rare split-second slow motion on the biggest moments"; the VIP stays without, D-243); rumble "scaled by size, with a toggle"; a simple photo mode in the demo; accessibility: rebinding, reduce flashing, hold or toggle, colour-blind safe cues; gore "On by default, with a toggle" (D-242 unchanged); languages "All six + Chinese at the demo"; results screen: biomass and best combo, destruction tally, body count, personal bests (extends D-152's stats); no demo-end tease; news crawl "On big events"; run stats "Opt-in, attached to feedback" (no background sending; D-152's no-network feedback file gains a tick box); Steam page "Not yet"; a 60 s trailer from game captures; if M4 slips, "Hold M4 until all of it is in". He noted some questions repeated earlier interviews: the lead now greps the archive and roadmap chapters before asking.

## 2026-10-26 · D-258 · Director · Street life, Taskforce and demo rulings

Street life: civilians "Mixed panic"; hydrants "Puts out fires"; traffic "Yes, jams and pile-ups"; time of day "Night only". Taskforce: grapple "Buildings only"; swatting agents out of the air "Yes, with a bonus"; an agent hit is a "Gore splatter"; jetpack "Hover and fire". Demo: the automatic stomp is replaced by the stomp button ("Button replaces it"); scope "Baby to adult croc"; controls "Keyboard+mouse and gamepad".

## 2026-10-26 · D-257 · Director · District buildings: review, scale, colour, signs, rewards; new bridge; stomp button

Asked a batch ("ask me a lot of questions"). Tripo buildings: reviewed as "One board per district"; tallest skyscrapers "About 2x the croc" (adult); "District palettes" applied at voxelising (Chinatown reds/greens, docklands brick, neon strip dark with bright signs); Chinatown signs in "Real Chinese characters" (authentic shop words, meaning checked, no real brands). Red-light district: "Suggestive signage" (cheeky silhouette neon, XXX-style signs; nothing explicit beyond signage). Hero landmarks (bank, town hall, courthouse...): "Yes, a big bonus" (biomass burst + callout). Landmark bridge: "Make a new one" (Golden Gate / Harbour Bridge style suspension span over the wider water, Tripo HD, inside the D-256 4700 cap). Croc stomp: "Its own button" (stomp where you stand, shockwave flattens nearby streets and props). Also: "Swap in the new adult" (adult3 replaces croctitan in game; old clips retargeted until re-keyed in Cascadeur); keep HD over Smart Mesh for buildings ("Keep HD").

## 2026-10-26 · D-256 · Director · Tripo district buildings: hero pieces and 40 fillers, up to 4700 credits

"can probably make the architecture as tripo models then voxelise it if that works?"; picked "Hero buildings, <=1500 credits", then "id be happy for you to make like 30-40 buildings in tripo to act as filler buildings" and picked "Go to 40 filler" (<=3200). Districts total <=4700 credits. Every model gets a six-view check and is voxelised into carvable cell grids (tools/landmarks/bake.py, D-253); filler is placed with variation (facings, mirror, floor stretch, palettes, roof clutter), no model above 5% of a view, no identical neighbours. "can you get started on the tripo": the lead generates through the built-in browser.

## 2026-10-26 · D-255 · Director · Districts grow by stage; street life; human clips may be premade; agents swing and jet

Districts (comment #78): red-light district, Chinatown, docklands, a bar and restaurant street, a business district, neon commercial streets and a giant billboard intersection; picked "Grow by stage" (baby: bar strip + neon street; teen adds Chinatown, red-light, docklands; adult adds business district + billboard intersection). Street life (#77): traffic lights, power lines, manholes, bins, graffiti, street lights, phone booths, food trucks, plus "Add a few more" (hydrants, bus stops, benches, newsstands, bikes). Taskforce (#76): "spiderman" grapple swings then jetpacks, "Mix by situation"; "if the premade clips are better, then we use them" (humans only; kaiju stay Cascadeur); agents get "New voxel poses".

## 2026-10-26 · D-254 · Director · Play area 1.5x wider; landmarks and explosive sites spread; the landmark bridge

"id like to expand the play area for all 3 stages": "1.5x wider" (half-widths 75/120/225 m). "space out our landmarks (of which one is a bridge, so we can also put an expanded water area there) and explosive sites across the new expanded area"; the bridge is the D-133 suspension bridge tower Tripo model, "like a sydney harbor bay bridge/golden gate bridge style".

## 2026-10-26 · D-253 · Director · Carving is universal for every building and structure

"carve is a universal feature for all buildings" (standing rule). Every building and structure, railway included, breaks only through the one voxel carve and collapse path; a CI test fails any structure type that removes geometry another way (landmarks and river bridges are named known gaps until converted). PR #209 rail: "FIX. he doesnt carve it at all? he hits it once and it disappears".

## 2026-10-26 · D-252 · Director · Croc focus to the Itch demo; dragon paused; subagent team; model per task; merge everything

"can we pause all dragon work for now though", "I want to focus on getting croc shipped" (finish line: Itch demo, M4); croc stomp first ("Croc standing stomp", then "Croc stomp next"). Team: subagents, 3 builders + 1 reader; "i need you to determine whether a task demands opus or sonnet". Branches: "I want the branches fully cleaned up and stale ones removed / i want all mergable good work merged"; "why isnt it merged? ive been asking you to merge everything" (PR cap 8 until the backlog lands); branch force-delete unblocked in settings ("Remove the block"). Skeletons: "optimised for natural, smooth animation", "only interested in our reptilian skeletons".

## 2026-10-26 · D-251 · Director · Komodo w29 walk approved; Komodo lands off

"walk is good. ship it"; Komodo motion bars "His own, from w29"; Komodo work lands off by default while paused ("Land it too").

## 2026-10-26 · D-250 · Director · Straight to him: every visual goes to the director, judged by no agent

"just show me the clip, i will immediately know what is wrong and can describe the fix, you then workout how to do that fix"; every visual, every project. Replaces D-249's lead-looks-first route.

## 2026-10-25 · D-249 · Director · No critics: only the lead and the director judge art

Director: "abandon our critics, all art passes through you who ACTUALLY LOOKS AT IT and then ASK ME, so the builders are never judging the art, only you and me". Confirmed by question: every project, and the VFX lead does not judge either. Why: critics were passing work he could see was wrong. What changes: no critic agents or sessions (the four critic agent types are retired); every image, capture and clip goes straight to the lead, who opens it, checks it at 1x and 2x crops beside a real reference, sends back defects with exact fixes, then asks him with labelled images. Builders and helpers never give an art verdict. RULEBOOK, ~/.claude/CLAUDE.md, art-qa-critic, game-studio-lead and the Kaiju proof and handoff skills updated.

## 2026-10-25 · D-248 · Director · Team cap, handoff folder, start-up budget, mouth method, clean road

Team: at most 2 helper sessions, and every session (the lead included) runs at most 1 subagent; tonight casc-anim and vfx-lead (his pick), the atmosphere lead, Komodo mouth, claw and tongue parked. Handoffs: one copy per role in ~/.claude/handoffs/kaiju/<role>.md outside git, listed by the start hook from any folder (#205), after a regenerated lead could not find its handoff among stale branch copies. Start-up context: measured 108.6k tokens before any work; duplicate plugins off, comfy-mcp denied here, rulebook capped at 18 KB, a Stop hook logs and flags every session's start (budget 100k, lowered once he switches the unused claude.ai plugins and connectors off on both accounts). Komodo mouth: built tooth by tooth and strand by strand from a measured 1 cm grid (#60). Road: clean asphalt, dark and even with fine grain, crisp paint and faint tyre lines only (#61). Eyes rule: the lead opens every image a helper reports before replying (#62).

## 2026-10-25 · D-247 · Director · Smoke look confirmed; sound judged as a soundscape; Komodo keyed first; landmarks burn; rail carves; Nim 023

Smoke and sky (extends D-154): of the rampage still, "i think we can both agree the effect here is a bit much"; shown a reference picture and asked if it is the look he wants for the rampage smoke and sky: "Yes, that look" (dark plume columns with fire at their base, orange only at the horizon and behind the plumes, the city kept sharp). So D-154's "orange sky" means a low horizon glow, never a wash over the whole sky; the atmosphere lead's round 4 builds to that picture. Sound: "leave the sound listens to the playtest, ill listen to it as a collective soundscape rather than individual sounds" and "if anything sounds off or annoying we can iterate later": no single sound is sent to him; sound is judged at playtest milestones (the survey has a sound section) and iterated after. Animation (D-199/D-216/D-228 stand): the teen croc's stomp is redone in Cascadeur ("for the millionth time. I want 100% of our animation done with Casc"); machines (cars, turrets, rotors, trains) stay code, the rule covers "Creatures + people"; the new stomp is keyed on the "Komodo first", then the croc stages; until the real mouth is modelled the Komodo's roar is "Komodo mouth first, closed until then" (jaws shut, drool stays, D-239). Fire: "Yes, landmarks burn" (the agent-added off-switch goes ON). Walk weight (#4): "Drop it" (walk-m2 is dropped). Railway: "Yes, all of it" (pillars, deck and station break when the kaiju walks through; "all buildings in the play area must be destructible"; buildings that fall on the track damage it). Insectoid in the distant city: "yes bring it back" (on by default). Nim 023 is the train sound loops; "he can use $20 of claude api" (the lead's earlier question read as about ElevenLabs, which he corrected: "we use credits"). Comments #41-59.

## 2026-10-25 · D-246 · Director · Serpent redesign: hood, frills, armour, horns; Tripo test models (200 credits); serpent work frozen

"im concerned that our serpent kaiju just resembles a giant snake, roadmap: revisit the serpent concepts and possibly make new models"; "so dont do any serpent work until we decide on the final design". Asked: what makes it a kaiju is "Hood and frills" (a huge cobra hood with patterns, dorsal frills and spines) and "Armour and horns" (plated scales, horns, a crested head: a dragon-snake); explore with "Tripo test models", spend "Up to 200" Tripo credits (about 3-4 textured variants; no rigging or final model). All other serpent work (mouth, animation, powers art) waits for his pick. Also: "btw youre cooking the pc's ram too hard, ease up a bit": every lead now runs at most 2 heavy jobs, python pools at most 2 workers, nothing new under 6 GB free RAM.

## 2026-10-25 · D-245 · Director · Water details, rubble, shot impacts, real mouths, Komodo pace

Water (extends D-244, asked): "Looks only" (never changes damage or score); bay "Gentle swell, whitecaps in storms"; he reviews "After each step" (surface, ripples and wake, debris). Rubble ("i dont like the tangled mess of rectangular ruins clipping into one another"; asked): "Pancaked floors + debris", piles "Well below his knees", feet make it "Crunches flatter"; built "Right after ground". Shot impacts ("look a bit flat, like theyre pasted on top ... it glows too much ... a toned down impact indicator with a tiny red blood mist at the impact site"): on-surface, no glow, tiny blood mist; plus "faint wounds" that build up over a run. Komodo mouth: after three failed rounds on the closed-mouth Tripo head, "Model a real mouth" (asset session, no credits). All kaiju ("we should give all our models the same detailed, functional mouths with real anatomic features"; asked): "Croc first, then Komodo, then serpent"; gums, rooted teeth, wet lining, a moving tongue, throat and palate; each from "Its own real animal". Komodo walk: in game it played at about 2.17x its authored pace; "Slow him to the clip" (D-201: he moves only as fast as his animations show), roughly halving his walk speed. Asked how upgrades then work: "Size lengthens stride; speed unlocks a heavier gait" (size upgrades lengthen his stride at the same leg pace; speed upgrades raise cadence up to about 1.25x; the top speed tiers unlock a lumbering-run clip).

## 2026-10-25 · D-244 · Director · Real water; VIP escape headline

"water also counts as a flat untextured surface. Not for the first time, Im asking you for real water, it needs physics, and should react to things falling in it, it should have ripples, currents, reflections, whitecaps, moss, debris etc"; "larger bodies of water in the bay need waves too". Asked: build it in parallel with the ground texturing ("Run both at once"); the kaiju makes a "Full wake" (bow wave, trailing wake, tail-slam splash and rings to the banks); debris is his wreckage plus ambient litter plus small moored boats that rock and capsize; moss is a "Waterline on quay walls". VFX lead owns it; presentation only. Also asked: if the governor escapes, the headline is "COWARD {rank} ESCAPES THE CITY".

## 2026-10-25 · D-243 · Director · Trains, roar gape, claw trail, VIP headline, walk bob, next playtest

He asked to be asked more. Answers: trains "Keep running" as the kaiju nears (horn blares, no braking or fleeing); derailing pays a "Big one-off bonus" well above a car (a new tuning row he judges in playtest); the line is an "Elevated viaduct" on pillars so a derailed train falls into the street; after a derail survivors crawl out and flee (existing crowd people); Nimbalyst's API budget for trains is $60 on top of the ~$70 spent on 019-021 (stop at about $54; extends D-240). Komodo roar gape "35-40°" (clear air between the jaws). Claw rake "Faint, short trail" (thin streak per claw tip, fades in about 0.25 s). The VIP kill headline stays 3 s while play continues (no slow-mo). Young croc walk gets a "slight bob" on top of the small arm swing. The next playtest build comes "After the flat-surface pass" (P0-P2 textured), surveyed on the 4K TV only.

## 2026-10-25 · D-242 · Director · The visual vision critics judge by

He asked for a summary of what critics keep pushing or rejecting, then an interview "so we can align our visions". Answers: effects intensity "Elegant, restrained" (ambient effects support the scene and never compete with the kaiju; only his own attacks go big); reference vs style "True to reference" (match real animals and physics; stylise only where it does not read at all); visceral detail (drool, wet teeth, scars, gore) "Keep and celebrate" (never a defect; only checked for clean anchoring); framing "Wide: city scale" (as charge v10 at 36 m); timing at kaiju scale "Slowed for mass" (bigger is heavier and slower; small details such as the tongue and blinks stay near real speed); night "Dark and moody" (windows, lamps and fires carry the image; the kaiju reads by rim and fire light); critic vs his pick "You win, critic notes" (an approved trait is locked; critics flag defects only: pops, clipping, slits, stretch, flat surfaces, unreadable at 4K). Also asked: VIP headlines "COWARD GOVERNOR FLEES CITY BY CHOPPER" / "GOVERNOR SWATTED FROM THE SKY"; the governor's heli "Same size, lit"; young croc arms "Small swing" with the walk; intro skip "1 s".

## 2026-10-25 · D-241 · Director · Kaiju Creation ships with the dark lab room and all three serums

After the 020 clip: "looks great. change the black interior to a laboratory setting and its ready to ship"; "also load the serpent and dragon serum into the vials, and ensure the clip is functional for all 3". Asked: "Filled, still locked"; "Dark high-tech lab"; "3 clips, one per genome". On the dish: "make the dish metal a little less blocky, less speckled, more smooth"; "change the dish to be a more clear glass, less brown dirt". After the three 021 clips: "Ship it" (PR #192).

## 2026-10-25 · D-240 · Director · Nimbalyst builds trains; spend for it

Asked which medium task Nimbalyst takes next: "trains. he can have a fresh 1000 tripo credits, and he can make sounds on 11labs and he should research train locomotion and derailment physics". One rail line, a station and running trains that derail and smash (#63, #69 "Derail and smash"). Spend: up to 1000 Tripo credits (new, for the train set; board first), ElevenLabs train sounds (lead's cap 500 credits unless he says more), within the D-232 API cap. Brief: kaiju-mailbox to-nimbalyst/022-trains.md.

## 2026-10-25 · D-239 · Director · The Komodo's drool is part of its design

"the drool is a non-negotiable aspect of the Dragon's design". The lead had removed the drool threads from the idle and the game model on a critic's guess, reading his "disgusting" (meant: nearly 50 idle attempts) as being about the dragon; he asked "WHY ARE YOU REMOVING THE DROOL". The drool threads stay on every Komodo model, clip and stage; no session removes, hides or shortens them.

## 2026-10-25 · D-238 · Director · The charge's direction: Komodo charge v8 (a Godzilla-style forward-pitched run)

Shown the side-on charge v8 (lean 53-65° from vertical over near-standing hips, legs extended at push-off, arms from the shipped walk, a tail whip, an airborne lunge; matched to Godzilla x Kong 2024 side-on runs after v5 read upright and v6-v7 read as a low lizard scuttle): "dragon charge v8 is good, thats the right direction". Changes: v8's posture, lean and look are fixed; later rounds only fix defects (coil, held leap pose, no dead hold, framing).

## 2026-10-25 · D-237 · Director · Kaiju Creation lab sounds: ten clinical SFX from ElevenLabs, up to 500 credits

In Nimbalyst's session: "we need nice, clinical sfx for this scene, lab sounds and high-tech precision machinery whirring". Answers: the ten-sound list as drafted (room tone loop, screen chirps and heartbeat pulse, the injector boom's servo swing, the injector drawing liquid, injector servo whine and pneumatic hiss, needle click and electric snap, takeover crackle loop, overload surge to bang, dive whoosh, a real egg crack); source "ElevenLabs on your plan (Recommended)" (the D-138 route); spend cap "Up to 500 (Recommended)" credits. Picks via a loudness-matched shootout page; provenance in docs/provenance/sfx.md and LICENSING_REGISTER on claude/kaiju-creation.

## 2026-10-25 · D-236 · Director · Kaiju Creation: the injector does the work, Special K, hazard stripes on lab props

His sequence: "scene set - click genome (injector rotates to the croc vial, drains it, moves to dish and puts croc gene into dish - click kaiju juice (injector rotates to the kaiji vial and repeats above step) i do NOT want the vials magically flying over to the dish and pouring" (the flying, pouring vial was agent-added with no decision; removed). Injector: "Use image A whole" (the Tripo post, swinging boom and head; the rack sits within its reach). Special K: "Own canister on the bench", a hazard-marked glowing canister beside the rack (about 55 Tripo credits). Dish: "Glass dish in the cradle" (a low thin glass rim with agar in the approved cradle). Naming: "call Kaiju Juice 'Special K'"; the button reads INJECT SPECIAL K. Hazard stripes on the Tripo lab props: "Keep them (Recommended)", an exception to VFX_STYLE's "no UI colours in the world" for lab props only.

## 2026-10-25 · D-235 · Director · Kaiju Creation is rebuilt as a dark secret lab from Tripo props, up to 500 Tripo credits

Reviewing Nimbalyst's 019 captures: "you did a pretty bad job overall, why not use tripo?". What bothered him: "Props look cheap, Effect is weak, Whole thing too plain". Route for the lab props (dish, genome vials and rack, syringe or injector, bench and equipment): "Tripo Studio, browser" (existing Studio credits in the built-in browser, voxelised like the kaiju so the look stays one style, D-163). Spend: "Up to 500" Tripo credits for the lab props, a new cap not drawn from D-204 or D-213; stop and ask at 500 (330 used by the D-236 canister). Board first: "board first"; after a critic SHIP he picked "Build it (Recommended)": the dark secret-lab set, the croc's own white-hot lightning tearing through the genome in the dish, then the dive to black and the egg crack. Every Tripo task goes in docs/provenance/tripo.md on claude/kaiju-creation.

## 2026-10-25 · D-234 · Director · Komodo walking arms: pose C, forearms up and forward, claws reaching ahead

After w25 ("no looks like a clown. use video reference of bipedal kaiju arms") and w26 matched to the official Godzilla 2014 walk ("Still off": "Too stiff / frozen", "Pose itself wrong"), he picked "Raised and ready" (forearms at chest height in front, rocking with the body like a stalking predator), then from three still poses at the game camera picked C: "forearms up and forward, claws reaching ahead". Changes: refines D-233; the walk, idle and charge use pose C as the arm base, with the hands visibly moving every step. Method: a pose that misses twice is picked from labelled stills before any clip.

## 2026-10-25 · D-233 · Director · Komodo arms reach forward, ready to swipe (replaces D-229's hanging arms)

Shown walk w22 (arms hanging at his sides per D-229, critic SHIP): "arms lifeless like a zombie, i prefer his earlier pose of arms slightly outreached, prepared to swipe". Shown w21 (arms about 45 deg out to the sides, elbows bent, claws open): "no i want them facing more forward than that". Changes: the adult Komodo walk's arms reach forward ahead of the chest, slightly outreached, elbows a little bent, claws open and ready, symmetric, a small living swing; legs, torso, tail and footfall stay as w22.

## 2026-10-25 · D-232 · Director · Nimbalyst joins as a developer, Opus 5.5 Medium on the Claude API, $100 cap

His words: "I also have Nimbalyst connected to Claude API, you can use him as a developer"; "I will make him Opus 5.5 Medium". Asked how it gets work: a mailbox folder (`Documents/Nimbalyst Tutorial/kaiju-mailbox`, briefs in, results out). API spend: "100" (read as $100 in total until he says otherwise; it stops and reports at $90). First task: Kaiju Creation (D-207). Changes: one more builder outside the PC's engine cap count only while it runs Godot; the lead opens its PRs and merges.

## 2026-10-25 · D-231 · Director · Rig first: every model passes a rig check before any animation

After walk v18 (footfall jolt; "his torso sometimes contorts ... like he has no ribcage or internal mass at all"; "see how the width of his waist changes so dramatically ... as his leg moves forward"): "seems like we should be doing better skeletons and better rigging before we get to the animation". Asked; answer "Yes, rig first". Komodo animation pauses; its skeleton and skin are rebuilt (rigid ribcage, waist and flank on the pelvis, thigh influence only below the hip crease, shoulders hold volume) and a critic passes a standard grey-mesh pose sheet (spine bend and twist, leg and arm swings, neck, tail; waist width change at most 5%) before any clip. The same gate applies to the croc, serpent and mecha boss.

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

## 2026-10-21 · D-121 · Director · Camera growth: A (today's camera plus look-ahead); walk contact built now
Why: picked from the A/B/C stage-4 boards (kaiju 51% / 33% / 47% of screen height). Falling towers fade like standing ones.
The D-118 walk contact is built now, ahead of fire gameplay (his yes 2026-10-21).

## 2026-10-21 · D-122 · Director · Water = the R 21 plan (presentation physics), built after fire gameplay
Why: asked whether "proper water with physics" (#12) means the planned ripples, wakes, splashes and floating rubble with no
gameplay effect, or gameplay water or a fluid sim: the plan. Order: fire gameplay (R 26), then water (R 21).

## 2026-10-21 · D-123 · Director · One of the 3 cities is a water city; the octopus swims fast and can submerge
Why: his words, "im planning the octopus to be in a city with lots of water so it can move quickly through it". Asked: the water
city is one of the 3 every species plays; in water the octopus is fast and the others move normally; it can also dive to
dodge the army and burst out under buildings. Water becomes gameplay for the cephalopod (amends D-122's 'no gameplay effect').

## 2026-10-21 · D-117 · Director · Run timer stays 40 s at the start, 100 s at most
Why: Asked 2026-10-21 (R 1.2). No change to data.

## 2026-10-21 · D-118 · Director · Walking into buildings: small ones crumble; big ones take visible damage and tear easily with a little more effort
Why: His words 2026-10-21: "even big building should take visible damage, it should be easy for him to tear through them, it just requires slightly more effort / the game isnt meant to be extremely challenging or frustrating, its meant to be a thrill". Closes R 13.3.

## 2026-10-21 · D-120 · Director · The background skyline rampage stays after the slice (section H)
Why: Asked 2026-10-21.

## 2026-10-21 · D-119 · Director · Skins and body-part mutations are stretch goals
Why: Asked 2026-10-21 (customisation beyond species).

## 2026-10-21 · D-113 · Director · The game ends in a finale boss fight against a giant military mecha, after 3 cities
Why: Asked 2026-10-21 (open list: finale shape, how many cities). Changes: ROADMAP finale (R 23) builds a mecha boss; city count 3.

## 2026-10-21 · D-114 · Director · Music: Suno Pro (director's written yes to the spend; he subscribes and generates)
Why: Asked 2026-10-21 (Suno Pro vs ElevenLabs Music). Agents never enter keys; he generates, the lead cuts loops and registers licences.

## 2026-10-21 · D-116 · Director · Heartbeat sound: the director makes it in ElevenLabs
Why: Asked 2026-10-21; the lead gives the prompt and length, then wires and tunes it.

## 2026-10-21 · D-115 · Director · Fire: wind fixed per run; non-breath species light fires through tree augments
Why: Asked 2026-10-21. His words: "fire augmentation possible in the upgrade tree, i.e. insectoid 'searing venom' cephalopod 'flammable oil spray'". Fire as gameplay (R 26) is the next build after the current batch.

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

## 2026-10-20 · D-105 · Director · Camera framing C: low and cinematic
He picked C from four labelled framings of one seeded run (stills + 2x2 clip): rest offset (0, 16, 30), FOV 60 (was (0, 27, 19), FOV 55).
Why: build2-7 "the camera doesnt let us see much of the city"; C sees to the skyline and keeps the kaiju big. Changes: data/tuning.json "camera"; the run intro (Phase D) ends on this angle.

## 2026-10-20 · D-106 · Director · Every time of day, one per run
Asked which time of day the Cinematic look uses, he answered "all of them, except make morning less hazy and the night a bit lighter". Runs rotate dusk, night, morning, noon (run index from the save; the first run is dusk, the look as written).
Changes: data/looks.json "times" (overrides of look keys; morning fog 0.008 -> 0.003, night ambient 0.8 -> 1.4, sun 0.18 -> 0.35, lighter sky and fog), Content.set_time/time_for_run, Rampage.setup picks it.

## 2026-10-21 · D-108 · Director · The croc's breath is hot lightning, not atomic; its shape is a croc in a t-rex body
Why: research 02 flagged the upright reptile + dorsal plates + glowing breath beam combination as the Godzilla look; he
answered "we could have our croc shoot hot lightning instead of atomic theme" and "ours is like a crocodile in a t-rex
body, not godzilla shaped" (comments 2026-10-21 #7). Changes: Phase D b2-18 breath VFX and copy pass re-themed to forked
white-hot lightning (research 17); the halo colour is still his question (R 17.6).

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

## 2026-10-18 · D-086 · Lead · #36 option A (Behemoth army 0.03), void
Why: proposed for Behemoth defeats; superseded the same evening by D-087's pick and never applied.

## 2026-10-18 · D-087 · Director · The first evolution comes at about 15 minutes
Why (19:xx): "try to get the first evo earlier, no ones going to play 41 minutes of a demo if theyre still a baby";
picked "About 15 min" from 10 / 15 / 20-25. Lever: evolve1 cost 1778 -> 400 (#36, MERGED cceabba): 130 runs on the
real head give evolve1 0.26 h, young defeats 8/14, tree 82/87 at 3.37 h. The growth test ratio moved /10 -> /20.

## 2026-10-19 · D-084a · Lead · #55 trample: topple out, crush in place instead (rule 8)
Why: ten topple rounds failed; method change to crushing trees in place (debris, stump, footfall puff). Still after
the demo build per D-084.

## 2026-10-18 · D-085 · Director · Rooftop squads fire raggedly, never in unison
Why (via the rooftops session): "shooters arent firing in unison ... improvised, unrehearsed resistance". Seeded
ragged gaps per squad (51a2d5d); in #63.

## 2026-10-18 · D-083 · Director · After the demo, playtest fixes come first
Why (16:0x): director's call for after the demo build (P7 playtest); no new feature work jumps ahead of its fixes.

## 2026-10-18 · D-084 · Lead · #55 trample gets one last round, else the demo ships without it
Why (18:0x, same rule as D-082): r9 failed the critic (topple hidden by the body, sprite dust, see-through crowns, dark
stumps, falls along the tail). One more round; if it fails, greenery's trample is not in the demo.

## 2026-10-18 · D-082 · Director · #50 military AI gets one more round, else the demo ships without it
Why (16:0x): the fresh motion critic failed #50 (tanks skewed mid-street, helis firing nose-away). One last round,
and #50 ships only if it passes a fresh critic before #36 is tuned.

## 2026-10-18 · D-080 · Director · The jet strike warning scales with the kaiju's size
Why (15:4x): director's call on the jets PRs; applied on the jet branches (#58, #61).

## 2026-10-18 · D-081 · Director · Landmark rubble_bonus stays 4x
Why (16:0x): asked whether to change it; kept as built in the landmark sites work.

## 2026-10-18 · D-079 · Director · shell_hit keeps its full boom (A); #52 closed
Why: heard the A/B; kept A, the existing full boom. The alternative's PR #52 is closed unmerged.

## 2026-10-18 · D-078a · Director · The stadium stands are full of spectators watching the match
Why (18:0x): "the stadium needs to be full of people in the stands watching the sport, currently its empty".
Added to #59's brief; the AFL clip is re-rendered with the crowd.

## 2026-10-18 · D-073 · Director · Croc baby and adolescent approved
Why (10:5x): the P3 bodies from the croc titan design (D-059) are approved for the demo; clips kept, slam polish
later. PR #54.

## 2026-10-18 · D-074 · Director · Slow stage 1: the baby reads as a toddler
Why (10:5x): slow stage 1 so the baby reads as a toddler; pacing re-measured in the P3 PR (#54).

## 2026-10-18 · D-074a · Director · Baby speed ~0.6 with more hp; demo ~35 min
Why (11:4x): revises D-074 with a target; superseded by the measured numbers in D-074b.

## 2026-10-18 · D-074b · Director · Stage 1 at speed 0.6 and hp 1.15 (~43 min demo)
Why (13:2x): ~0.6 h to evolve1 is unreachable at 0.6 speed (the sweep floors at ~0.66 h). Accepted ~0.71 h: about
45% of early runs end in defeat and 87% of the city is destroyed by evolve1. PR #54.

## 2026-10-18 · D-075 · Director · Green lots at 8% of the city
Why (10:5x): answers D-065(b), the green-lot share tabled with its chunk and pacing table. City session, after
greenery (a).

## 2026-10-18 · D-076 · Director · Rooftops: more squads, firing more often
Why (10:5x): "more squads, more often". Cause found: rifle reach was measured from the kaiju's centre. Plan in D-076a.

## 2026-10-18 · D-076a · Lead · Rooftop density: reach from the stomp edge, more squads, a tenth of the chip
Why: for D-076 at the same threat. Option A: chip per volley scaled down per tier so each stage's damage per run
holds within ±5%; tanks unchanged; no HUD change (the hide spark is the hit read). PR #63.

## 2026-10-18 · D-077 · Director · The tree's stats panel shows only what the selected node changes, in plain words
Why (10:5x): the 12-number summary (STOMPS/S, RECHARGE, ARMOUR 0.0, SIZE 1 -> 2) read as software. Now the cost and
the node's own stats ("Stomps hit harder: 13 -> 16"), lines from data/tuning.json "stat_text". MERGED #51 (997f516).

## 2026-10-18 · D-078 · Director · Stadium matches: one random sport per run, players flee when the wall caves in
Why (14:1x): AFL, NFL, soccer or cricket, random per run; presentation only, low-effort visual flavour, in the demo.
Real cities make the sport deliberate later. Lands in #59 (landmarks session).

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

## 2026-10-18 · D-055 · Director · The croc roar plays on the evolution reveal and the demo end card
Why (04:35): heard roar_reveal.mp4; "ship it". Not layered under Atomic Breath, no new power. PR #8.

## 2026-10-18 · D-056 · Director · The kaiju earns and spends BIOMASS, not rubble
Why (05:08): "I don't like the concept of rubble as currency." Options: biomass (you devour what you flatten; evolving
is growing), terror, radiation, rename only. Picked biomass. Changes: player-facing words only (title Continue line,
pause, results "Biomass devoured", tree, HUD, upgrade desc, VISION.md); internal keys and the save field stay. In #27.

## 2026-10-18 · D-054 · Director · Zebra crossings only at the central avenue junction
Why (04:35): "remove the level crossing hellscape": zebras were painted at every avenue arm and mid-block. Now only the
avenue x avenue junction nearest the centre keeps them (city.zebra_junctions = 1; 0 = none); dashes and kerbs kept. PR #26.

## 2026-10-18 · D-053 · Director · Worktrees: one live worktree per live session
Why (04:30): the demo team runs six to eight sessions at once and the cap of four blocked work. The lead prunes dead
worktrees; tools/lint/worktrees.sh caps the total at 8. PR #25.

## 2026-10-18 · D-051 · Director · The evolution reveal is titled by the node bought
Why (04:20): after buying EVOLVE: Behemoth the reveal said "REPTILIAN ADOLESCENT"; now it says BEHEMOTH (the node's data
name), for every evolve node. Life-stage names stay internal. PR #23.

## 2026-10-18 · D-052 · Director · Demo SFX shipped as heard
Why (04:30): listened to three game-camera clips (stomps + footsteps, building collapse, Atomic Breath) with cracks
capped at one per 2.5 s and a footstep minimum interval; "ship as is". The 0.7 s auto-stomp rhythm is the sim's (D-004).

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

## 2026-10-17 · D-044 · Director · Locomotion paused until the kaiju models are decided
Why: "pause locomotion until we decide on the models because theyre doing work they might have to replace
if we change our models"; octopus capture showed "head detached, limbs a static, awkward mesh".
Changes: species-motion and kaiju-motion stop; PR #11 stays open, unmerged. The Blender motion test
(one hand-weighted rig on the Blender and Tripo reptiles) decides the model pipeline first.

## 2026-10-17 · D-043 · Director · Make the repo public to restore GitHub Actions
Why: Actions stopped starting jobs (account spending limit); options were raise the limit ($), run locally,
or go public (free minutes). Picked public. Changes: repo visibility public (the director flips it), main
protected per github-hygiene, failed CI rerun. Commit email and all code/docs become readable.

## 2026-10-17 · D-042 · Director · Military vehicles at 2x real size, desert tan; modelled in Blender
Why: tank board docs/captures/2026-10-17-vehicles/tank_board.png (modelled through the Blender MCP);
picked 2x (readable from the game camera beside a growing kaiju) and desert tan (olive goes near-black
in blue-hour light). Changes: TankModel uses the voxelized Blender tank; helicopters follow the same way.

## 2026-10-17 · D-041 · Director · Kaiju render as voxel cubes on a smooth skin (look test C)
Why: "its looking very rough so far, would this work better if our kaiju werent voxel?"; side-by-side
docs/captures/2026-10-17-look-test/look_test_abc.mp4 (A per-bone voxels / B smooth skinned / C voxel cubes
on a skinned lattice); picked C. Changes: one skinned mesh per kaiju, cubes move rigidly with their bone
over a watertight lattice: no joint gaps or speckle, keeps the voxel look. A kept as a debug fallback.

## 2026-10-17 · D-040 · Director · Ultimates get their own button
Why: picked "own button" over replacing the signature. Changes: E / pad Y, long cooldown (18 s);
the signature stays (the insect keeps Leap Slam for hold-to-glide). As built in PR #12.

## 2026-10-16 · D-039 · Director · The city grows with each evolution
Why: species-powers' pacing sim (tools/pacing.gd) clears the tree in 0.9 h because the one city is
flattened by run 11; the director picked "bigger city each stage" over a new city per stage or raised
costs. Changes: each evolution unlocks more districts, taller towers, harder defences; costs re-tuned
after that (a follow-up task); species-powers paces only its branches against the current curve.

## 2026-10-16 · D-038 · Director · Mantis skin = dark chitin, red eyes, rusty scythe tips; octopus baby 6176590f
Why: approved docs/captures/2026-10-16-stages/mantis_skin_v2.png ("Yes, use it"); the cephalopod baby
"i love him" (Tripo 6176590f, big round eyes). Changes: same mantis prompt on all three insect stages.

## 2026-10-16 · D-037 · Director · Species powers are upgrade-tree unlocks; hold-to-glide; helicopters
Why: "part of the upgrade tree, you forgetting this is an incremental, not a kaiju simulator"; hover =
hold jump to glide; helicopters yes. Changes: SPECIES.md answers; every power in it is an upgrade node
in a per-species branch (data/upgrades.json), ultimate at the branch end.

## 2026-10-16 · D-036 · Director · Cephalopod adult = the many-tentacled hydra (Tripo 8bf2f668)
Why: picked C on docs/captures/2026-10-16-stages/cephalopod_adult_options.png (10+ barnacled tentacles)
over the clawed 8-limb and the smooth octopus; fits SPECIES.md "limbs like the heads of a hydra".
Changes: the radial rig takes its tentacle count from the mesh; baby/adolescent keep the many-limb plan.
Also: a jaw bone for the reptile ("him opening his maw is a key part of his design").

## 2026-10-16 · D-035 · Director · Three species, three ways to play (docs/SPECIES.md)
Why: the director's species brief: reptilian = strongest (tail shears buildings, unstoppable momentum,
ultimate atomic beam); insectoid = fastest (scuttle, jump/hover, climbs towers, ultimate egg brood that
devours civilians and fights the military); cephalopod = most cunning (360 hydra limbs, grab and throw
tanks and helicopters, push/pull/climb/squeeze, ultimate corrosive ink). Changes: SPECIES.md is the spec;
build after locomotion (PR #10) lands; three open questions listed there.

## 2026-10-16 · D-034 · Director · Kaiju get real Tripo-textured skins; reptile = dark olive crocodile
Why: "i hope this isnt our final textured look"; "should be greener, less grey"; picked C (dark olive
middle ground) over B (bright green) on docs/captures/2026-10-16-stages/reptile_skin_options.png.
Also: "spend as many tripo credits as u want". Changes: rig_voxel.py samples the base-colour texture
when present; every stage of every species gets a matching texture pass (same prompt per species).

## 2026-10-16 · D-033 · Director · Kaiju growth stages picked
Why: stage board docs/captures/2026-10-16-stages/stages_board.png. Reptile adolescent = B (Tripo
f9cf6ba7, slimmer version of the adult); mantis baby 06ed8a12, adolescent 0161ad14, adult 9668b815
("yes, use them"). Changes: reptilian_adolescent re-rigged at 130 voxels; mantis rigs wait on the
hexapod skeleton (kaiju-motion).

## 2026-10-16 · D-032 · Director · Looks first, performance tuning later
Why: "lets worry later about frame rate/performance issues. focus on getting the best looking game
we can and then we can tune it". Changes: perf budgets no longer block visual work; benches are still
recorded in PRs (so tuning has a baseline) but a slower frame is not a reason to cut detail. A perf
pass comes after the look is locked.

## 2026-10-16 · D-031 · Director · Kaiju move like killing machines, each species its own way
Why: "the walking animation looks very wind-up-toy". Reptile = JP T-rex graceful deadliness (posture a
medium between Godzilla and T-rex, ~20-30° lean: "my t-rex comparison was mostly the gracefulness");
insectoid = disturbing skitter, twitches, exoskeletal motion; cephalopod = slides, pushes, pulls,
grabs building edges with tentacles, never tip-toes. Changes: helper kaiju-motion rebuilds rig
locomotion (foot IK, weight shift, tail counterbalance, hexapod and radial rigs).

## 2026-10-16 · D-030 · Director · SFX: free libraries, synthesized in-house where that sounds better
Why: "download the free stuff, synthesize in-house when we can get better results". Changes: Sonniss
GDC bundles, Kenney (CC0) and Freesound CC0 only; each source CLEARED in the licence register first;
no paid packs. Also: fullscreen now starts only in exported builds (a project-wide fullscreen start put
agent capture windows on the director's screen).

## 2026-10-16 · D-029 · Director · Real city districts from OpenStreetMap, starting with Melbourne CBD
Why: "could we have real cities with real layouts... imagine how fun it would be to destroy your own
city"; "the cbd alone would be plenty". Changes: helper real-city bakes districts offline from OSM
(ODbL, credited; never Google Maps, whose terms forbid it) at about 1/4 scale into the generic play
area. No player-imported cities, ever: new cities ship as patches (director, 2026-10-16).
TABLED (director, 2026-10-16): "focus on proofing the game before we expand to that feature";
the helper pauses at a clean point on its WIP branch.

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

## 2026-10-22 · D-143 · Director · Taskforce: railgun strength, arrival, new adult-city enemies, obsidian and electric blue

Adds to D-137/D-139. A railgun hit costs about 8% of the kaiju's health. First arrival: a ticker headline ("ANTI KAIJU TASKFORCE DEPLOYED") as the first squad's glowing jetpack trails streak in. No on-screen markers for agents. Aesthetic for all Taskforce troops and vehicles: "Obsidian with Electric Blue highlights". Every Taskforce agent can jump building to building with grappling hooks and jetpacks. Adult city adds new types: gas-grenade soldiers whose blue-black cloud locks special powers (e.g. the thunder beam) while the kaiju stands in it; knee-high walking mechs in the street, 3-4 at a time, firing laser-bomb volleys marked by electric-blue target rings about 1.5 s before impact, destroyed by stomp, claw swipe, a toppled building or the thunder beam; Taskforce gunships (obsidian, blue lights). The regular tanks and helicopters keep coming alongside the Taskforce. All of it ships before the Itch demo (asked: agents first and the rest after; he picked "All before the demo").

## 2026-10-22 · D-145 · Director · Demo is all three cities, ~90+ min; more Taskforce rules; roars, names, time of day

Asked 2026-10-22 ("ask me 20 questions"). Demo: includes the adult city (DESIGN's "hatchling to Behemoth" demo line is superseded); a first playthrough runs 90+ minutes; the end shows a thanks screen with rampage stats and a feedback link; the pause menu has a bug/feedback button that writes a report file with version and screenshot (no network calls); demo saves do not carry over to the full game. Taskforce: gas locks special powers only, the dash and every physical attack still work, and the cloud does no damage; mech bombs hit the kaiju and the city; the railgun line tracks the kaiju then locks shortly before firing, so a late step dodges it; several frost grenades refresh the slow, never stack; the dash shatters the ice early; gunships strafe with a blue laser cannon; squads arrive faster as more of the city falls; a destroyed mech blows up and damages nearby buildings; every railgun hit fires the post-effect colour fringe. Post effects: the red low-health pulse starts below 25% health. Title: one fixed view (not the player's current city); keep the BREAKING ticker. Layout: "move our main menu buttons achored to left of screen, keep the most visually apealling scene elements to the right of screen"; the logo sits above the buttons as one left column. Then his own layout (2026-10-23 mockup): a settings gear top-left; under the logo one row, a wide "Continue Game: <species>, <n> rampages" plus a smaller "New Kaiju?" (with no save, one wide "New Kaiju"); an exit button "Run for your life!?" bottom-right above the ticker; buttons in the worn industrial plate look. Colossus: "occasional explosions should reveal the sillhouette of the reptilian colossus obscured in the inferno" (supersedes the earlier silhouette removal); about every 12-20 s, and it moves slowly in step with the footfalls between reveals. Then: "the colossus silhouette could look a bit better though, more distinctive but less of a solid outline, give him red glowing eye (faintly) through the smog". Helicopter crews sometimes bail out by parachute. Load screens: a thin hazard-stripe progress bar. The signature beam is called "Thunder Beam for now but thinking of a better name". No roar button, but the kaiju "should roar more often, perhaps when he uses his ultimate power and/or a dash". Time of day: "the time of day will be randomised each run (a toggle available in the options menu to set a fixed time if players prefer)": random per run replaces D-106's rotation, with an options toggle for a fixed time; "random but cannot do the same time of day twice in a row".

## 2026-10-22 · D-144 · Director · Tanks caught by the longer breath just die

The longer baby breath trapped a retreating tank behind a parked one inside the danger radius; the lead had briefed a convoy re-plan, then a reverse-yield. Director: "think smarter, not harder, the tank doesnt need to avoid the breath, just let it die, even the most professional soldier wouldnt know to anticipate the breath in that moment". No convoy change; the military check counts only tanks that choose to park or fire inside the radius.

## 2026-10-22 · D-146 · Director · Playtest milestones replace per-change clips and approvals

"we are wasting our time making so many clips, its better for you to build, then i play and you give me an exhaustive survey to fill"; then "not NO more clips, but not so many, and i dont want to play every single update, you need to identify milestones in the roadmap that justify my playtest and craft a survey for that game state". Picked 4 milestones (ROADMAP "Playtest milestones"): M1 feel pass, M2 Taskforce agents, M3 demo complete, M4 Itch release candidate. Builds are exported .exe files in a fixed folder. The lead merges green, critic-passed work without a director gate.
