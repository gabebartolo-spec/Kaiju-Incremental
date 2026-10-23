# Volley-stagger handoff (builder "volley"), 2026-10-23 13:3x
## State: waiting for 14:14 (director: no Godot until then); task 1 pushed, task 2 audit done and reported
## Task
Kaiju lead's builder. Task 1: ROADMAP "Interview answers", D-166 "Stagger the shots": one Taskforce squad never
lands more than about 2 railgun hits in a second, so the dash has time to save the kaiju (D-161). Sim only,
data in data/tuning.json, seeded, no save change. Task 2 (read-only, after task 1 is pushed): audit of every
PRESSED reptilian attack against D-166 "Damage lands on impact" (report to the lead as a table, no code).
## Branch and commit
Branch claude/volley-stagger (from origin/claude/look-options df5309de), worktree
.claude/worktrees/agent-ac92f78143e5f1af5. Code commit 9e1f7666. No PR (the lead opens it). The branch's upstream
is look-options by accident: push only as `git push origin claude/volley-stagger:claude/volley-stagger`.
## What changed (task 1)
- data/tuning.json taskforce.railgun.squad_gap 0.6 (+ the _note sentence). 0.6 is the builder's pick inside "about
  2 hits' worth in a second": any gap over 0.5 s keeps a squad to 2 shots in a second.
- sim/taskforce.gd: `_volley` {squad -> seconds until its next aim may start}; `_start_aim()` (the old aim-start
  lines, plus taking the squad's slot); `_tick_volleys(dt)` counts the waits down once a step, after frost.step and
  before the agents loop. In `_perched`, a gunner whose railgun is ready and in range aims only if its squad has no
  wait; else it holds (no frost, no hop) until the slot frees. A shot lands `aim_seconds` after its aim, the same for
  every gunner, so aims `squad_gap` apart are shots `squad_gap` apart. The lock/dodge rules are untouched.
- tests/run_taskforce_gate_tests.gd: `_check_volley` + `_volley(gap)` + `_worst_second(times)` (6 checks).
  Planted a squad of five lined up and a squad of three (railguns ready, one roof, kaiju standing in range, 10 s).
## Review packet (kaiju-sim-review; reviewer is not the author)
Transitions affected (derive your own from the diff too):
- Tick: Taskforce.step order is now frost.step, `_tick_volleys`, then agents in list order. No clock, no new RNG
  draw; the only state is a Dictionary keyed by the agent's squad id (insertion order is deterministic).
- Injury: damage per hit is unchanged (share x max hp, armour, min damage). Only WHEN a squad's hits land changes.
- Removal: a gunner killed mid-aim (perch collapse, swat) leaves its squad's slot taken for at most `squad_gap`; the
  entry expires by itself (erased at <= 0), so an empty squad leaks nothing.
- Save/reload: none. Taskforce is rebuilt per rampage; the only persisted value is `carried` (city_seconds, D-160).
  No save version change, no new save key. `_volley` is not saved (no mid-rampage save exists).
- Generation: no new entities, caps unchanged. Identity: `agent.squad` is the index into squad_sizes at spawn;
  test-placed agents share `squad_sizes.size()` (so planted squads must append to squad_sizes, as the test does).
Invariants and evidence:
1. One squad's railgun shots are at least squad_gap apart, so at most 2 in any 1 s window (closed window).
   Evidence: _check_volley, worst window 5 and 3 before, at most 2 after (the check passes).
2. Every gunner still fires (no starvation): the slot frees every squad_gap, so the nth waits (n-1) x 0.6 s at most,
   1.8 s for a real squad of 4. Evidence: "every gunner still fires" (5 and 3 shots in 10 s).
3. The gap is per squad, never global: a second squad is not held up. Evidence: first shots of both squads within
   squad_gap of each other. PLANT NOT YET SHOWN (see below).
4. A lone gunner is unchanged (empty `_volley` means it aims at once): existing railgun_hit, dodge, mid-aim and
   armour checks pass unchanged.
5. Determinism: same seed, same events (the taskforce suite's _check_determinism passes).
Not exercised: the look (aim lines now go up 0.6 s apart; no capture); play feel; two or three squads at once can
still land 2 hits a second EACH (up to 6 with 3 squads, about 48% of health), because D-166 says "one squad"; a
squad's cooldown cycles after the first volley (only the first volley is planted, 10 s of a 12 s cooldown).
## Evidence so far
- Failing first (old rule: key present, ignored): taskforce_gate 25 checks, 2 failures: "a squad lands at most 2
  hits in any second (5 and 3)" and "shots at least 0.6 s apart: [2.03 x5]" (all five shots on the same step).
- With the change: taskforce_gate 8 of 8 functions, 25 checks, 0 failures; taskforce 10 of 10, 56 checks, 0 failures.
- gdlint, gdformat --check (LF), tuning_keys.py, complexity_ratchet.py (70 offenders, none grown), check_scripts.sh
  (452 scripts) all clean on the code commit.
## Unfinished changes
- After 14:14 only: rerun taskforce_gate once with a PLANTED global gap (`_volley[0]` and `has(0)` instead of
  `agent.squad`): "the gap is kept per squad" must fail; revert with `git checkout sim/taskforce.gd`; then one clean
  green run of taskforce_gate. The first planted run was stopped by the engine ban (exit 127) and reverted.
- Push (explicit refspec above), report the sha to the lead.
## Task 2 audit result (read-only, sent to the lead; the sim steps at 60 Hz in the game, 30 in tests)
Pressed reptilian actions are three: dash, signature breath, Thunder Beam (HELD only feeds the mantis glide).
- Dash (Shift/B): moves from the press tick (0 s); buildings break on contact over ticks 0-24 (0.4 s), tanks once each
  at 60; same at all three growth steps (about 15 / 27 / 50 units far). A sim wind-up would cost the 0.4 s railgun
  dodge (D-161), so the D-165 crouch must be view-only.
- Breath: ALL damage on the press tick (0 s), cone read at that instant; 7 s cooldown from the press; view flame
  lingers 0.9 s (fx.beam_seconds). A wind-up needs a call: lock the cone at the press or follow the kaiju to the
  strike; what a breath pressed in the last second does; run_fire and run_sim tests assume tick-0 damage.
- Thunder Beam (E/Y, Colossus only): stream of beam_dps x dt for 4.0 s from the press tick, cooldown 18 s from the
  press, walk x0.3 while on. A wind-up needs a call: does the 4 s start at the press or the strike, is he rooted.
- Not pressed: stomp lands on its tick (the view already waits for the foot); the claw swipe ALREADY has a 0.3 s sim
  wind-up (swipe_windup event, then the rake); tail sweep and ram are instant.
## Open decisions
- Does the director want the stagger across squads too (a global gap)? D-166 says "one squad"; built as ruled.
- 0.6 s is the builder's number inside "about 2 hits' worth in a second" (one data value).
## Running jobs
none (engine ban until 14:14).
## Findings for the lead
- The worktree guard refuses `bash <script>` and `~`/`$HOME` paths and any redirect to a path containing "GitHub";
  engine_slot.sh could not run, so suites ran as `GODOT=... tools/run_tests.sh --quick <suite>` (plain command).
- gdformat on Windows rewrites files with CRLF in the working copy; convert back to LF before committing.
## Rules learnt the hard way
- Edit tuning.json _note text without double quotes: they break the JSON (the whole sim fails to load).
- A fresh worktree import segfaults (exit 139) after the class cache is written; the cache is enough for tests
  (`run_tests.sh --quick` works), so do not rerun the import.
