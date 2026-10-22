# Clumsy-army handoff, 2026-10-22 (builder; rebuilt on the squashed base)
## State: sim-review FIX round done, pushed to claude/clumsy-army-v2 (2026-10-23); lead merges after CI
## Task
Director comments #18: "tanks shouldnt be perfectly accurate every time, i really like the idea of a clumsy military
which destroys parts of its own city occasionally". Ruling: misses land beside him (ring round the kaiju, radius 2.5 m).
Bar, never loosened: the army's damage to the kaiju per minute within 5% of the base at tiers 2 and 4.
## Sim-review FIX round (lead brief 2026-10-23; D-066 budget, D-157 stray destruction counts) - DONE, pushed
1. hit_mult: REMOVED (tuning key, army.gd, probe). Cause of the old "-6.5% at tier 3": the luck of the hit rolls, not a
   mechanism. A hit does damage / chance, so each run's sampled damage carries ~12% of Bernoulli noise (30-50 shots at a
   0.6-0.9 chance); 12-36 sampled seeds cannot resolve 5%. Shots (+0.5% t2, -0.3% t3, +4.9% t1), squad volleys (-0.2%) and
   tanks in range are unchanged; what strays really do: +2-6% towers toppled, +1-9% roads shut, +1.5-4% chunks broken.
2. Budget with helicopters ON, 24 seeds, 120 s, hit_mult 1.0 (= final code): see PR body table. Expected damage (shots x
   hit damage + squads + helis) has the smaller SE: tier 1 +4.7 +- 3.2%, tier 2 +0.5 +- 3.0%, tier 3 -0.2 +- 2.4%; as it fell
   -1.5 +- 5.0, -0.2 +- 3.7, -3.3 +- 3.0. Tier 1 extended to 48 seeds (see PR). Tier 4 gone (D-135).
3. demand_way skips at yield_all >= stuck*3. tests/lib/military_yield.gd failed first (B yields 60.0 s, 0 free steps), now
   max 8.1 s and 7 free steps in 60 s.
D-157 test: tests/lib/military_stray.gd _counts_as_destruction (real shot -> stray_landed -> biomass, ruin, threat, heli cap);
failed on a "wrecking earns nothing" mutation (3 new checks red), green on the code.
Suites on the final tree (no full suite on this PC, director rule): military 26/0, sim 66/0, sim_play 5/0.
Probe: tools/strays_damage_probe.gd (helis on, ROW lines, expected damage, cause counters; 2 at once, engine_slot.sh first).
Gotchas: the shared scratchpad is shared with the lead's session (own subfolder clumsy/); the Bash tool does not kill
background jobs but the lead's pause did (exit 127); probe chunks of 6 seeds, detached with nohup.
## Branch
claude/clumsy-army-v2 = origin/claude/look-options 56d92a1b + the branch's own commits cherry-picked (backup ref
claude/clumsy-army-pre-rebase = old tip cfd2fb3d). The old claude/clumsy-army on origin is not an ancestor: push to -v2.
Conflicts met: street_life/city_view crush(by_tank, by_army) both kept; stray fx moved into TankYard.fire(event, ...)
so Rampage._on_event does not grow (complexity ratchet); crush_all split (_crush_stadiums, _count_crushed).
## What the branch does
- sim/stray_shell.gd: hit chance .9 near -> .6 far over reach; a hit does damage / chance; a miss lands on a ring round
  the kaiju (body + U(4, 14) m, random angle) and breaks floors 0..3 within 2.5 m. Tuning: data/tuning.json army.miss.
- Fans and people a stray kills are army_killed, not the kaiju's. Tests: tests/lib/military_stray.gd, flow_stadium.
- tools/strays_damage_probe.gd: fixed-path probe (scripted square loop, no autoplay, air off, kaiju hp 1e6), base mode
  (hit_near = hit_far = 1.0) vs strays, per seed; prints ROW lines and TIER summaries. Usage in its header.
## Result (72 seeds per tier, 120 s each, tuning unchanged)
- Tier 2: base 190.33 -> strays 192.33 damage/min (+1.05%); shots 3949 -> 4007, misses 1427.
- Tier 4: base 421.79 -> strays 416.89 damage/min (-1.16%); shots 5344 -> 5344, misses 1988.
- Run on the pre-rebase tree; after the rebase seeds t2 4-5 and t4 0 reproduce digit for digit (sim path unchanged).
## Convoy fix (lead ruling (a), 2026-10-22) and sim-review packet (kaiju-sim-review)
Cause (tier 4 seed 1, autoplay kaiju at 5.5 m/s): two tanks retreat through one T-junction. The younger waits its
turn at 1.5 m/s while the older stands blocked inside the 12 m danger radius; a third tank yields 2 s standing under
the kaiju. Touch failures are the turrets of tanks swept by a kaiju 3 m away. Fix, sim/tank_spacing.gd only:
- outranks(a, b): a tank inside the danger radius outranks one outside it, else the older (was: the older). give_way
  uses it (a tank in danger never yields to one that is not).
- demand_way: held up by a tank outside the danger radius while inside it, the blocker gives way at once (give_to,
  yield_t) - called from give_way, so Convoy._drive is unchanged (complexity baseline untouched).
- back_off: at retreat_speed pace (not reverse pace) when the tank it makes way for is in the danger radius.
Transitions: tank right of way / yield (Convoy._drive -> give_way -> yielding -> back_off); nothing else.
Invariants: no RNG draw added or removed (convoy is deterministic; no Seeds use in the diff); no new tuning key or
state (uses give_to, yield_t, cfg retreat_speed, army speed and reverse); hull, road and clash checks unchanged
(back_off still needs drivable and blocker == null), so no tank overlaps are allowed that were not before;
nothing persisted (no save change). Same-seed runs are identical (military suite runs each rampage twice).
Evidence: military 20/0 (tiers 1, 2, 4 x seeds 0, 1, 2); before the fix 18/2 on the same tree. Ablation: the pace
change alone left the standoff check at 88% (fail), so all three parts stay. Seeds 3-8 (scratch run, test unchanged):
base d6685f34 also fails touch (63 pairs) and standoff (93%): the test only holds on its own seeds, a base weakness;
with the fix touch 67 pairs, standoff 87% of 39, longest 0.3 s (was 0.6 s). Not exercised: reverse-speed changes
across other tiers beyond the suite; helicopters.
## Final evidence (tip after the convoy fix; tier 4 cut by D-135, so tiers 2 and 3)
- Damage per minute, final code, base vs strays, 12 seeds each, 120 s: tier 2 193.5 -> 188.8 (-2.4%, 12 seeds),
  tier 3 177.8 -> 172.8 (-2.8%, 12 seeds). Both inside the 5% bar. (Earlier 72-seed run on the pre-fix tree: tier 2
  +1.05%, tier 4 -1.16%.) Seed noise is large (1 SE about 5%); 12 seeds is the lead's choice.
- Full suite tools/run_tests.sh: All checks passed (21 suites), exit 0, with the military suite on tiers 1, 2, 4 x seeds
  0, 1, 2 at 20/0.
- Clip: strays_ring_v2_6s.mp4 in the clumsy-army notes folder (seed 4, 36 s render, cut 29.8-35.8 s, local RTX 4070
  SUPER, 4 of 4 shots missed at frames 1640 1773 1906 2039). Not yet QA'd by the lead.
## Clip critic FIX round (lead, 2026-10-22) - code in, clip not re-cut
1. Tracer vs impact: view-only mismatch plus a sim timing fact. The sim landed a stray at fire time, the tracer took
   0.22 s, and the impact popped at fire (14-16 frames early); a miss's tracer also sparked at its landing. Now: army
   keeps missed shells in flight for army.shell_flight (0.22, data) and emits stray_landed then the break; the view
   draws the tracer to the landing for the same time with no hit spark (TankFx.fire_shell miss) and the impact comes on
   stray_landed (TankYard.on_event handles tank_fired and stray_landed; Rampage._on_event shrank, baseline row gone).
   RNG: the landing is still drawn at fire time from the same stream; strays now land 0.22 s later (same seeds).
2. HP 160 -> 159: rooftop squads (rooftop_fired, 0.01-0.02 each per volley, headless seed 4: HP lines all carry a
   rooftop_fired event, none a stray); the readout rounds. Not the strays.
3. Impacts: headless seed 4 showed 3 of 4 misses broke nothing (they landed on streets). StrayShell.landing now tries
   up to army.miss.ring_tries (6) ring spots and takes the first within the blast radius of a standing building
   (draw count varies, same stream); impact fx: 8 debris, flash 9.0, a dust cloud. Not yet measured: chunks per miss
   with the new landing (capture_strays now prints CHUNKS and HP lines headless: godot --headless ... --seconds=36).
4. Re-cut with the breath-aim indicator off and a closer camera: NOT done (paused).
Open: military suite 19/20: tier 4 seed 1, tank 17 yields 0.9 s standing under the kaiju (steps 508-523); tier 4 is cut
(D-135), so this goes away with the tier-4 rows if the lead drops them; otherwise the yield rule needs one more case.
Not run on this tip: full suite, damage probe (strays land later and on buildings: re-probe tiers 2 and 3 before the PR).
## Final evidence (tip after merging origin/claude/look-options 6f86d7a8; hit_mult 1.04 since removed, see FIX round)
- Full suite tools/run_tests.sh: All checks passed (25 suites), exit 0 (military 20/0 on the new seeds; flow dash check
  failed once under heavy load and also on the untouched base 6f86d7a8, passes in the full run: a load flake).
- Damage per minute, base vs strays (hit_mult 1.04), 12 seeds, 120 s: tier 2 193.5 -> 196.1 (+1.4%); tier 3 177.8 ->
  172.9 (-2.7%). Without hit_mult tier 3 was -6.5% over 36 seeds (three batches -6.4/-4.8/-8.3%), so the margin is the fix.
- Headless seed 4 (capture_strays CHUNKS): both strays break chunks (781 and 695) 14 frames after the shot.
- Clip critic FIX points (tracer to landing, impact on arrival, hit spark off for a miss, bigger impact, aim wedge off,
  closer camera --closer=0.6 in capture_strays): in code; one closer clip NOT rendered (D-146).
- street_life.gd is 400 lines: the army's dead are counted in scenes/army_toll.gd (ArmyToll), CityView.crush(by_army).
## Left
Lead: merge. Next builder: if a motion check is wanted, capture_strays --seconds=36 --seed=4 (local GPU, override.cfg).
## Findings
- The spawn camera sits inside a tower for a kaiju at its rise point (standing captures render black).
- Autoplay damage probes are the wrong instrument for a change that alters the city.
- Never leave a temp probe in tests/ during a suite (smoke compiles every script).
