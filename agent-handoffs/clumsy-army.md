# Clumsy-army handoff, 2026-10-22 (builder; rebuilt on the squashed base)
## State: probe passed; full suite running; clip and push left
## Task
Director comments #18: "tanks shouldnt be perfectly accurate every time, i really like the idea of a clumsy military
which destroys parts of its own city occasionally". Ruling: misses land beside him (ring round the kaiju, radius 2.5 m).
Bar, never loosened: the army's damage to the kaiju per minute within 5% of the base at tiers 2 and 4.
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
## Left
1. Full suite (tools/run_tests.sh) on the rebuilt tip: running; log in the lead scratch ca2/full.log.
2. Push claude/clumsy-army-v2; lead opens the PR.
3. One ~6 s clip at the game camera (capture_strays --seed=4 --seconds=36), local GPU, off-screen no_focus override.cfg.
## Findings
- The spawn camera sits inside a tower for a kaiju at its rise point (standing captures render black).
- Autoplay damage probes are the wrong instrument for a change that alters the city.
- Never leave a temp probe in tests/ during a suite (smoke compiles every script).
