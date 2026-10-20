# carve-wp5 handoff (builder, WP5 physics presentation of carving)
## State: life 3 DONE. Head = sphere-off commit. CI clips (no sphere): tower 39356130302, swipe 39356732686, block 39357091553 (wp5-recap/ci_<scene>/). pr_body_wp5.md updated (untracked).
## Fixes (local headless, fixed-fps 30, tower/block; scratchpad before_*/oldphys_*/after2_*.log)
1. Hit detect over break_window 0.3 s (IslandBody._hit): longest wait between breaks tower 1.17 -> 0.13 s, block 1.43 -> 0.33.
2. Staged break bottom-up over break_stage 0.4 s; ground_drag 5/s, piece damp, settle 0.4/1.0/0.3 s.
   Live at end tower 257 -> 0 (fastest 3.01 -> 0.00), block 1094 -> 4 (7.5 -> 0.58); skid >5 widths 48 -> 12 / 19 -> 5.
3. fill_light 0.12 emission in CarveMesh.material (needs render numbers: dark px in gouge).
4. rubble_cap 2000 per building: tower 5707 -> 2001 (3,652 dropped), block max 1309 (under cap).
## Open
- Capture "breaks" now count break steps (130/821), not whole breaks.
- Black px: swipe lum<45 up to 1021 -> 0, darkest gouge px 73. Slab undersides now mid-grey.
- Capture blow sphere (test overlay) off by default; --markers opts in. 2 stills per scene viewed, none shown.
