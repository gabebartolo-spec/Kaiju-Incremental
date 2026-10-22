# Taskforce handoff (PR 1, sim core, agents only), 2026-10-22
## State: working (code written, tests not yet run: Godot paused by the director until 23:35)
## Task
Anti Kaiju Taskforce PR 1 of the plan (post-fx/agent-handoffs/taskforce-plan.md): sim core for agents only.
Serves ROADMAP "Adversaries" and D-137, D-139, D-141, D-143, D-145. Lead's brief: Taskforce manager + Agent states
in sim/ (no Node), squads of 3-4, max 12 alive, jetpack in from the map edge faster as the city falls, perch and
hop, railgun (line tracks, locks shortly before firing, 8% max hp), frost (refresh, no stack, dash shatters), deaths
(perch collapse, claw-swipe swat), events, all numbers in data/tuning.json "taskforce", placeholder boxes, seeded tests.
## Branch and commit
claude/taskforce-core in C:/Users/DANTE/Documents/GitHub/Kaiju-Incremental-wt/taskforce-core (from origin/claude/look-options 2cd09bba).
## What is in it
- sim/taskforce.gd (Taskforce + Agent: squads, arrival, perch, hop, railgun, deaths, swat), sim/taskforce_frost.gd.
- Hooks: Army owns `taskforce` (stepped in Army.step, own seeded stream 0x7F), ClawSwipe._rake calls taskforce.swat,
  SpeciesPowers.speed_mult multiplies by the frost slow (the old body is _ground_mult). RampageSim is untouched
  (it sits at the 400-line cap).
- data/tuning.json "taskforce" (all numbers; max_by_tier [0, 12, 12, 12] gates the young city).
- scenes/taskforce_view.gd: placeholder obsidian boxes + a blue aiming line, created by TankYard (rampage.gd is at its cap).
- tests/run_taskforce_tests.gd (9 checks incl. the player-effect fixture "taskforce.agents"), tests/README row.
## Decisions I made (placeholders, flagged in the PR for the lead)
- Numbers are (tune) placeholders except 8% share, 2.0 s aim, squads 3-4, 12 alive. Frost slow 0.5 for 3.5 s is mine.
- The railgun ignores the kaiju's armour stat and needs no line of sight (nothing ruled).
- Only the two ruled deaths (perch collapse, swat); stomps/breath/beam do not kill agents (D-139/D-145 do not say).
- A railgun hit raises event railgun_hit (the plan's PostFx fringe hook is PR-later; not wired here).
## Unfinished
Run the suite (timeout, own APPDATA), fix, full suite, push, PR per kaiju-pr with the kaiju-sim-review packet.
## Findings for the lead
none yet
