# Taskforce handoff (PR 1, sim core, agents only), 2026-10-22
## State: handed over (WIP pushed; a fresh builder takes the sim core)
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
## Test state (tests/run_taskforce_tests.gd + tests/lib/taskforce_suite.gd; run with
`tools/run_tests.sh --quick taskforce`, ~6 min, own APPDATA, under timeout)
- Compiles, lint/gdformat/ratchet/tuning_keys clean. 9 functions, 38 checks.
- Passing: stage gate (none in the young city, 12 in the adolescent, none before after_chunks), arrival
  and cap (taskforce_deployed once, squads 3-4, <= 12 alive, edge arrival, interval shrinks as the city
  falls), perch death (agent_died perch_collapse, pays biomass), 8% railgun hit and the 2 s telegraph,
  frost refresh / no stack / thaw, swat (spins to a wall, pays), determinism.
- Failing at the last run (tf10): (1) "a step after the lock dodges the shot": the kaiju does not
  move far enough in the 0.4 s lock (kaiju speed 5.5, hit_radius 1.5; walking a free way) or is held
  back by body contact: debug with tests-side print of kaiju_pos per step (a scratch script that extends
  run_taskforce_tests.gd works); (2) "the dash shatters the ice early" returned {} (the dash did not start
  that step: check body.active()/dash available, or press for 2 steps); (3) "a grenade that lands where
  the kaiju no longer stands does nothing" (same walking problem); (4) the effect fixture saw equal damage
  (512 vs 512): the cushion heals to max_hp each step so the compare must read damage per step, and agents
  may not shoot in 90 s from the south-edge start (check perch range / arrival time).
- Findings: sim.hp is clamped to max_hp every step (so a huge cushion does nothing); a teleported kaiju
  is pushed back by body contact (move it by walking); the old default start (0,0) is inside a building,
  use the run's own start (the ring avenue, south edge).
## Decisions I made (placeholders for the lead): railgun hit_radius 1.5 absolute (not the body radius),
frost radius 4.0 at the feet, slow 0.5 for 3.5 s, railgun ignores armour and line of sight.
## Unfinished
Fix the four failing checks, run the full suite, push, PR per kaiju-pr with the kaiju-sim-review packet
(transitions: agent spawn, perch, death, kaiju hp, kaiju speed (frost)). The PostFx fringe hook on
railgun_hit is not wired. Never edit rampage_sim.gd (at its 400-line cap): hooks live in Army.
## Findings for the lead
none
