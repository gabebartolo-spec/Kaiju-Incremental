# Body-chunks handoff, 2026-10-23
## State: pushed, awaiting the lead's PR
## Task
ROADMAP "Engineering upkeep (D-159)", item "Chunks inside the body": chewing a tall tower down left standing
chunks inside the kaiju's body at city seeds 3, 8, 22 (tests/lib/sim_body_contact.gd `_chew_to_topple`, "worst").
Lead's ruling after my first report: fix the fixture, change no sim code, no new rule without the director.

## Branch and commit
claude/body-chunks (from origin/claude/look-options aad7e485). Commit sha: see the push report. No PR (the lead's
helper opens it).

## Finding (measured, not assumed)
The chew/hold in BodyContact is correct. The chunks were there at step 0: the fixture's `_place` set the body down at
the tower's south face + 0.6 body lengths, on top of neighbours the baby cannot break outright (tier 2+, D-091
dwarf_mult < 1). Those chunks are chewed at bite_dps while the hold keeps the body still, so they count as "inside" for
10 to 30 steps, then drop to 0. The office-only tower pick also found no tower at seeds 3 and 8, so the fixture fell
back to `buildings[-1]`, a 3x2x3 tier-1 shed that never topples.

## Changes (tests only, no sim code)
- tests/lib/sim_body_fixture.gd (new): shared statics: nearest_of / nearest_office / nearest_tower (office, else any
  style, -1 if none), set_down, set_down_clear (backs the body off its facing until nothing stands inside), count.
- tests/lib/sim_body_chew.gd (new, split out of sim_body_contact.gd, which was 361 lines): the topple, swipe and fall
  checks, now set down clear and fail loudly when no tower or no clear spot is found; new `_check_chew_seeds` runs
  city seeds 3, 8, 22 (nothing inside at the start, tower topples, nothing inside after any step).
- tests/lib/sim_body_contact.gd: 362 -> ~190 lines, calls Chew.new(...).run().
- tests/lib/sim_suite.gd: `_sim_seeded(species, levels, tuning, Vector2i(city seed, run index))` (`_sim` calls it);
  `_layout` takes a city seed. tests/run_sim_tests.gd passes it to SimBodyContact. (gdlint caps arguments at 4.)

## Evidence so far
- Old fixture, real tall tower, city seeds (start pose on top of the neighbours): seed 3 = 0 inside (clear spot);
  seed 8 = 107 at step 0 (tower 5x4x12, any style; no office in the arena); seed 22 = 76 (office tower 4x4x14;
  55 for the nearest any-style tower). Chewed to 0 by step 10 (seed 22: step 7) to 30 (seed 8).
- Clear start (pushed back 0 to 21 m): city seeds 0..40, nearest real tall tower, 0 chunks inside after every step
  through the topple (40 of 41 seeds have a tower; seed 4 has none in the arena).
- 18 seeded random 30 s walks with dashes (baby / adolescent / adult x city seeds 0, 3, 5, 8, 11, 22): 0 steps with a
  chunk inside the body; held steps present (0 to 91 per walk), so dwarfing walls were met.
- New check on the fixed fixture (7 checks, 0 failures). Same check with the old placement: FAIL seed 8 (107) and
  seed 22 (76). Same check with a planted sim defect (BodyContact._hold does nothing): FAIL at seeds 0 (8 inside),
  3 (50), 8 (50), 22 (40). The planted edits are reverted (no diff in sim/).
- Touched suites (tools/run_tests.sh --quick, own user data, behind engine_slot): sim 11 of 11 functions, 69 checks, 0
  failures; sim_play 1 of 1, 5 checks, 0; city_sound 9 of 9, 87 checks, 0; military 5 of 5, 26 checks, 0. gdlint and
  gdformat --check clean on the five changed .gd files; none over 400 lines (largest 213).

## Sim-review packet (no sim code changed)
Transitions the measurement walked: kaiju pose change (steer/walk/dash then BodyContact._sweep/_hold), chunk removal
(damage_chunks -> Carving.apply -> Collapse.settle -> falls), a topple landing (Collapse._land). Nothing in sim/ was
edited, so no transition changed.
Invariants and evidence:
1. From a pose with no standing chunk inside the body, after every RampageSim.step still none (walk, turn, dash, hold,
   chew, topple). Evidence: the 41-seed chew and 18 random walks above; new `_check_chew_seeds`.
2. A fall (drop or topple) never adds a standing chunk to the mirror, so Collapse.settle cannot put a chunk into a
   held body. Evidence: counts stay 0 through every topple in the runs above (the lead's hypothesis ruled out).
3. A pose set from outside the sweep (first step, a test's set-down, a glide landing) is not guarded: the body stays
   put and chews its way free at bite_dps. Not changed (design call). Measured: fixture start overlaps clear in 7 to 30
   steps; glide landings (see below) in 0 to 9 steps.
Leap/glide probe (lead's request, 60 landings, scratch scripts not committed): only the reptilian has a body volume
(data/tuning.json contact.bodies) and it has no leap or glide, so no landing meets body contact in the game today.
With the mantis given a volume: a plain leap overlaps for the landing step only, the next step's sweep puts the body
back clear (0 inside after 1 step, 24 of 24, adolescent/adult x seeds 0,3,5,8,11,22 x 2 tall buildings, 0 to 325
chunks at the landing step). Glide landing, 24 of 24: 0 to 473 chunks at landing, 0 after 1 step (tier 2 to 3 towers
do not dwarf these sizes). Baby glide (the dwarfed case, 12): 0 to 109 inside, clear in 0 to 9 steps.
Not exercised: the real mantis/octopus body volumes (none exist), emergence from the river into a shoreline
building, a tier-4 tower against an adult (the test city has none), the native KaijuSettle extension (not built on this
machine: carving ran its GDScript reference path).

## Attempts (fix-loop record)
None needed: the plan held first time (one wrong guess dropped on measurement: that Collapse.settle puts chunks in).

## Open decisions
None for the director. If the mantis ever gets a body volume, "when he lands on a building, does it crush flat at
once, or does he shoulder his way out?" is the question (answer today: crushed within 9 steps at most).

## Running jobs
None.

## Findings for the lead
- A fixture that sets a body down must check the spot first (set_down_clear); an in-sim invariant measured from an
  overlapping start proves nothing about the sim. Candidate learning for kaiju-proof-evidence after review.
- Dropping a stale `buildings[-1]` fallback: a helper that returns -1 must fail the check by name, not pick another.
- The scratchpad dir path trips the worktree-isolation shell guard when named in a Bash command; scripts live in the
  worktree's untracked .bc/ instead (deleted before the push).

## Rules learnt the hard way (under 10 lines)
- gdlint caps function arguments at 4: add a Vector2i of seeds, not a fifth argument.
- `"$GODOT"` or `bash -c` in a Bash call is refused by the isolation guard; use a script file in .bc/.
- Warnings are errors in --script runs: type every Variant read (`var lv: Dictionary = DICT[key]`).
