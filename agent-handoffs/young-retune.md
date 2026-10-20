# young-retune (builder)
State: stopped by lead 8. NOTE: tuning was already committed, pushed and PR #107 opened (head 3829b48) before the stop message arrived; lead decides to close it or not.
Best variant (data/tuning.json in 3829b48): young sting 0.05, Behemoth 0.055, tank_rubble 2->5, rooftop_rubble[0] 1->3, alert ramp left at 20 s. Costs/evolve1 600 in data/upgrades.json.
Pacing (reptilian, 8 seeds x 30): e1 0.271 h (target 0.24-0.27), young defeats 5.3 per 15 (target ~8.5), buys/death 1.97 (target 2-4).
Military suite: 3 failures (tank fallback speed, hull along road, standoff band); seen on the pre-sync head, not compared with a baseline; may come from the #89 tank_spacing merge rather than the tune. sim: "armoured scales" fails at baseline too.
Left: defeats miss (ramp 8 gives 8.4 but breaks sim_alert check; tank_damage/fire_interval no effect); check military on look-options without this tune; playtest.
