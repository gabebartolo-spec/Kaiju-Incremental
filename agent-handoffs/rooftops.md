# Rooftops handoff, 2026-10-18
## State: running a check (pacing on/off; then PR into claude/look-options; clip waits on the GPU slot)

## Who
Session "Kaiju: Rooftop defenders" (started by LEAD = "Kaiju: Lead"). Reports to LEAD, at most 8
lines, with the PR number and head SHA. Worktree .claude/worktrees/elastic-snyder-033782, branch
claude/rooftop-defenders off origin/claude/look-options (67986f1). PR into claude/look-options, never merge.

## Task (D-063, director 05:50)
"put soldiers/gun bearing citizens defending their homes on rooftops shooting at the kaiju".
Shots hurt: chip damage, no new escalation curve.

## Done (local, all suites green)
- sim/army.gd: Army.Squad. Placed at city start from Seeds.derive(army rng, 0x2007): buildings >=
  min_height, seeded Fisher-Yates, chance each, cap max_by_tier, top-layer cell, off the stair-hut corner.
  Fire every fire_interval in range (ground plane); volley = damage_by_tier x threat() (the tank
  armour curve). Die when the roof chunk is not alive, or via splash() from hit_area when the attack
  reaches the roof floor. Paid via clear_dead with rooftop_rubble[tier] x rubble_mult.
- sim/rampage_sim.gd: hit_area -> army_units.splash (also clears dead tanks); result()["rooftops"].
- data/tuning.json army.rooftop: min_height 4, chance 0.3, max_by_tier 6/10/14/18, squad_size 3,
  fire_interval 2, range 16, damage_by_tier 0.3/0.5/0.8/1.2, rooftop_rubble 1/3/8/18, radius 0.5,
  max_drawn 36.
- scenes/rooftop_view.gd: VoxelPerson.rifleman figures (5 outfits), MultiMesh flash and tracer pools,
  dust + "+N" on death, Sfx "rifle" (no stream yet). Wired in scenes/rampage.gd (now 400/400 lines).
- tests/lib/sim_rooftops.gd (11 sim checks incl. the effect fixture), 2 flow checks; floors sim 50, flow 102.
- tools/capture/capture_rooftops.gd: Behemoth clip + stills + rooftops.json (squad screen spots for the crop).
- Evidence logs (failing first, passes, bench): %TEMP%/rooftops_ev/. Bench script: scratchpad rooftop_bench.gd.
- PR body draft: scratchpad pr_body.md (PACING_LINE / CLIP_LINE placeholders).

## Decisions taken (flagged to LEAD)
- Armour does not reduce rifle chip. Brood young don't draw rifle fire. Figures vanish when the fall starts.

## Next
1. Pacing on vs off -> PR body. Commit, push, open the PR, bind it, report to LEAD.
2. Clip: local GPU slot (asked LEAD) or CI `tools/capture/ci_capture.sh --movie --resolution=1920x1080
   --fps=60 capture_rooftops.gd -- --out=<dir>`; trim to 3 s with ffmpeg; 2x crop of one squad from a
   still using rooftops.json spots. Clips go to LEAD (art QA), never straight to the director.
3. LEAD's sim review -> fixes.

## Don't touch
scenes/biped_swing.gd, scenes/gait_clip.gd, scenes/city_ground.gd, scenes/ui_kit.gd.
