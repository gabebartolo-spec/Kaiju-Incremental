# Fire-spread handoff, 2026-10-22
## State: available (clip v8 rendered, pushed; report sent)
## Task
R 26.2-26.4 fire spread in the sim (mailbox to-nimbalyst/016, answers 016-ANSWERS, D-126, D-129): heat meter,
neighbour spread with wind, glow, burn-out collapse, payout, five nodes, fire suite, player-effect fixture,
sim-review packet (below), full suite once, one ~6 s clip at the game camera (local GPU), push, report.
## Branch and commit
claude/fire-spread, rebuilt on origin/claude/look-options ef9212ca (own commits cherry-picked; backup ref
claude/fire-spread-pre-rebase and -pre-rebase2, local only).
## Unfinished changes
- (c) DONE: the lit block was broken by the claw rake (swipe band 13 m x body scale 0.54 = 7 m, farther than the
  baby breath's 5.9 m, so no standoff avoids it; --stop only moves the kaiju, it does move). The capture now sets
  sim.stats["swipe_damage"] = 0 for the shot (clip setup, not a rule). Auto-pick, run 4, --stop=0.4: lights its
  own target 297 (79 chunks), no swipe break.
- (a)+(b) rendered: clip v8 (below). Judged in frames: no one-frame swap, no light pop (crop luminance steady
  101-109 over 12.2-14.8 s), the neighbour stepped block keeps its own embers (it is still burning).
- (d)/(e) diagnose only, NOT verified against a plain smash: the falling piece's look comes from
  BuildingView.lift_piece (scenes/building_view.gd:204) via CityView.fall_start (scenes/city_view.gd ~176), shared
  with every smash topple; a plain-smash capture is still needed to confirm.
- Done and pushed earlier: collapse cost 612 usec/tick (2 batches; hash 1292598282 x2).
## Evidence so far
- fire suite 9 of 9 functions, 16 checks, 0 failures; powers suite green; check_scripts 345 ok; gdlint, gdformat,
  tuning_keys, complexity_ratchet clean.
- Stage 4 (4,435 buildings, seed city 0 / army 0 / fire 0, every fire node, 6 blocks lit, 30 s): spreads to 359,
  1022 fire events, replay hash 145565713 both runs, biomass 2948.2 both; 211 burn-outs, 0 standing; near shares
  0.60-0.69, far max 0.17; fire's own bookkeeping 231 usec/tick (budget 1000); burn-out collapses 619 usec/tick
  more (2639 each). fire.spread fixture: without City Ablaze 0 burn-outs, biomass 1646.8.
- New checks shown failing on a known-bad tuning (burn_out_floors 0, conflag_max 2.0): shell checks, pay checks red.
- Clip v5 after critic FIX (PR #152), local GPU (RTX 4070 SUPER): scratchpad fire_clip/fire_spread_v5.mp4, 9.65 s,
  capture_fire_spread.gd --run=0 --stop=0.7. Times read from the frames at 10 fps: breath 0.6 s, fire on the
  stepped block's roof 0.8 s, burns to 7.5 s, ground floor gives way 7.6 s (tilts over), down in rubble and dust
  9.4 s. Burn-out now gives way over burn_out_seconds 0.6, downwind first (no one-frame swap); a roof burns with
  one chunk fire per roof quarter (view_size 1.2). Stage 4 after: replay hash 601823901 x2, 203 burn-outs, 0
  standing, bookkeeping 270 usec/tick, collapses 1727 usec/tick (settle runs per crumble batch).
- Clip v8 (local GPU, RTX 4070 SUPER): scratchpad fire_clip8/fire_spread_v8.mp4 (cut from 4.9 s, 9.9 s), command:
  capture_fire_spread.gd --run=4 --stop=0.4 (needs override.cfg no_focus in the worktree, delete after). Beats
  (physics frames): breath 314, lit 297 at 315, burns, gives way 749 (12.5 s), down 767 (12.8 s), dust to 14.8 s.
  Frames: ignition 5.0-5.5 s; stepped neighbour roof burns from 9.0 s; collapse 12.5-13.5 s, dust cloud 13.5-14.5.
  Shot is wide: the action is ~15 percent of the frame (game camera).
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
- Breath ignition at baby stage: the lead asked for the ignite roll before the breath's damage (done,
  BreathCone.breathe). Same 4 seeds before/after: identical (runs 0, 4 lit on the first breath; 8, 9 never in 6
  breaths): the rolls decide, not the order. A block lit and then wholly broken by the same breath is dropped
  BURNT next tick without heating anyone (making it spread is more than an ordering change: not done).
- The WIP burn-pay test counted the rooftop squad (army pay, full) as building pay: compare buildings only.
- Timing-based budget that includes collapses swung 1000 -> 1470 usec on a loaded PC; budgeting the fire's own
  bookkeeping (224 usec) and reporting collapses apart is stable.
## Rules learnt the hard way (under 10 lines)
- tests/lib helpers print passing numbers themselves (FireStage prints its lines): pass lines are not in the log.
