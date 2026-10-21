# Clumsy-army handoff, 2026-10-21 (lead-10 builder, stood down at ~280k context)
## State: available (stood down with work left: restart fresh from this file)
## Task
Director comments #18: "tanks shouldnt be perfectly accurate every time, i really like the idea of a clumsy military
which destroys parts of its own city occasionally". Director ruling: misses "land beside him" (visible). Helis and a
HUD line are out of scope.
## Branch and commit
claude/clumsy-army @ 37590bb (pushed), look-options 8d6d7db merged in. Worktree ../Kaiju-Incremental-wt/clumsy-army
(native built in-tree; godot-cpp copied, gitignored). Base worktree ../Kaiju-Incremental-wt/ca-base: detached at
8d6d7db, native built (leave it; worktree removal is denied).
## What the branch does
- sim/stray_shell.gd: hit chance hit_near .9 -> hit_far .6 over reach; a hit does damage / chance (same expected
  damage). A miss lands on a ring round the kaiju: body radius + U(ring_near 4, ring_far 14) m at a random angle
  (lead option a); land() breaks floors 0..3 within radius 2.5 m (damage 8). Tuning: data/tuning.json army.miss.
- sim/army.gd shoot(); scenes: TankFx.stray fx; fans and people a stray kills are army_killed, not the kaiju's
  (StreetLife.crush/crush_all by_army; flow check _check_stray_fan, shown failing first).
- tools/capture/capture_strays.gd: walks 3 s in from the river (spawn camera sits inside a tower, R 19.4), then stands;
  prints each MISS with its on-screen pixel.
## Left (lead's steps, in order)
1. Fixed-path probe (lead): the kaiju stands or walks a scripted line (no autoplay, so strays cannot change its path),
   the same tanks fire with and without strays (for "without": tuning army.miss.hit_near = hit_far = 1.0 in a probe-only
   override, or the base worktree). 72 seeds per tier, tiers 2 and 4: kaiju damage per minute within 5%. If it misses,
   tune the hit damage in data until it is back (never loosen the bar). Probe kaiju HP is 1e6 (military_base set-up).
   Scratch probes to adapt: <lead scratchpad>/fire_probe3.gd, ca/fire_probe4.gd (PROBE_TIER), fireprobe*.sh.
2. Full local suite (SUITES_ONLY=1 tools/run_tests.sh --quick) with no tests/zzprobe dir present (a temp probe there
   made the smoke compile check red last time).
3. One ~6 s clip at the game camera: local GPU, off-screen no_focus override.cfg in this worktree (lead yes; CI
   llvmpipe timed out, run 39553440618). Seed 4: capture_strays --seconds=36 --seed=4; misses at frames 1640 1773 1906
   2039 before the radius change (re-check). Bar: >=2 misses visibly breaking buildings; check at game speed and 2x crops.
4. Push, report to the lead (8 lines, table + clip path). The hygiene agent opens the PR.
## Evidence so far
- Sim suite time: the 1147 s was a stale dll; rebuilt native: base 392 s vs branch 386 s (same load).
- Suites on the merged tree (before the ring): military 5/5 20, powers 12/12 25, flow 7/7 202, sim 12/12 71.
- Probe, autoplay, base 8d6d7db -> ring eb6e20b (radius 1.5), 36 seeds: t2 24.0 -> 20.6 (-14%), t4 239.9 -> 218.1
  (-9%). Roads blocked and tanks spawned are unchanged; autoplay paths diverge (t2 seed 10: 24 -> 4.5 shots/min).
  Few shots per seed (seed 26: about 11), so a ~30% miss rate swings per-seed damage.
- Clip (radius 1.5): of 4 misses, 2 on screen beside the kaiju (1 breaks a low wall, 1 is a flash and fire beside a
  building), 2 hidden behind it. Notes folder clumsy-army/strays_ring_6s.mp4, ring_miss_*_2x.png.
## Open decisions
none (lead ruled: ring, radius 2.5, 5% bar kept, fixed-path probe)
## Running jobs
none
## Findings for the lead
- The spawn camera is inside a tower for a kaiju standing at its rise point: every standing capture renders black.
- CI capture (llvmpipe, 1080p) cannot render a city rampage: 4.8 s in 100 min.
- An autoplay damage probe is the wrong instrument for a change that alters the city: the path diverges per seed.
## Rules learnt the hard way
- Never leave a temp probe in tests/ while a suite runs (smoke compiles every script).
- A seeded-chance change needs many shots per comparison; per-seed values swing.
