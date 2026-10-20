# carve-wp5 handoff (builder, WP5 physics presentation of carving)
## State: life 4 (critic round 2 fixes) pushed at b2442b5; CI captures (gl_compatibility, green) tower 39372583855, swipe 39372587203, block 39372590079 in wp5-recap/ci4_<scene>. pr_body_wp5.md updated (untracked).
## Life 4 fixes (local headless 30 fps seed 7; before cecfac8 / after b2442b5)
1. Slab lands whole: IslandBody._split, island <= split_bricks 48 splits into ~4-brick seeded chunks on a hard hit.
   Largest island at end tower 1808 -> 0 cells, block 889 -> 980 (settled chunk). Rubble past cap fades (VANISHED 3652 -> 0).
2. Staircase shear: break_ragged 2.0 x FastNoiseLite (freq 0.3, seed hash(seed, building)). Front spread tower 0.246 -> 0.508, block 0.241 -> 0.478.
3. Debris in glass: CarveDebris._indoors (footprint - 0.5, standing cell above) fades at rest or after indoor_seconds 1.0.
   Swipe INSIDE per s 264 at end -> 2.
Local clips: %TEMP%/claude/wp5-recap/local4_<scene>/clip.mp4 (+ before/after_headless.log).
## Open
- gdlint max-file-lines: carve_debris 539, capture 460 (over at cecfac8 too), island_body 437.
- Fires hover where a mid-air break spawned them (not in brief).
- Life 3 numbers: see pr_body_wp5.md "Motion-critic fixes (life 3)".
