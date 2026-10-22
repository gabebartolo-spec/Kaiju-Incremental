## D-098 young croc retune A (steady upgrades)
Level-1 costs ~half of level 2 (claws 45, hide 45, stride 80, quake 100, rage 75, greed 125, frenzy 220, r_tail 200, r_momentum 400), evolve1 600; young rooftop sting 0.011 -> 0.05, Behemoth 0.012 -> 0.055 (same x4.5, so sim_rooftops order holds); young tank_rubble 2 -> 5, rooftop_rubble[0] 1 -> 3. Also carries the army alert ramp from closed #85.

## Evidence (tools/pacing.gd, reptilian, seeds 0-7 x 30 runs; the bot plays worse than a human)
| | before (ramp 8 draft) | now |
|---|---|---|
| e1 | 0.295 h | 0.271 h (target 0.24-0.27) |
| young defeats /15 | 8.4 | 5.3 (target ~8.5) |
| buys per death | 1.79 | 1.97 (target 2-4) |
Defeats miss: ramp 8 s gives 8.4 but fails the sim_alert "caught unaware" check (not weakened); tank_damage and fire_interval barely move it. Balance is his playtest, not settled.
Suites: growth, powers pass. sim: 1 failure "armoured scales cut the damage taken" (equal values; also failed before this change). flow passed pre-sync.
## Not exercised
Military suite (3 failures seen pre-sync, unverified against baseline); no playtest.
## Board and log
None (D-098 already logged).
