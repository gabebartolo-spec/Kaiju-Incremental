# Volley-stagger handoff (builder "volley", then builder "beam-cost" for D-178), 2026-10-23 16:3x
## State: D-178 done and proved (red on the old sim, green on the new); pushed to claude/volley-stagger (updates PR #170)
## Task
D-166 "Stagger the shots" (one squad never lands more than ~2 railgun hits a second, so the dash has time to save the
kaiju, D-161) and, since the non-author sim review of #170, D-178 "Lock together, fire in turn" (director): a squad's aim
lines lock at the same moment (one lock-on point for the squad) and its shots land 0.6 s apart (taskforce.railgun.
squad_gap), so one dash at the lock dodges the whole squad's volley; standing still, at most ~2 hits a second per squad
(D-175: per squad). Sim only, data in data/tuning.json, seeded, no save change.
## Branch
claude/volley-stagger (from origin/claude/look-options df5309de), no PR from me (the lead opens/updates #170). The
branch's upstream is look-options by accident: push only as
`git push origin claude/volley-stagger:claude/volley-stagger`. D-178 worktree: Kaiju-Incremental-wt/volley-d178.
## What changed
- D-166 (commit 9e1f7666, earlier): data/tuning.json taskforce.railgun.squad_gap 0.6; each gunner's aim started squad_gap
  after the squad's last (so the lines locked one after another: one dash dodged only one shot; D-178 replaces this).
- D-178 (this commit): the railgun code moved out of sim/taskforce.gd (it would have passed the 400-line cap) into the
  new sim/taskforce_volley.gd (class TaskforceVolley, like TaskforceFrost/TaskforcePerch). Taskforce keeps `volley`,
  `Agent.muzzle()`; _perched asks `volley.busy(squad)` then `volley.open(agent, agents, dt)`; step calls `volley.tick`
  before the agents loop and `volley.aim(agent, dt)` for an aiming agent.
  - open(): the first ready gunner (perched, rail_cd 0, kaiju in range) and every LATER-listed ready gunner of its squad
    put their lines up in the same step; gunner n (list order) is due aim_seconds + n x squad_gap after. A later-listed
    gunner also runs aim() this same step, so it starts one dt behind to stay level with the opener.
  - tick(): per squad {"lock": s until the lines lock, "left": s until the last shot}; at lock every aiming gunner of
    the squad locks on the first line's aim_at (one point, one step, railgun_locked each); at left <= 0 the squad may
    open another volley. A gunner killed mid-aim leaves its shot out, the volley still runs to its planned end.
  - aim(): follows the kaiju until locked; fires when its aim_left <= 0 (damage, armour, events unchanged: _fire moved
    as it was). A lone gunner is exactly as before (same lock and shot steps), so railgun_hit/dodge/mid-aim/armour checks
    pass unchanged.
- tests/run_taskforce_gate_tests.gd: `_volley(gap)` now returns {"locks", "shots"} per squad; `_check_volley` gained
  "each squad's lines lock at the same moment" (squads of five and three); new `_check_squad_dash`: a planted squad of
  four, ONE dash (Shift) the step after the lock: 0 hits and 4 misses; standing still: 4 hits and 0 misses; plus "the four
  lines lock in one step on one point" and "the dash left the lock behind".
- data/tuning.json _note and tests/README.md row describe the new rule.
## Evidence (2026-10-23 16:1x-16:2x, isolated APPDATA by run_tests.sh, native DLL absent here: the GDScript path)
- RED on the base sim (new tests, old sim/taskforce.gd, volley class moved aside): taskforce_gate 9 of 9 functions, 31
  checks, 4 failures: "each squad's lines lock at the same moment (lines [5, 3]): [[1.633, 2.267, 2.9, 3.533, 4.167],
  [1.633, 2.267, 2.9]]", "the four lines lock in one step on one point (1 locks, 1 points)" (twice), and "one dash at
  the lock: every shot of the squad misses (hits, misses [3, 1])".
- GREEN on the new sim: taskforce_gate 9 of 9, 31 checks, 0 failures; taskforce 10 of 10, 56 checks, 0 failures.
- gdlint, gdformat --check (LF), tuning_keys.py (1167 reads), complexity_ratchet.py (70 offenders, none grown) clean.
- Not exercised: check_scripts.sh (the suites compiled every file they load); the look (aim lines now go up together and
  lock together; no capture); play feel; a squad of five lined up at the exact same roof cell (the fixture does that);
  the military/army suites (the sim change is inside Taskforce); two or three squads at once can still land 2 hits a
  second EACH (D-175 per squad); a gunner who becomes ready mid-volley waits for the squad's next volley.
## Sim review FIX of #170 (2026-10-23 17:3x): defect, drift, nit, all fixed and proved
- DEFECT: _can_join read a later-listed gunner's rail_cd before Taskforce.step decremented it (4 gunners on equal rail_cd:
  the first opened alone, the rest locked 2 s later). Fix: Taskforce.step runs every agent's rail_cd/frost_cd down in a
  pre-pass before the agents loop; "ready" (TaskforceVolley.ready) allows READY_SLACK = half a step, for the opener and the
  joiners alike (float noise and a squad_gap that is not a whole number of steps could split a squad by one step).
- DRIFT: the cooldown counted from each gunner's own shot (round 2 split: A at 14.07 s, B-D at 16.07 s). Now a gunner's
  rail_cd after its shot = cooldown - (the volley's age at its shot - the age at the volley's first shot), measured in the
  volley's own steps (not the nominal k x squad_gap, which was one step off for some gunners: first try 2 of 6 checks red).
  A volley now ends when no gunner of the squad is still aiming (record erased by the next tick), not at a planned time.
- NIT: _can_join skips a gunner whose roof chunk is gone (no slot, no railgun_aim).
- New suite tests/run_taskforce_volley_tests.gd (3 functions, 6 checks): four gunners ready together at rail_cd 0.5 and 6.0
  lock in one step; three rounds each lock the squad of four in one step and every gunner fires once a round; a lost-roof
  gunner puts no line up and takes no slot (the next shot follows by one gap). RED on e5d24848: 6 of 6 checks failed
  (locks on steps [63, 123], [228, 288], [48, 469, 529, 890, 950]; 10 shots; aimed [0, 1, 2]; 1.23 s vs gap 0.60 s).
- GREEN: taskforce_volley 3 of 3 functions, 6 checks, 0 failures; taskforce_gate 9 of 9, 31 checks, 0 failures; taskforce 10
  of 10, 56 checks, 0 failures. gdlint, gdformat --check (LF), tuning_keys, complexity_ratchet clean.
- Not exercised: check_scripts.sh (the suites compile every file they load), military/army suites, the look, play feel.
  A lone gunner can now fire up to half a step earlier than before (READY_SLACK).
## Review packet (kaiju-sim-review; reviewer is not the author)
Transitions affected (derive your own from the diff too):
- Tick: Taskforce.step order is frost.step, volley.tick, then agents in list order. No clock, no new RNG draw; state is a
  Dictionary keyed by squad id (insertion order deterministic).
- Injury: damage per hit unchanged (share x max hp, armour, min damage). WHEN hits land changes: lock together, shots
  squad_gap apart; the lock is now a per-squad moment, not per-gunner.
- Removal: a gunner killed or swatted mid-aim keeps its place in the schedule (its slot stays empty); the volley ends at
  its planned time, so the squad's next volley waits at most 4 x 0.6 s more.
- Save/reload: none (Taskforce rebuilt per rampage; `_volleys` not saved). Generation/identity: no new entities;
  agent.squad is the index into squad_sizes at spawn; test-placed agents share squad_sizes.size().
Invariants: (1) one squad's shots are >= squad_gap apart (at most 2 in a 1 s window); (2) a squad's lines lock in one
step on one point; (3) every ready gunner of the opener's squad fires once per volley (no starvation); (4) squads are
independent (a second squad's first shot is not held up); (5) determinism: same seed, same events.
## Open decisions
- 0.6 s is the builder's number inside "about 2 hits' worth in a second" (D-178 now names 0.6 s: one data value).
## Rules learnt the hard way
- Edit tuning.json _note text without double quotes: they break the JSON (the whole sim fails to load).
- A fresh worktree import segfaults (exit 139) after the class cache is written; the cache is enough for tests
  (`run_tests.sh --quick` works). In a gdscript test, index into an Array/Dictionary gives Variant: assign to a typed local
  before `.size()` or `check(...)` (Warning treated as error).
- The worktree guard refuses variable assignments next to GitHub paths in a plain command: run a script file instead.
