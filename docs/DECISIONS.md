# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. Only the merge role edits this file, from the "Board and log" section of merged PRs.

## 2026-10-23 · D-188 · Director · Visual reviews keep going until the critics pass; repeated failure changes the method

He asked "are we in clip making purgatory again?" (the fire and helicopter look at round 7, the new breathing failed its first review as invisible at the game camera, the walk fix failed twice on the swivel). Asked how visual reviews run until M1, he chose "Keep going until critics pass": no round cap; critics keep failing merely acceptable work, so the M1 build shows finished visuals. Then: "but if something has failed 7 times in a row then our method is wrong, and needs to be reassessed": two failed rounds in a row (CLAUDE.md rule 8) mean the owner stops, finds why each round failed and changes the approach before the next round. The fire and helicopter look is reassessed before any round 8. Not chosen: two rounds then M1; fewer clips with the same rounds.

## 2026-10-23 · D-187 · Director · The big forms turn heavier and slower

The walk fix failed its motion review on the swivel he named ("he swivels rather than turns"). Measured: the sim turns the Behemoth and Colossus at peaks of 260-311 degrees a second, each step's yaw squeezed into its planted window, so the body snaps round on planted feet; the snap also swings his position 8-13 units about the planted foot (the lunge that lets him catch helicopters). Asked: "Heavier, slower": turns grow slower with size, a U-turn about 1.5 s for the Behemoth and 2.5 s for the Colossus (about 1.2 s for both before, in snaps), spread evenly over the steps. The young croc keeps its smooth turn (D-131) and small corrections stay smooth (D-130); amends D-130's "the turn rates stay as they were" for the two big forms. The lead re-checks the 10 s rise-point bar (D-131); a clip comes before it merges. Not chosen: same speed without the snap; keep as is.

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
