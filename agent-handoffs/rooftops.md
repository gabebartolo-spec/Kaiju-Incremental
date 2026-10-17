# Rooftops handoff, 2026-10-18
## State: awaiting lead (look FIX re-clipped on the GPU, head e57636e; lead checks, runs a critic, merges #40)

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
  Fire every fire_interval in range (ground plane); volley = damage_by_tier x threat_scale() (the tank
  armour curve). Die when the roof chunk is not alive, or via splash() from hit_area when the attack
  reaches the roof floor. Paid via clear_dead with rooftop_rubble[tier] x rubble_mult.
- sim/rampage_sim.gd: hit_area -> army_units.splash (also clears dead tanks); result()["rooftops"].
- data/tuning.json army.rooftop: min_height 4, chance 0.3, max_by_tier 6/10/14/18, squad_size 3,
  fire_interval 2, range 16, damage_by_tier 0.3/0.5/0.8/1.2, rooftop_rubble 1/3/8/18, radius 0.5,
  max_drawn 36.
- scenes/rooftop_view.gd: VoxelPerson.rifleman figures (5 outfits), MultiMesh flash and tracer pools,
  dust + "+N" on death, Sfx "rifle" (no stream yet). Built and fed by scenes/powers_view.gd
  (rampage.gd is at its 400-line cap on look-options; it is untouched).
- tests/lib/sim_rooftops.gd (11 sim checks incl. the effect fixture), 2 flow checks; floors sim 50, flow 102.
- tools/capture/capture_rooftops.gd: Behemoth clip + stills + rooftops.json (squad screen spots for the crop).
- Evidence logs (failing first, passes, bench): %TEMP%/rooftops_ev/. Bench script: scratchpad rooftop_bench.gd.
- Pacing on vs off: 0.58/4.45 h vs 0.59/4.46 h (no change). CI clip run 39061920261 (at ef33e9c):
  3 s 1080p clip, stills, 2x/4x crops, logs in the lead notes folder rooftops/.
- Look note: figures are about 10 px tall at the Behemoth camera; tracers read, flashes are faint. Scaling up
  is LEAD's / the director's call.

## Decisions taken (flagged to LEAD)
- Armour does not reduce rifle chip. Brood young don't draw rifle fire. Figures vanish when the fall starts.

## Review (lead, 2026-10-18)
- Sim review PASS at fa3ef77. Look FIX: squads and flashes were invisible at the game camera.
- Fixes: flashes 0.45 u, additive, unshaded, fog-free, 0.08 s; tracers 0.09 u with a 0.08 s hold;
  a spark on the hide; figures 1.5x, spaced 0.55. Flashes, tracers and sparks are drawn at HOT 4.0,
  over the glow threshold of 1.1.
- Root cause of the invisible tracers: they were aimed at the kaiju's axis and buried in its body.
  They now end on the near hide (_hide). The capture stands the kaiju 13 u off and takes stills
  2 frames after a volley.
- GPU re-clip evidence is in the lead notes rooftops/fix/ (clip, mid-volley still, 2x crop).
- Open: the 3 flashes merge into a block that hides the figures for 0.08 s. Offered ~0.3 u offset
  forward; the lead decides.

## Next
1. Lead's look verdict: if it asks for smaller flashes, change FLASH_SIZE and the muzzle offset, then
   re-clip (ask for the GPU slot; override.cfg first, delete after).
2. After #40 merges, Military AI syncs onto it; this worktree can be removed by the lead.

## Lead rules (2026-10-18)
- Rooftops land BEFORE Military AI (local_5325ef73), which syncs after. In sim/army.gd keep hunks to the
  squad code, threat_scale() and the clear_dead tail; _spawn() is left as it was (Military AI edits it).
- rampage.gd is at its 400-line cap: no lines from this PR. Floors resolve to the real counts (flow 114).
- Armour does not reduce chip (lead accepted; tabled for the director as a balance note).

## Don't touch
scenes/biped_swing.gd, scenes/gait_clip.gd, scenes/city_ground.gd, scenes/ui_kit.gd.
