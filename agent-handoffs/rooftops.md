# Rooftops handoff, 2026-10-18
## State: awaiting lead (critic FIX 4 re-clipped in rooftops/fix5/, hit gate 27/27; fresh critic, then merge)

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
- Flash tweak (lead): flashes are now 0.35 u soft star billboards (procedural 32 px texture,
  additive, fog-free), FLASH_AHEAD 0.2 u out along the aim, the rifles 1 frame apart; sparks use the
  same star. Re-clip is in rooftops/fix2/: the flashes PASSED a fresh motion-critic.
- Critic FIX 2 (coded in b358186): tracers are 1.75 u streaks flying at 60 u/s; the round strikes the
  rig bone nearest the shooter (above FEET_CLEAR), pushed out 0.35 body-radius; the star spark lands
  at the tip on arrival; TRACER_HOT 2 and 0.05 wide. The capture runs 6 s, logs volley_frames and
  takes stills 5 frames after a volley. Squad 6's "ledge" was checked in the sim: an intact top layer.
- Critic FIX 3 (deda6cc + capture): sparks are stars with no depth test for 7 frames; flashes counted
  in frames (4, one-frame stagger, 0.45 u ahead); point-blank (<3 frames) means no tracer; rounds aim at
  bones above 1.15x the hip height. The capture picks the stand spot with the most squads firing on
  screen (seed 0: 3 firing, 5 on screen; no seed 0-11 gives 4 firing). Movie-measured sparks: min
  gain +0.42, median +0.62 luminance.
- Critic FIX 4 (79e2c27), method change: scenes/kaiju_hit.gd hits the first rig voxel (KaijuHit.parts:
  every MultiMesh under the rig except VoxelSkin's) on the line from the muzzle to the nearest bone
  above the hips, held in bone space so the tracer end and the spark ride the body. The fallback is the
  nearest voxel. Stars are a sharp 4-point sprite, flash 3 / spark 4 frames with a fade; screen paths
  under 60 px get no tracer. The gate tools/capture/rooftop_hit_gate.gd (headless, projected-voxel
  silhouette) gives 27/27 inside; worst search 1.7 ms per volley. Movie sparks: min +0.49, median +0.65.

## Next
1. Lead's fresh critic on fix5 -> any fix -> rerun the gate first -> GPU go -> re-clip -> `python tools/capture/spark_gain.py
   <dir> <ffmpeg>` (each spark's brightness gain in the movie; the in-engine image lags, so not that).
2. After #40 merges, Military AI syncs onto it; this worktree can be removed by the lead.

## Lead rules (2026-10-18)
- Rooftops land BEFORE Military AI (local_5325ef73), which syncs after. In sim/army.gd keep hunks to the
  squad code, threat_scale() and the clear_dead tail; _spawn() is left as it was (Military AI edits it).
- rampage.gd is at its 400-line cap: no lines from this PR. Floors resolve to the real counts (flow 114).
- Armour does not reduce chip (lead accepted; tabled for the director as a balance note).

## Don't touch
scenes/biped_swing.gd, scenes/gait_clip.gd, scenes/city_ground.gd, scenes/ui_kit.gd.
