# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. Only the merge role edits this file, from the "Board and log" section of merged PRs.

## 2026-10-27 · D-328 · Director · Interview: tail, night, lab, skins, crowds, turn, ElevenLabs, night calls
Tail (asked whether the button tail lash, D-280, is the same move as the automatic tail whip from a tree node, D-259):
"remove the automatic whip, repurpose the nodes to improve our button whip". Night (D-106/D-145 "lighter" vs D-242 "dark
and moody"): "Tonight's look" (D-285 stands; the older wording is retired on this point). Kaiju Creation lab scene:
"Both" (a new save and each new species). Skins earned by playing: "Both" (each form reached, and rampage records).
Crowds speed-up (render plan item 7): "Keep trying (Recommended)" if the second method misses. Heavier turn (D-187,
Behemoth seed 1234 takes 11.9 s to flatten the buildings by its rise): "Keep it heavy"; the test bar is fitted to it.
ElevenLabs: "I'll sign in" (the lead reads the four train sounds' generation ids for the licence register). Night calls
(night_calls.md): "All fine". Not asked, lead's call from D-326: rooftop soldiers near the camera stay undrawn.

## 2026-10-27 · D-327 · Director · Physics destruction ships with the demo; render items 10 and 11 are built with it
Q: real-physics destruction (D-094: carved buildings, loose pieces topple and fall) is planned after demo build 2;
keep that timing or build it sooner? A: "WTF do you mean render items come with it, render is our number 1 priority,
stop fucking with me. the destructions ship with the demo, the destruction is the game". So: D-094's "after demo exe 2"
is reversed; real carving and falling pieces ship in the demo, and render plan items 10 and 11 (the physics speed-ups,
D-311) are built now as render priority 1 work, not parked. Corrects D-311's correction note.

## 2026-10-27 · D-326 · Director · Never fade out the destruction; audit cuts and keeps
Q: falling chunks of a toppling building fade out when they pass between the camera and the kaiju; keep or cut? A:
"Cut. ive said a thousand times, its ok to obscure the kaiju, its not ok to block the camera, please stop asking me
questions about this, please stop making buildings fade out, the destruction IS THE GAME, NEVER FADE OUT THE
DESTRUCTION". So: no falling, toppling or broken piece ever fades or goes see-through; it may hide the kaiju. Only a
wall that fills the frame at the camera is handled, by the D-283 bubble. Never asked again. Same batch: the sound duck
"Keep, not stomps" (roars, big collapses and barrel blasts still duck the mix; footsteps do not); the barrel-blast white
screen flash "Cut" (ring and delayed boom stay, his #19/#20); low health "Vignette only" (the red edge band goes, D-142).

## 2026-10-27 · D-325 · Director · Intro camera behind the kaiju; real, textured water with physics now
Intro clip (#245): "the scene is fine but the camera needs to pivot out to be BEHIND our kaiju". Then: "water is still
a textureless, depthless colour so it looks like hes floating in a void, we desperately need to beautify our water and
add real physics to it like ive said a dozen times" (his #12 10-20, D-122, D-244, D-245: swell, ripples, currents,
reflections, whitecaps in storms, his wake, splashes and floating debris, moss on quay walls; looks only, reviewed after
each step). So: water is built now, starting with the surface (texture and depth), not parked behind other work.

## 2026-10-27 · D-324 · Director · Looks: Tripo vehicles recoloured; smoke, walls, windows, far city, facade kept
Tripo tank, gunship and governor's helicopter: "yes they look good but recolour them to be less TAN and more generic
military colour". Soft smoke (P4b): "Keep it". Building walls: "B: soft corners" (P4a on). Lit windows: "B: lived-in"
(#301 stays). Far city at night: "Fog + reflection" (both far-city PRs; the glow is re-measured with #301's window
colours). Facade carve (#288): "impossible to tell from the clip, but ship and ill test in play".

## 2026-10-27 · D-323 · Director · Kaiju death: jagged stone chunks replace the cubes; the 0.2 s wait stays
On #240's clip: "you didnt change the blocks that i said i hated. you just changed their colour, but the bllocks are
stupid and look bad". Q: what should fly out of his body? A: "Jagged stone chunks" (irregular broken rock in his
hide's texture, many sizes, tumbling with dust; keeps D-294's shards first). Blast wait 0.2 s: "Keep 0.2 s".

## 2026-10-27 · D-322 · Director · Interview batch 1: roar and solid vehicles kept; window flicker not solved
Roar (#276): "Keep it". Vehicles always solid (#279): "keep it. shouldnt even be a question, no other choice makes any
sense" (a fix that carries out his own ruling is never put to him as keep or revert). Window bars (#274, D-303): "didnt
solve the issue, theres still flashing/stuttering lit windows" (second miss on his 10-26 comment; method changes:
measure the flicker in motion first).

## 2026-10-27 · D-320 · Director · He adds the Windows Defender exclusions for the game folders himself
Q: will you exclude the game folders from Defender scanning (agents cannot change security settings)? A: "Yes, I'll
add them (Recommended)". Folders given: the repo, `Kaiju-Incremental-wt`, `C:\kt`. Agents never change it themselves.

## 2026-10-27 · D-319 · Director · A finished change runs its full test check on GitHub first
Q (after "whats the point of having so many helpers if most of them are waiting half a day to work"): where should a
finished change run its full test check before it goes up for merge? A: "On GitHub first (Recommended)". So: the
local full prepush stops being the gate. A builder runs the cheap local gates (no Godot), pushes, and GitHub runs every
shard on the branch (`C:/kt/gh_check.sh`, one lead watcher); the PR is ready only after that passes, so no red PR
shows. Builders still run locally only the suites they iterate on. Replaces the local-prepush gate (D-186 stands).

## 2026-10-27 · D-318 · Director · If Cascadeur freezes: save Dracorex as a copy, then restart
Q: if Cascadeur freezes while his Dracorex scene is open, may the lead save Dracorex as a copy and restart? A: "Yes,
copy first, then restart (Recommended)". So: only on a real freeze (no response for 10 min, PID 22276), Save As a new
file name (never overwrite his file), then restart Cascadeur and reopen the copy. Narrows the never-restart rule.

## 2026-10-27 · D-317 · Director · Tonight: keep the 6 GB memory floor, drop the 85% CPU cap
Q: the PC rule (nothing new under 6 GB free RAM or above 85% CPU), tonight? A: "Keep memory floor, drop CPU cap
(Recommended)". So: the RAM floor (freeze guard) stays; the CPU cap is off for the night shift.

## 2026-10-27 · D-316 · Director · Export a playable build at the end of the shift
Q: export a build at the end of the shift? A: "Yes, in the usual build folder (Recommended)". So: a demo .exe from
main in the fixed build folder before he wakes, with a short note of what merged overnight.

## 2026-10-27 · D-315 · Director · No usage cap tonight
Q: weekly limit 17% used; how much may tonight use? A: "Whatever the work needs (Recommended)". No usage stop tonight.

## 2026-10-27 · D-314 · Director · Opus at high effort for the hardest builds tonight
Q: Opus high for the hardest builds (new engine code, kaiju posing, tail and toe skeleton)? A: "Yes, hardest builds
only (Recommended)". So: Opus high only for P2a, P3a, P3c, P4c and the r21 rig work; everything else stays as is.

## 2026-10-27 · D-313 · Director · Speed runs keep the PC to themselves tonight
Q: keep D-299's ~3 min sole-PC turns tonight? A: "Keep it (Recommended)". D-299 stands through the night shift.

## 2026-10-27 · D-312 · Director · Item 15: the speed savings buy a quieter, cooler PC
Q: what should the headroom buy at Medium? A: "A quieter, cooler PC (Recommended)". So: same look at 60 fps with the
GPU working less (D-093's reason for Medium); no render-scale rise. Closes render plan item 15.

## 2026-10-27 · D-311 · Director · Render plan items 10 and 11 build tonight, last in the plan
Q (06:2x): items 10 (native collider rebuild, no freeze on big stomps) and 11 (no stutter when a tower starts to fall),
parked until after the demo by D-094, build them tonight? A: "Yes, last in the plan (Recommended)". So: both go in
after every other render-plan item, each proved by a D-299 speed check. Reverses D-094's "after demo exe 2" for these two.
Correction (lead, 06:18, director away): not built. The question described both wrongly: the code they speed up (carve physics) runs only in a capture tool, never in the shipped game (checked on main b0fe3687; the baseline measured 0 ms there), so neither changes what the player sees. Back to him at the next interview (D-094 option A, full-game destruction, would bring them back).

## 2026-10-27 · D-310 · Director · Parked work starts tonight, after the debt fixes
Q (06:1x): work parked until the render plan is done (D-276: roads, play area, camera bubble, rubble, stomp rework,
Tripo buildings), start it tonight? A: "yes, but not before the debt fixes". So: parked items start tonight once every
D-295 debt row is done (merged), in the set order (roads #243, then play area #241, then intro #245, then the rest).
Refines D-276.

## 2026-10-27 · D-309 · Director · Up to 1,000 more Tripo credits tonight, any task
Q (06:1x): Tripo credits tonight? A: "Up to 1,000 more, any task". So: on top of D-297's vehicle budget (600, 260 used
at 05:3x), up to 1,000 more credits may be spent tonight on any outstanding Tripo task (vehicles, buildings,
beachfront). Every task id, credits and verdict logged in the provenance file; Private on every generation.

## 2026-10-27 · D-308 · Director · Night shift: visual changes go into the game; he judges them next morning
His words (06:1x, before sleeping): "any visual work is fine but after the first iteration save it and show me in
interview tomorrow". Q: should visual changes made tonight go into the game before he has seen them? A: "In the game,
you judge tomorrow (Recommended)". So: tonight's visual PRs merge on by default after one iteration; each keeps a saved
1080p clip or 4K still in C:/kt/interview_2026-10-27/ for the morning interview; anything he rejects is reverted. No
second visual rounds without him. Overrides, for this night only, the director look gate on merges.

## 2026-10-27 · D-307 · Director · The croc skeleton may gain bones to match the Dracorex
Q (05:3x): may the croc gain bones (more tail or neck joints)? A: "Yes, add bones if needed (Recommended)".
So: bones are added where the study shows the croc lacks them; the croc is re-skinned and the approved roar, idle and
turns move to the new skeleton, each shown to him again in a clip before it replaces the old one.

## 2026-10-27 · D-306 · Director · Recreate the Dracorex walk with its methods and our own keys
Q (05:3x, his request "look at every single frame of the dracorex walk loop and apply those learnings to our models
skeletons / take of the settings and techniques used in that dracorex file and try to recreate it with our model"):
same methods with our own keys, or copy its motion? A: "Same methods, our own keys (Recommended)".
So: every frame of the sample walk is studied and its settings and techniques (controller layout, key grid, curve
types, tail and neck set-up, timing) are copied; the croc walk is keyed fresh. No key, curve or pose from the sample
(licence not cleared) enters our files. Refines D-302.

## 2026-10-27 · D-305 · Director · Our animator works inside his open Cascadeur
Q (05:3x, after "casc is open"): use his open copy, or he closes his? A: "Use my open copy (Recommended)".
So: the Cascadeur builder runs its script server inside his running Cascadeur and opens its own tabs beside his
Dracorex file. It never closes, edits or saves his file, and never takes his keyboard or mouse (no window activation,
no clicks). Owner: croc moves builder (row 21).

## 2026-10-27 · D-304 · Director · Clips render at 1080p; stills stay 4K
Q (05:0x, after he asked "why do we need to capture things in 4k? surely that takes much longer and uses more gpu?"):
switch clips to 1080p? A: "Clips 1080p, stills 4K (Recommended)".
So: every ~6 s clip renders at 1920x1080; stills keep the 3840x2160 check for text and fine detail. The first 1080p
clip is timed against a 4K one so the saving is measured, not assumed. Replaces the 4K-clip wording in briefs.

## 2026-10-27 · D-303 · Director · Balcony railings take the window-sill tone
Q (05:0x, with the window-bars 4K A/B, C:/kt/wb_old/ab2.png): the short black bars under the windows on brick towers are
balcony railings (palette key "rail", 2a2c2e, 2 voxels proud); they stay pitch black at night and slide over the windows
as the camera moves. Leave, lighten to sill tone, or drop? A: "Lighten to sill tone (Recommended)".
So: the rail voxels use the window-sill colour; brick towers keep their balconies. Owner: window-bars (PR #274).

## 2026-10-27 · D-302 · Director · Croc walk reworked from the Dracorex study; size-matched steps
Q (after the Dracorex study he asked for at 03:5x, "maybe you should study this and take some learnings from it"; numbers in C:/kt/dracorex/learnings.md): rework the approved walk with the learnings? "Rework, send a clip (Recommended)". How fast should his legs step at his normal walking speed? "Size-matched, ~1.4 s a step (Recommended)".
So: the Cascadeur builder (debt row 21) rekeys the croc walk to the study's bars: a steady head (heading range <= 25% of the trunk's twist, bob <= 70% of the pelvis, 2-4 f late); the neck lifting as the body drops (r <= -0.5, >= 3 deg range); the chest swinging against the hips (S-shaped spine); the tail tip trailing the base by >= 0.25 cycle, swinging wider toward the tip; feet that peel (ankle peak 15-30% into the swing) then reach (toe peak in the last 20%); planted feet still slide <= 1 cm. Sizes the study left open (trunk twist, tail swing, bob) sit between today's croc and the sample; he judges ONE ~6 s side-on clip, and today's walk stays in the game until he approves the new one. Tempo: same ground speed; a cycle of ~2.7 s (a step ~1.35 s, stride ~15 m) instead of 1.10 s and 6.06 m; the sim's footstep cadence follows the clip (D-201); damage under his feet is re-tuned so the street clears per metre walked as it does today. Not chosen: keep the walk and use the learnings for new moves only; halfway (~0.95 s a step); today's ~0.55 s a step. No key, curve or pose from the sample enters the game (licence not cleared): measurements only.

## 2026-10-27 · D-301 · Director · Cascadeur bought just before release; trial clips re-exported under it
Q: the release build would ship clips keyed on the Cascadeur Pro Trial, whose EULA (2.2(e)) "prohibits any Commercial Use". Answer: "as long as we can use our trial animations after I pay, im happy to wait still a long time left on the trial".
EULA (cascadeur.com/download, read 2026-10-27): Indie (gross revenue under $100k/yr) and Pro permit Commercial Use; the licensee keeps ownership of its animations (6.3); it says nothing either way about trial-made work after upgrading. So: keep working on the trial; buy before the Itch release; at purchase re-open every clip's .casc in the paid Cascadeur and re-export it, so every shipped clip is exported under a paid licence; every clip keeps its .casc source; credits name Cascadeur (EULA asks for it). Release checklist item.

## 2026-10-27 · D-300 · Director · Debt fixes go ahead of the render plan
His words: "maybe we should prioritise the debt fixes" (after the third local freeze tonight and P2b's speed runs swinging 63-81 ms). Asked "Should debt fixes go ahead of the render plan?"; picked "Debt first": debt PRs merge first and get the next speed runs; the Cascadeur remake of the 31 code-driven creature moves (debt row 21) starts now instead of after the render plan; render builders already working finish their items; later render items start after waiting debt. New order: 1 debt, 2 render plan, 3 everything else. Replaces D-298's order.

## 2026-10-27 · D-299 · Director · Each speed run gets the PC to itself
D-292's check failed: the same freeze-fix build measured 59.47 ms (95th-percentile frame, High) alone and 72.54 ms with 11 headless test runs beside it (+22%; two clean main runs differ 0.1%). Asked "Should each speed run get the PC to itself for its 3 minutes?"; picked "Yes, PC to itself": while a speed run holds C:/kt/BENCH_WINDOW_<owner>, no other Godot starts, headless included (2 min 49 s per run, measured). Enforced by the tool-gate hook (refuses Kaiju Godot launches without C:/kt/wait_window.sh) and by drive_timing.sh (waits for zero Godot, records others=N; a run with others>0 does not count). Replaces D-292's headless-beside rule. Not chosen: keep tests beside; try top CPU priority first.

## 2026-10-27 · D-298 · Director · Priority order: render plan, then debt, then everything else
His words: "priorities are 1. render plan 2. debt fixes 3. everythin else". Where work competes (speed-check turns, merge order, builder slots, the lead's attention) the render plan (D-276) goes first, the tech-debt list (D-295) second, all other work third. Parked work stays parked ("Render plan first").

## 2026-10-27 · D-297 · Director · Tanks and helicopters remade in Tripo, up to 600 credits
His words: "i think our helis and tanks look untextured too, they look procedurally drawn rather than proper models". Asked how to remake them; picked "Tripo, up to 600 credits": the tank, the gunship and the governor's helicopter are generated in Tripo Studio (HD model, Private every generation, balance checked before and after), split into the parts the game moves (turret, barrel; main and tail rotor, gun), shown to him from six views, then voxelised into assets/vehicles. This is his written yes for up to 600 Tripo credits on vehicles. Debt row 24.

## 2026-10-27 · D-296 · Director · No builder count: as many as the PC and tests allow
Asked "so what are these slots? is it a guardrail hallucination?" (the "at most 3 builders" rule had no quote of his behind it; his 10-21 words were "use as many sub agents as you want, up to 8"). Answer: "idc how many, use 100 if its not going to ruin the tests / use as many as is feasible". The machine gates stay (nothing new under 6 GB free RAM or above 85% CPU, one speed check at a time); on a PC freeze find the cause before cutting builders. Rulebook "Kaiju team" line replaced. Replaces D-278 and D-287.

## 2026-10-27 · D-295 · Director · Every tech-debt item is actioned
Asked "does our project have a proper tech stack and good codebase hygiene", then: "I want the FULL list of debt items, i want them all actioned". Picked "After facade+vehicles" for the hygiene builder. List: docs/roadmap/2026-10-27-tech-debt.md (from C:/kt/debt/debt_list.md), every row owned and closed by a PR.

## 2026-10-27 · D-294 · Director · Death: his stone shards land first, then the blast
Asked (02:5x, on the death clip with all 3 Death Blast nodes): "Shards first": his falling stone body smashes buildings, then the blast clears the rest; both visibly destroy things. Not chosen: blast first (as built, shards hit only rubble). Same look: "i dont like the pale blocks that come out of the explosion" (plain untextured cubes; fix in the same PR #240).

## 2026-10-27 · D-293 · Director · The rule audit covers workflow rules too
Asked: "Yes, add workflow rules": the D-291 audit also lists every workflow rule we follow (RULEBOOK, CLAUDE.md files, briefs) with its source, his quote and date or "agent-made", for him to keep or cut each agent-made one. Not chosen: game behaviours only.

## 2026-10-27 · D-292 · Director · Background tests run beside speed checks
His words: "sometimes a hallucinated guardrail will handcuff our progress even though i never would have wanted to use that guardrail". The lead's own rule "timing benches run with no other Godot" (CLAUDE.md, #255) held four builders idle 01:50-02:24 for ~15 min of benching. Asked: "Yes, let them run": headless Godot runs (tests, imports; no window, no graphics) go ahead while a speed check runs; only windowed/GPU Godot waits for it. Check once: if a speed check's whole-route p95 moves more than 1% with a headless suite beside it, the lead brings it back to him (two clean main High runs differed 0.1%: 55.29 vs 55.23). Not chosen: keep the full stop.

## 2026-10-27 · D-291 · Director · Audit what agents built from loose readings of his rulings
His words, on the vehicle fade agents had stretched from D-025: "im certain id never have agreed to that if id understood what you were proposing". Asked: "Yes, audit now": a Sonnet reader lists every behaviour the player meets that an agent built beyond the words of a ruling, or with none, each with a still from the real game (C:/kt/rule_audit.md), for him to keep or cut item by item. Every question to him says what he will see on screen in plain words, with a picture or clip of the real effect when it is visual. Not chosen: not now.

## 2026-10-27 · D-290 · Director · Vehicles never go see-through
His words, seeing the governor's heli ghost over a tower: "the governers heli sometimes blends into the buildings, as if it is translucent"; told the screen-door fade on tanks and helis was an agent's extension of D-025 (smoke) with no decision of his: "why would any vehicle ever go see through?". Asked: "Remove it": VehicleFade goes; every tank and helicopter, the governor's included, always draws solid. Smoke keeps clearing over the kaiju (D-025). Building fades are D-283's bubble rework. Not chosen: keep it for regular vehicles.

## 2026-10-27 · D-289 · Director · The facade jump on the first carve is fixed in the next free slot
His words (watching runs): "when a building gets carved anywhere, its whole facade changes texture, so even if you carve the bottom of a tower, the top of the tower is changing appearance too". Asked: "Next free slot": a Sonnet builder (briefs/brief-facade-carve.md) takes the next builder slot that frees, ahead of the remaining render-plan items; pass bar: the untouched part of a carved building does not change (upper-half pixel diff mean <= 1/255, p99 <= 4/255), a headless check that fails on main first, one clip to him. Not chosen: a 7th builder now; after the render plan.

## 2026-10-27 · D-288 · Director · Death Blast upgrades: Overload, Meltdown, Supernova at 2,540 / 8,128 / 17,780
Asked (PR #240, agent-added values): "Keep them" for the names Overload / Meltdown / Supernova and their card text ("Go out with a bang: when you fall, you take the street with you" / "A bigger bang: your last breath flattens the block" / "The biggest bang: nothing near you outlives you"); "Keep" for costs 2,540 / 8,128 / 17,780 biomass (the steps of Signature Recharge levels 1 and 3 and Crushing Weight's top level). Not chosen: his own names; costs x2 or x0.5. The death look waits for the clip.

## 2026-10-27 · D-287 · Director · Six builders tonight: P2b and P2c start now
His words: "speed up our work, make sure our pc is able to manage the workload". Shown: 17 of 31 GB RAM free, CPU 34% of 16 threads, GPU idle. Asked: "Yes, 6 builders": render plan P2b (crowds, item 7) and P2c (pooled effects, item 8) start as builders 5 and 6 beside death overload and army balance; back to 4 on any PC freeze (replaces D-278's 4). Timing benches still run with no other Godot, in bench windows (C:/kt/BENCH_WINDOW* flag files builders respect). Not chosen: keep 4.

## 2026-10-27 · D-286 · Director · The freeze fix merges at its speed check; the soak checks it after
His words: "i dont want to wait til 7am if possbile". Asked: "Merge at speed check": PR #254 merges once its p95 speed check passes (fix within 5% of main) and CI is green, instead of after the D-282 soak. The soak keeps running (fix runs 1-10 run 40331611227, 11-20 run 40342907172 on soak/fix-b; main run 40331600221 until one freeze); any fix run that freezes means #254 is reverted at once. D-282's pass bar (main >=1 freeze, fix 20/20 clean) is unchanged, only the merge comes first. Not chosen: wait for the soak (~04:20 at the earliest).

## 2026-10-27 · D-285 · Director · New colour grading and both clean-ups ship (render items 3 and 4)
Shown 20 labelled 4K stills of the real game (item 4: night, dusk, morning and noon, current vs new; item 3: night fog, night lamps and dusk sky, each off/deband/sharp/both). Asked: "should the new colour grading ship?" -> "New grading" (AgX 1.6, post contrast 1.0, night tone split; night pure-black area 9.9% -> 0.2%, mid-tones within ~1%). "which clean-up should ship?" -> "Both" (debanding + FSR sharpening). All on by default in #257 with D-279's night fog. Not chosen: keep current; deband only; sharpen only; off.

## 2026-10-27 · D-284 · Director · No floating biomass numbers

"the biomass numbers also visible THROUGH te buildings and kaiju isnt great"; then, on a screenshot of +numbers sprinkled over the croc's tail (docs/captures/2026-10-26-clips/numbers_over_kaiju.webp): "i dont want to see the numbers. i want to see kaiju". Always-on-top numbers were agent-added at the greybox kickoff (8d02a024), no decision. First pick "Hidden behind it", then asked again: "Remove them entirely". Every floating +biomass number goes (callers in rampage.gd, rooftop_view.gd, rail_view.gd, tank_fx.gd); the biomass counter and its tick-up are the only readout. When: "With the bubble" (D-283), after the render plan.

## 2026-10-27 · D-283 · Director · Camera bubble after the render plan

"see why we need the bubble", "the bubble would solve unsightly views like the above" (screenshots: a building wall filling the frame; the screen-door fade over the croc at night, wall: docs/captures/2026-10-26-clips/bubble_why_wall.webp; the screen-door one was not saved to disk). Asked when to build it; picked "After the render plan". Rework #238 (solid by default, cut away only the 0-3 buildings between camera and kaiju, shadows kept); his two screenshots are the pass bar (no wall fills the frame, no screen-door over the kaiju); the clip goes straight to him. Re-asked 00:58 while League blocked the speed benches (start it now in the gap?): "Keep it after the plan".

## 2026-10-27 · D-282 · Director · The freeze fix's 20-run test runs on GitHub first

His question: "is it possible to do this on github instead?". Asked: "Yes, GitHub first": 20 runs on main and 20 on the fix on GitHub (software rendering, free on the public repo); main must freeze at least once there to prove GitHub catches it; then 20/20 clean on the fix passes. If main never freezes there, the test returns to the local GPU. Speed benches and stills stay on the local GPU (no GPU on GitHub). Not chosen: keep local, both.

## 2026-10-27 · D-281 · Director · The charged stomp becomes the dragon's attack

His words: "stomp fits the dragon more than the croc". Asked: "Yes, dragon's kit": the tap/hold charged stomp (D-260, D-263), its 0.80x speed and Frenzy speed-up (D-264) move to the dragon's design for when dragon work resumes (paused, D-25x); the dragon gets its own Cascadeur clip.

## 2026-10-27 · D-280 · Director · Croc: the stomp turns automatic and weak; a tail lash takes its button

His words: "we should probably revisit the stomp attack and replace it with something else, make stomp damage weaker and automatic / a stationary stomp goes against the croc's power fantasy as an athletic kaiju". Asked: auto stomp "Every footfall crushes" (damage under his feet as he walks and runs, never stops to stomp); power "Street-level only" (people, cars, trees, props underfoot; buildings only chip); the button "Tail lash" (mid-stride tail whip flattening a ring beside him, never breaking his run; Cascadeur clip); timing "After the render plan". Replaces D-260 "Button replaces it" and D-263 "Rooted while charging" for the croc. Not chosen: rhythm stomps, chipping buildings, death roll, lunge bite.

## 2026-10-26 · D-279 · Director · Night sky: fog matched to the sky (B)

Asked with 4 labelled 4K stills (docs/captures/2026-10-26-clips/night_sky_A-D.png) after his "too much white in the blue ... the lighting or the fog": "Which night look should ship?" Answer: "B: fog matched to sky". Night fog_color 1e2a46 -> 0c1428 (= sky_top); ambient stays 1.4. Measured sky luma 9.5 -> 1.9, facades 39.5 -> 38.3. Not chosen: D both, C dimmer buildings, A keep.

## 2026-10-26 · D-278 · Director · Builder cap 4 for tonight's render plan

Asked: "Can I run 4 builders tonight instead of 3, so the night-shadow, clarity and night-sky batch starts now?" after he said "wow, thats so slow, anyway we can speed it up?". Answer: "4 builders tonight (Recommended)". Kaiju cap is 4 builders + 1 Sonnet reader for tonight; drops back to 3 if anything freezes. Not chosen: 5 builders, keep 3.

## 2026-10-26 · D-277 · Director · Beachfront round 2 kept; defects fixed in Blender; nightclub V03r

Round 2 (D-274's change of method: a reference image first, HD H3.1 chosen by a measured pilot over Smart Mesh, Remove Lighting; 1,365 of the 1,600 credits, balance 5,955) shown as a labelled board with the three round-1 keepers. He picked "All usable, fix defects": all 19 (B01-B07, V01, V02, V03r, V04-V06, S01-S04, P01, P02) go into the beach district; thin canopies, awnings and umbrella poles are thickened and blank backs filled in Blender, then voxelised. Nightclub: "V03r, no sand base". Blender fix waits until the render plan's Godot runs are done (D-276).

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
