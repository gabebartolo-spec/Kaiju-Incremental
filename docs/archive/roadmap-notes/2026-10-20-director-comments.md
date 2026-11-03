# Director comments of 2026-10-20

Cap: 150 lines.

Quotes are verbatim from his messages. Rule: every comment of his goes here with owner, branch and status.

| # | His words | Owner / branch | Status |
|---|-----------|----------------|--------|
| 1 | "why the shockwave lands beneath the crocs tail ... remove it or make it make sense" | stomp-ring builder / #104 | merged (critic: foot ring not visible, slam unchecked: Phase D) |
| 2 | "the shockwaves look quite amateurish in general, tone down the effect" | stomp-ring builder / #104 | merged (critic: foot ring not visible, slam unchecked: Phase D) |
| 3 | /goal "playable build with building carving first draft" | carve-play / builds 1-2, #105 WP6, #106 WP5 | build 2 (3998051) played; notes in 2026-10-20-build2-playtest.md |
| 4 | "change lead context limit to 500k so we can actually get something done" and "increase to 300k (450k hard cutoff) for all helpers" | lead 8 / ~/.claude hook + RULEBOOK | done |
| 5 | "dont waste time chasing marginal gains, get things implemented and we can polish later" | all | rule (no-marginal-gains) |
| 6 | "dont spawn multiple helpers. I will allow you ONE Opus Medium helper, and from there any helpers must be sonnet critics/readers, only you and the other Opus session should build" | lead | rule (RULEBOOK, CLAUDE.md) |
| 7 | "add to roadmap: find a few different shaders and create side by side comparisons at different times of day so i can assess and choose which goes into the game" | lead / claude/camera-options | decided: Cinematic (D-104) |
| 8 | "dont worry about \"stealing focus\", work unhampered, i am not using the pc" and "all of the gpu and cpu is yours, use as many godot/gpu/ci lanes as you need" | all | standing while he is away |
| 9 | "allow tanks to run over cars, thats fine with me, clumsy military" | lead / #109 (military check drops the car rule; tanks flatten cars) | done in #109 |
| 10 | "make sure the river entrance shows our kaiju actually emerging from the water, not from the asphalt." | Phase A (bug) / #113 | merged |
| 11 | "have this as a quick, dramatic camera shot, zoomed in on the water which begins to ripple and fount before our kaiju emerges, roaring with rage before the camera zooms out into the play angle and the run begins. the entire scene should run for no longer than 3 seconds" | Phase D (after the Phase B camera pick) | open |
| 12 | "water needs physics and to react to the kaiju" | Phase D | open |
| 13 | Time of day (asked after the shader pick): "all of them, except make morning less hazy and the night a bit lighter" | lead / claude/camera-options (runs rotate dusk, night, morning, noon; data/looks.json "times") | done in camera-options PR |
| 14 | "buildings which get destroyed invariably turn into burning buildings, it makes no sense because they were previously reduced to rubble then emerge from the ground as flaming buildings" | lead / #111 (Ruin drops its wall stubs) | merged |
| 15 | Builder restart at 300k: "No, I'll do Phase A" (picked answer: the lead builds Phase A alone) | lead | standing |
| 16 | "kaiju pivoting from left to right is too slidey, our kaiju should have real weight behind them, feel lumbering and unstoppable. Movement needs real weight without feeling unresponsive. The kaiju must move naturally like the predator and animal he is, perhaps if the kaiju's head were to turn the direction he wants to walk slightly before his body angles to move it would read more naturally" | Phase D (body feel; clip through the motion critic) | open |
| 17 | "theres a visual bug when destroying the stadium where you can see the humans feet dangling in the air when you destroy the floor theyre on, they should fall to the ground or otherwise be destroyed in the carnage before aberrant visuals like that occur" | Phase C (with b2-8 stadium crowd) | open |
| 18 | "the edge of the play area needs to be indicated somehow (not too loud)" | Phase A / #114 (a quiet row of bollards) | in review |
| 19 | Helpers: "i afforded you two sonnet high helpers, use them wisely"; "keep your devs working" (two Sonnet-high read-only reviewers; the lead builds) | lead | standing |
