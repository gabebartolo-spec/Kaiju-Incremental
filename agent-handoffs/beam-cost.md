# beam-cost (builder, branch claude/beam-cost, worktree .claude/worktrees/agent-a1448c3e2dfa8c9e5)
Task (lead brief): D-167 "Cheaper Thunder Beam": r_beam's three costs lower so the LAST unlock of the reptilian tree lands
at about 2 h (D-156). Change only r_beam's cost rows in data/upgrades.json. Baseline (lead, 109 seeded runs): evolve1 0.16 h,
evolve2 1.28 h (run 55), r_beam L1 2.11 h (run 88), last unlock 2.62 h (run 109); r_beam 160,020 / 266,700 / 419,100.

## State: STOPPED at step 1 (brief says stop and report if no r_beam price alone reaches about 2 h). No data file changed.
- Method: python replay of the baseline's per-run rubble (scratchpad pace_after_rept.txt, verbose) through pacing.gd's
  cheapest-first buying with the real upgrades.json. Scripts: scratchpad/beamcost/replay.py, sweep.py, sweep2.py.
  The replay reproduces the baseline marks exactly (evolve2 run 55, beam L1 run 88, last run 109, 2.62 h).
- Result, income per run held fixed (Colossus runs are city-capped at 30-46k rubble, ~70 s + 20 s tree):
  beam free (0/0/0): last unlock 2.11 h (run 88). The other Colossus nodes alone (regen 293,370, sig_reach 182,880,
  apex_claws 471,150, adrenaline 223,520 = 1,170,920, plus r_firestorm 40,000) need ~33 runs after evolve2.
  beam x0.8 2.50 h, x0.6 2.41, x0.5 (80,010/133,350/209,550) 2.36, x0.4 2.31, x0.3 (48,006/80,010/125,730) 2.26,
  x0.2 2.21, x0.1 2.16, x0.05 2.14.
- If the four other Colossus nodes are also cheaper (director chose the beam only): others x0.7 + beam x0.3 = 2.04 h;
  others x0.6 + beam x0.3 = 1.97 h; others x0.6 + beam x0.5 = 2.09 h; others x0.8 + beam x0.3 = 2.11 h.
- Not measured: whether owning the beam earlier lifts income (burning buildings), and the army's stage_growth rises with
  Colossus levels owned. Only a real pacing run (3533 s wall, timeout 5400) shows it.

## Next (after the lead's answer)
Edit r_beam's cost row (and, if the lead rules it, the other four nodes), run tools/pacing.gd --species=reptilian once,
then the suites that read upgrade costs (grep tests/ for r_beam and upgrades.json: flow_save, fire, flow, powers,
tentacles), lint (tuning_keys, complexity_ratchet, check_scripts), push claude/beam-cost, report.
