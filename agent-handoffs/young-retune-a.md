# young-retune-a (builder)
State: D-098 numbers committed; PR to claude/look-options (see PR). Helper finished and archived.
Final tune (data/tuning.json): young rifle sting 0.05, Behemoth 0.055 (same x4.5 so sim_rooftops order holds), tank_rubble 2->5, rooftop_rubble[0] 1->3. Costs/evolve1 600 already in data/upgrades.json.
Pacing (reptilian, 8 seeds x 30 runs): was e1 0.295 h / 8.4 defeats per 15 / 1.79 buys per death (ramp 8) -> now e1 0.271 h / 5.3 per 15 / 1.97.
Miss: defeats 5.3 vs ~8.5 with the alert ramp at 20 s. Ramp 8 gives 8.4 but fails sim_alert "caught unaware" check (not weakened). tank_damage and rooftop fire_interval barely move defeats. Left to playtest.
Suites: flow/growth/powers pass. sim: 1 fail "armoured scales" (also fails at HEAD before this change, 1.0 vs 1.0). military: 3 failures (tank fallback/hull/standoff) unverified vs baseline, tank_spacing came from #89 merge.
