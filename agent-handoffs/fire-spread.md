# Fire-spread handoff, 2026-10-22
## State: working (rebuild on the newest base, push, report)
## Task
R 26.2-26.4 fire spread in the sim (mailbox to-nimbalyst/016, answers 016-ANSWERS, D-126, D-129): heat meter,
neighbour spread with wind, glow, burn-out collapse, payout, five nodes, fire suite, player-effect fixture,
sim-review packet (below), full suite once, one ~6 s clip at the game camera (local GPU), push, report.
## Branch and commit
claude/fire-spread, rebuilt on origin/claude/look-options 802636cd (own commits cherry-picked; backup ref
claude/fire-spread-pre-rebase = old history, local only). Not pushed yet.
## Unfinished changes
- Full suite done: all 23 suites passed (tools/run_tests.sh with import, on 802636cd). Then rebuild on newest origin/claude/look-options (ef9212ca moved: perf scans #148, no
  overlap), fire + scans suites, push claude/fire-spread (no remote branch yet), report.
## Evidence so far
- fire suite 9 of 9 functions, 16 checks, 0 failures; powers suite green; check_scripts 345 ok; gdlint, gdformat,
  tuning_keys, complexity_ratchet clean.
- Stage 4 (4,435 buildings, seed city 0 / army 0 / fire 0, every fire node, 6 blocks lit, 30 s): spreads to 359,
  971 fire events, replay hash 2138472427 both runs, biomass 2947.6 both; 201 burn-outs, 0 standing; near shares
  0.60-0.69, far max 0.17; fire's own bookkeeping 224 usec/tick (budget 1000); burn-out collapses 569 usec/tick
  more (2548 each). fire.spread fixture: without City Ablaze 0 burn-outs, biomass 1646.8.
- New checks shown failing on a known-bad tuning (burn_out_floors 0, conflag_max 2.0): shell checks, pay checks red.
- Clip (local GPU, NVIDIA RTX 4070 SUPER in the log): scratchpad fire_clip/fire_spread_r0.mp4, 13.3 s at game
  speed, tools/capture/capture_fire_spread.gd --run=0 (dusk): breath lights at 0.5 s, neighbours glow at 2.3/2.6 s,
  catch at 4.1/5.3 s, first burn-out collapse at 12.3 s. Longer than ~6 s because a burn lasts burn_seconds 6 +
  0.25 a floor after a 1-3 s glow (placeholders). Fire look is today's chunk fire on the roof (R 26.5 later).
## Sim-review packet (kaiju-sim-review)
Transitions: (1) tick: FireSpread.step runs once a tick inside SpeciesPowers.step (after the coats), the heat pass
every spread_tick s (a whole number of ticks), timers every tick; own stream Seeds.derive(powers rng, 0xF12E)
(derive draws nothing, so no other stream moves); wind drawn once at _init (fixed per run, D-115). (2) per-building
status: INTACT -> HEATING -> GLOWING -> BURNING -> BURNT; HEATING cools back to INTACT at 0 heat (room for fire
crews, #50); GLOWING/BURNING/BURNT never go back; a building smashed (alive_count 0) at any stage is BURNT.
(3) removal: burn-out breaks the lowest burn_out_floors floors and Collapse topples the rest like a smash (D-129);
pay_share on the Building scales every later pay of its chunks (burn_pay x conflagration, x far_pay past far_radius).
(4) ignition: City Ablaze (stat fire_spread) gates ignite/scorch/shelled; the beam's burn coat, the breath (chance
breath_ignite per building it reaches), shelled(at) for claude/clumsy-army (stub caller), blast(at, r) for
claude/city-explosives (stub caller, needs Firestorm). Save: none (fire state is per run, never saved).
Invariants and evidence: replay identical (stage-4 trace hash + biomass); no burning shell (pair + stage 4);
off without City Ablaze (pair + fire.spread fixture); burn-out pays ~0.6, never more than a smash (pair 0.60 exact,
stage 4 range); each node's effect (pair fixtures); per-tick cost (stage 4). Not exercised: army shells and explosive
blasts from real callers (branches unmerged), species other than the croc, a save mid-fire (no save state).
## Open decisions
- Placeholder numbers, node places and costs flagged for tuning (D-129): r_ablaze [2,4] 1500 .. r_firestorm [6,4]
  40000; conflag_max 1.15 / step 0.03 keeps a burn-out at 0.60-0.69 of a smash (lead 2026-10-22).
## Running jobs
none
## Findings for the lead
- Breath ignition barely lands at baby stage: the breath breaks the small blocks it reaches before scorch
  rolls (nothing left to burn), and a lit block it damaged often collapses within ~2 s; 2 of 4 seeded
  clip-script runs (--run 8, 9) lit nothing in 6 breaths. Tuning call: roll before the damage, a higher
  breath_ignite, or leave it (lead/director).
- The WIP burn-pay test counted the rooftop squad (army pay, full) as building pay: compare buildings only.
- Timing-based budget that includes collapses swung 1000 -> 1470 usec on a loaded PC; budgeting the fire's own
  bookkeeping (224 usec) and reporting collapses apart is stable.
## Rules learnt the hard way (under 10 lines)
- tests/lib helpers print passing numbers themselves (FireStage prints its lines): pass lines are not in the log.
