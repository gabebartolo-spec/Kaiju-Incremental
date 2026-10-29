# Decisions log

Cap: 400 lines; oldest roll to `docs/archive/`. One decision per entry, newest first. A decision
that is not here does not exist. Format: date · id · who decided · the decision · why · what it
changes. The lead owns the wording; a decision goes in the PR that acts on it (any PR may carry it).

## 2026-10-30 · D-388 · Director · Landmarks carve on cells
Q (ROADMAP 4, "carve is universal", director 2026-10-26): landmarks broke by chunks only (Carving.takes skipped them).
Now a landmark promotes to its LandmarkCells grid on its first hit and blows carve its cells like any building's. A
ring landmark's arcs (the stadium) keep the chunk rule on cells: once an arc has lost arc_shed_cells cells, its
section above the stub comes down as one topple over the stub's edge (rim outward, stands inward) before the support
settle. Landmarks keep their cut side (D-387). River and bay bridges still render as decks, not carved buildings.

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

## 2026-10-29 · D-383 · Director · No local test runs: push and CI is the test
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
8,802). Everything else, motion and smoke included, runs on every PR. The list is the `pr_skip` line of
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

## 2026-10-28 · D-373 · Director · The river intro is dropped; the beach start ships straight onto main
His words (10-28 ~18:2x): "im sick of seeing runs start in the river. when will our beach front patch hit the godot
runs?"; "why would river intro - a scene we nixed and dont require any further build - go before our planned ship?";
"we already spoke about this today ... we arent using the river intro". So: PR #245 (branch claude/intro-port, the kaiju
rising from the river) is never landed and is never a dependency for anything; the D-310 queue slot "river intro #245"
is removed. Runs start in the crescent sea bay on the north edge and walk up the beach (D-270); the bay, beach and quays
from claude/intro-bay are ported straight onto main (builder beach-start), rising on the approved rise clip until the
keyed rise_bay clip exists (D-199). Never ask him about the river intro or the river for the intro again.

## 2026-10-28 · D-372 · Director · Render item 15 (Medium GPU p95 bar) is parked for now
The 10-28 re-measure (#371) left Medium's whole-run GPU p95 0.3-0.9 ms over Phase 0's. Fixing it needs night speed
runs (D-331, D-299). His words (10-28 ~17:2x): "we wont be able to do it tonight, park it FOR NOW". So: no profiling
or GPU-cut work on item 15 until he unparks it; the render plan's other open items (10 and 11, D-327) go ahead.

## 2026-10-28 · D-371 · Director · The "never touch" rules on Dracorex, Defender and his Cascadeur tabs are removed
His words (10-28 ~17:0x): "i never made these rules. i dont even know what they are, you can remove the rules". The
"never open, edit or save the Dracorex file", "never touch Defender" and "never touch his Cascadeur tabs" lines were
agent-added on top of D-305, D-318 and D-320. Removed: agents treat the Dracorex sample and the open Cascadeur tabs
like any other file and tab. D-318 and D-320 stay only as the record of what he answered. Method lessons stay (tabs
in batches of 5, probes never switch scene: they prevent crashes). Claude still cannot change Windows security
settings itself (its own tool limit, not his rule).

## 2026-10-28 · D-370 · Director · Ruleset after the rule audit
Rule audit 10-28; his picks, each the recommended option except roadmap. Decision log: a decision goes into
DECISIONS.md in the PR that acts on it, the lead owns the wording; log-only updates ride in the lead's next PR (main
requires checks, so no direct push); no separate board PR after each merge. Godot queue: gq syncs a job's worktree to
latest main itself (only a real conflict refuses); a speed run waiting over 20 min in the day moves to NIGHT_QUEUE.txt;
NO_GODOT_UNTIL holds every start. Reading: what the task touches, in full, grep the rest. Asking: only real calls.
Handoffs about 150 lines, edited after a commit, push or PR change. Reports short, no line count, no read receipts.
Tool caps raised (output 25k, reads 25k, commands 6000). Player-effect fixture only for new systems or rules.
Checklist walks only where a defect reached you twice. Roadmap: picked "Wait for assignment" (unchanged).
Team shape stays keyer + 4 builders (D-353).

## 2026-10-28 · D-369 · Director · No cap on open PRs
Changes D-353 (its "at most 3 open PRs"). Asked "why is 3 the cap"; the cap held 6 finished branches out of the game.
Picked "Drop the cap (Recommended)": finished work opens its PR at once and merges on a green check; no PR left
conflicting over an hour. The repo is public, so extra checks cost no CI minutes.

## 2026-10-28 · D-368 · Director · Croc jaw keyed in Cascadeur; roar, beam and attack snarls open the mouth
Asked why the mouth never opens in the croc drafts (the keyer left every jaw for a Blender layer under D-228, which
was never scheduled; the croc's r12 skeleton has a jaw joint that passed a 40 degree open test), he picked "Key it in
Cascadeur (Recommended)" and "Roar, beam, plus attack snarls (Recommended)". The croc's jaw is keyed in the same
Cascadeur file as the body at all three stages (D-228's Blender jaw stays only for rigs with no Cascadeur jaw). Wide
open on roar and breath-beam; a snarling gape showing teeth on charge, claw rake, standing stomp, tail sweep and leap
landing (D-239); every other move keeps the jaw shut.

## 2026-10-28 · D-367 · Director · Collapse sounds: the newest cuts the oldest
Asked why many collapses at once went silent in the wider city (each collapse rings about 3.4 s and only 3 play at
once, so a 4th was dropped), he picked "Newest cuts oldest (Recommended)". When a hero sound's voices are all busy, a
new collapse takes over that sound's own oldest voice once it has played at least 1.0 s (a tuning value); no other
hero sound is ever cut for it.

## 2026-10-28 · D-366 · Director · Wider-city music pacing waits for balancing
Asked about the city music's last layers never arriving in the wider (1.5x) city (there is more city to destroy before
they trigger), he picked "Leave it for balancing" (D-363). The pacing stays as it is; only the test is refit to the
bigger city.

## 2026-10-28 · D-365 · Director · Claw rake PR #332 closed, branch kept
Asked whether to close #332 (grown croc claw rake, waiting on a rebake) to free a PR slot, he picked "Yes, close it
(Recommended)". The branch claude/croc-claw stays; the PR reopens when its rebake passes on GitHub.

## 2026-10-28 · D-364 · Director · Cascadeur restarted to free memory
Asked whether to restart Cascadeur (holding about 11 GB, free memory under 2 GB, every rebake and local run waiting),
he picked "Yes, restart it (Recommended)". It had already exited when the lead went to close it and was relaunched
minimized; one copy only (D-336).

## 2026-10-28 · D-363 · Director · Balance waits until the game is beautiful and working
His words, after dying in every run of the play build: "dont worry abot balance yet. lets get the game beautiful and
working then we can balance it". Army strength, run length and upgrade costs stay as they are until he says so; the
lead checked his question instead ("maybe i didnt actualyl getkilled?"): the run summary names the real cause
(army kill: BROUGHT DOWN, clock: TIME UP), and every ending plays the stone and blast by design (D-263, D-294).

## 2026-10-28 · D-362 · Director · First drafts of every remaining Cascadeur animation, one attempt each
His words, going to sleep: "do a first draft of all remaining casc animations, dont iterate on any first attempts, try
to get through them all and we will see what was good / use our reference models and clips that ive shown you", then
"dont stop the casc work, really rapid fire get through all animations". Every open creature and people row of the
animation audit gets one keyed draft (the croc at all three stages, plus people, per his 10-25 "Creatures + people"),
saved as its own .casc and opened in his Cascadeur (D-347); no second takes, no clips, no PRs until he picks. Asked
about the insectoid and cephalopod, he picked "Croc and people only". Pauses the keyer's #332 work for the run.

## 2026-10-28 · D-361 · Director · The leap lands on roofs up to shoulder height; a taller building takes it in its side
His words, playing the build: "leap attack is broken because you can leap to the top of a sky scraper haha". Asked, he
picked "Tall ones: hit the side". Changes D-262's landing: a roof at about his shoulder height or lower is still a
landing; a taller building takes the leap in its side, he carves in (D-268) and drops to the street at its foot.

## 2026-10-28 · D-360 · Director · No far blur: the skyline stays sharp, haze alone carries the depth
His comment watching runs (about 01:4x): "the blurred distance also looks kind of distracting, makes it like you have
a smudge on your screen". Shown the same dusk Behemoth frame with today's far blur (A) and without it (B), and quoted
D-163 ("Far blur only", locked on the kaiju, haze carrying the depth), he picked "B: no far blur" (not keep A, not a
lighter blur). Replaces D-163's depth-blur clause only: far blur is off by default; haze, cool shadows with warm fire
and fine-block ground stay as D-163 set them. Owner: load-flake (flag off by default, PR); the facade pop-in probe
("Blurry turns sharp") follows.

## 2026-10-28 · D-359 · Director · The demo plays at dusk only
His question: "would it be faster if we focused on just one time of day for the demo". Told that it is (each new look
is tuned and shown once, not four times; sim, animation and perf work are unchanged), and quoted his 10-22 ruling
("the time of day will be randomised each run"), he answered "dusk only" (not the recommended night only, not all four,
not night and dusk). For the demo every rampage plays at dusk, the options time toggle is hidden while only one time
can play, and every capture and clip for him shows dusk. D-145's random time (never the same twice) and the toggle
return after the demo; night, morning and noon looks stay in data, untouched (D-279, D-285, D-328 still hold for night).

## 2026-10-28 · D-358 · Director · Hatchlings: a late Colossus node, one purple-crackling egg spewed from the maw per rampage
His words: "roadmap: "Hatchlings" / each of our kaiju should be able to lay eggs (or im actually leaning toward they
spew the eggs out) / late game power where you can spawn an autonomous baby version of your kaiju that rampages the
city"; "they should only lay 1 egg, and it should be crackling with purple energy". Picks: "Spewed from the maw
(Recommended)"; unlock: first offered as "Apex Titan (Recommended)", a stage D-135 had already cut (the lead's mistake, from a stale note); asked again (01:3x, "what is "apex titan""), he picked "A late Colossus node" (bought on the evolution tree after reaching the Colossus, the adult final form, so it is worked toward inside that stage); how it is earned: "must reach a certain biomass threshold within
a run, challenging but attainable"; at the mark "You choose when to spew (Recommended)" (a button lights up, one egg
per rampage, the player picks the moment); the hatchling is "Your species' baby form (Recommended)" (the young form the
player starts as, at that size, with its keyed moves), rampaging on its own. Every species gets it. The egg's purple is
the kaiju-juice colour (D-357). Earlier the cut insectoid's Brood ultimate (archive SPECIES_2026-10) laid several eggs;
this replaces that idea with one egg for all species. Queued behind the debt list and render plan (D-310); the mark's
size and the spew move are asked when it is built.

## 2026-10-28 · D-357 · Director · The lightning is purple, from deep in the throat, with arcs up the spines first
Shown the round 7 clip (#309, D-308): "currently it spawns above his head slightly in front, arcing from up to down /
its light yellow/white / i want it to come from deep in his throat and be purple lightning / I want his spines to light
up from tip of his [tail] to his head in sequence before he spews purple lightning from his maw"; "purple is our
default 'kaiju colour', because of the kaiju juice that fuels their evolution". Told that plates lighting tail to head
before a glowing breath is the Godzilla charge-up D-108 steered away from, he picked: "Arcs jump up the spines
(Recommended)" (lightning crackles spine to spine, tail tip to head, never a steady glow); "Fit inside it
(Recommended)" (the charge-up plays inside the D-166 strike delay, 0.8 / 1.1 / 1.4 s, the breath no slower); "Yes,
both match (Recommended)" (the Thunder Beam turns purple with the same charge-up). Changes: D-108's white-hot colour
and the open halo-colour question (R 17.6) are replaced by purple; the bolt starts inside the mouth, never above the head.

## 2026-10-28 · D-356 · Director · The Godot window is never left idle
"godot has been empty like 90% of the time recently, make sure its always being used so we can be efficient". Asked
whether tonight's speed runs may start at once instead of at 01:00 (D-331): picked "Start now (Recommended)"; the hold
was lifted 00:30 and the night queue runs back to back, builders' captures queue behind it. Standing rule: a capture,
clip or speed run always waits behind the one-window slot, so the window never sits empty while work is queued.

## 2026-10-27 · D-355 · Director · The grown croc eases into its walk over about 1.3 s
For the keyed walk-start (D-343). Asked whether the croc may take about 1.3 s to reach full walking speed from standing
(today about 0.13 s): picked "Ease in, ~1.3 s (Recommended)". The sim's set-off changes (walk_off_s and the step clock),
and the keyed walk-start plays over it. A ~6 s clip goes to him before it ships. Not picked: the body trailing the sim
(a ~30% surge) or a quick 0.4 s first step (the defect he named).

## 2026-10-27 · D-354 · Director · Creature animation runs alongside the parked work
Asked for a plan to finish the render plan and the debt list ("make a plan to finish the render plan, debt fixes"). Asked
whether the Cascadeur animation row (debt row 21, 31 of 40 moves to key) holds back the parked work (roads, wider city,
river intro, D-310): picked "Run alongside (Recommended)". The parked queue opens once every other debt row is merged;
the keyer and rigger keep keying the whole time. Plan: C:/Users/DANTE/.claude/plans/dapper-percolating-lake.md.

## 2026-10-27 · D-353 · Director · Team: the Cascadeur keyer plus 4 builders
Replaces D-296. Asked "be honest, would this actually be any slower if we did it with just you and no subagents? maybe 1
subagent for CI and thats it?". Lead's numbers: 85 merges on 10-27 (no builder limit) against 29 and 33 the two days
before; costs: collisions (#332 vs #338), 10 open PRs against the cap of 3, the lead relaying instead of checking work.
Then "what do YOU think, im asking here"; the lead recommended the keyer plus 4. Picked "Yes, keyer + 4 (Recommended)":
the Cascadeur keyer plus 4 builders (the rigger is one of the 4, D-336), at most 3 open PRs. Running builders finish
their current task and are not replaced. The lead counts in-game progress on 10-28 and reports it.

## 2026-10-27 · D-352 · Director · Roof tanks: mostly white solar water heaters, some short wooden towers
Changes D-348. On the wooden towers: "idk, the rooftanks look massive, and why are the brown"; "i prefer rooftanks like
the attached image" (a white tank lying on its side on a metal frame above two dark solar panels; reference only,
C:/kt/reference/roof_tank/); "i mean keep SOME of the wooden towers, but mix it up with the white ones". Picked "Mostly
white (Recommended)": same spots and count, about 3 in 4 roofs a white heater, 1 in 4 a wooden tower; and "About 1.5
storeys (Recommended)": a wooden tower is half today's height, so it sits on the roof instead of looming.

## 2026-10-27 · D-351 · Director · Countable speed-run bars move to GitHub checks
Speed runs need his PC to themselves (D-299), so tonight's queue is about 3.5 h. Asked how to clear that bottleneck:
"Count on GitHub (Recommended)". Bars that can be counted on a pinned seed (draw calls, pieces, nodes) become GitHub
checks that run any time and in parallel; only millisecond bars stay on his PC (builder bench-counts). Not picked: the
card's own timer, renting cloud GPUs (no spend), a spare bench PC. Start time "[No preference]": runs start 01:00.

## 2026-10-27 · D-350 · Director · The camera bubble comes forward
Asked about the dot fade still on main: "Bring the bubble forward". #238 resumes now, ahead of D-283's "after the
render plan" timing and its place in D-310's order. Which buildings (22:50, replaces D-283's agent wording "between
camera and kaiju"): "its the ones that the camera itself phases through ... foreground buildings which are nowhere near
the field of destruction"; never "inside buildings adjacent to the kaiju". A sphere around the camera only; zero cuts in
the kaiju's destruction field; pieces, rubble and vehicles never (D-326); shadows kept. Removes the biomass numbers (D-284).

## 2026-10-27 · D-349 · Director · After the walk-start, the keyer keys the young croc walk
Asked what the one keyer keys after the walk-start (D-343): "Young croc walk", ahead of the grown croc's run. Order:
walk-start, young croc walk, run, slam-stop, turn-skate B.

## 2026-10-27 · D-348 · Director · Rooftop water tanks become wooden water towers
The brown roof "trees" (D-345) are the rooftop water tanks. Picked "Wooden water towers (Recommended)": same spots and
count, a barrel tower on legs with a cone roof.

## 2026-10-27 · D-347 · Director · Keyed Cascadeur moves come as the .casc, not a clip
"rather than taking a clip of an animation itd be easier to just show me the casc file so i can inspect it"; scope
"Keyed moves only (Recommended)". A keyed move reaches him as its .casc opened in a new tab of his Cascadeur
(C:/kt/casc_view_template.py: never saved, no other tab touched). How a move plays in the game still comes as one
~6 s game-camera clip.

## 2026-10-27 · D-346 · Director · The one-window GPU slot covers Godot only
Asked whether Blender renders and bakes should also wait for the one GPU slot (D-340): "Godot only (Recommended)".
Godot windows (clips, stills, captures, speed runs) take turns; Blender and other GPU jobs keep sharing the card by
VRAM budget, so asset work keeps its pace.

## 2026-10-27 · D-345 · Director · Trees on rooftops are a bug: they go to streets and parks
He asked about the far-city noon still: "why are there so many trees on top of buildings is that a bug?" (trees stand
on low roofs, one on a tall roof among the antennas). No decision asks for rooftop trees. He picked "Yes, find and fix
(Recommended)": find why trees are placed there, move them to streets and parks, and send him a still.

## 2026-10-27 · D-344 · Director · Far-city reflection look approved (D-324)
On the far-city reflection stills (the far skyline's glow in the bay, D-324 "Fog + reflection"): "Looks right, merge
(Recommended)". The branch claude/far-city-reflect opens READY after #330 and merges on green.

## 2026-10-27 · D-343 · Director · The croc's first step from standing gets a keyed walk-start
Asked how the young croc should start walking from a stand: "Key a walk-start (Recommended)": a Cascadeur
stand-to-walk clip plus its plumbing, on the one keyer's queue (D-336), before turn-skate B.

## 2026-10-27 · D-342 · Director · Slow motion: the slowdown is too brief
On the #308 clip (slow motion only when a landmark falls; rooftop rifle hits land on the hide, D-259, D-245): "i think
the slowdown is too brief but looks good". Merged as is (400903ee); the slowdown is lengthened and a new ~6 s clip goes
to him.

## 2026-10-27 · D-341 · Director · Death chunks approved (D-323)
On the #322 clip (he breaks into 8 baked jagged stone chunks with dust, never cubes, D-323): "Yes, merge it
(Recommended)". Merged cea476e8. The chunks' size, spin and trail numbers are agent-added, no decision.

## 2026-10-27 · D-340 · Director · One Godot window on the GPU at a time (rule replaced by D-376)
His words (22:0x): "having 2 godot open is cooking the GPU, you gotta do a better jop managing it". Cause: the rules
allowed up to 3 captures at once and up to 2 Godot processes per agent, and nothing counted windows PC-wide, so two
builders' clips rendered together. Rule: every windowed Godot run (capture, clip, still, speed run) takes the one
PC-wide slot, `bash C:/kt/gpu_slot.sh <command>`, which waits its turn; the focus-guard hook refuses a windowed run
outside it. Headless runs (tests, imports) take no slot. Replaces the capture counts in the rulebook and CLAUDE.md.

## 2026-10-27 · D-339 · Director · 1080p is the baseline, not 4K
His words (19:5x): "you know we dont need to work as 4k as the baseline just because i am using a 4k tv. most players
probably wont be running it at this resolution". Asked, he picked: "1080p first" (text, readability and the look are
judged at 1080p, the most common screen on Steam; 4K stays supported and is checked at each playtest build), the speed
target "60 fps at 1080p Medium" (replaces D-093/D-109's 60 fps at 4K), and stills "Switch to 1080p" (replaces D-304's
4K stills; clips stay 1080p). Scope, asked: "Kaiju only" (his other games keep the rulebook's
4K-first check); the project CLAUDE.md carries the Kaiju rule.

## 2026-10-27 · D-338 · Director · Momentum differs by titan: croc quickest, Komodo lumbering but hardest, serpent agile
His words (19:5x): "i want the turning bleed to be light for the croc, he should be the most mobile and gather momentum
the quickest / our komodo is lumbering / our serpent will be agile but not particularly fast or slow". Asked: the Komodo
"Slow start, hardest hit" (slowest to build, turning bleeds him most, but rolling he crashes and slams hardest) and his
run "Always on, like the croc" (replaces D-245's top-tier run unlock). The serpent, in his words: "snake will crash
through buildings around his height, but being that he is the shortest kaiju, that wont be many buildings. Snake can
however clumb the buildings bigger than him and constrict-crush them"; asked, a bigger building at speed "Flows into a
climb" (no slam) and constrict "Keep it at adulthood" (D-206 stands). Serpent work still waits on D-246.

## 2026-10-27 · D-337 · Director · The croc's run is momentum: he crashes through small buildings, slams into big ones
His words (19:4x), on hearing the croc has no run yet: "running wont have a sprint button, it should be momentum based,
at high momentum he can crash right through smaller buildings, and collide with a bang into bigger ones". Asked:
momentum "Always on" (from the first rampage, walking straight builds him into a run and turning bleeds it; tree nodes
make it build faster and hit harder, and the old unlock node becomes a boost); a big building "Slam and stop" (a loud
impact, a deep dent caved in at the contact, the building shudders, the camera shakes, his momentum is spent); small
vs big "Relative to his size" (shorter than about his shoulder crashes, so each stage crashes through more); when
"Now, one more builder" (ahead of D-310's order; it touches no debt or render file). Per D-335 the run and the slam
stop are keyed in Cascadeur.

## 2026-10-27 · D-336 · Director · One Cascadeur keyer and one rigger; no second Cascadeur copy
His words (19:3x), on hearing that Cascadeur runs one copy at a time: "if only 1 builder can use casc at a time then
we only need 1 casc builder otherwise the others are just twiddling their thumbs". Asked, he picked "1 keyer + 1
rigger" and said "No" to testing a second Cascadeur copy. So: one builder (croc-claw) keys every move in turn (claw
rake, walk first step, idle, run, turn B, then the young clips); one rigger (croc-young-casc) readies the young
skeletons (D-335, bars S1-S5) and brings finished clips into the game; every Cascadeur job holds C:/kt/casc_lock.sh;
croc-idle-run and croc-casc-s2 are not respawned.
