# Rooftops handoff, 2026-10-18
## State: available (PR #40 MERGED into claude/look-options at ea6de01; worktree already removed)

This is the final agent-handoffs/rooftops.md. The worktree was removed before it could be committed,
so the lead lands this file in its next handoff/board commit (the copy on look-options is the
pre-merge one, which says "awaiting lead").

## Who
Session "Kaiju: Rooftop defenders" (started by "Kaiju: Lead"). Branch claude/rooftop-defenders is
merged; delete it with the lead's usual cleanup (local and origin both still exist).

## Task (D-063, director 2026-10-18 05:50)
"put soldiers/gun bearing citizens defending their homes on rooftops shooting at the kaiju". Shots
hurt: chip damage, no new escalation curve. The lead accepted that armour doesn't reduce the chip and
tabled it for the director as a balance note.

## What shipped (#40)
- sim/army.gd Army.Squad: placed at city start from Seeds.derive(army rng, 0x2007). Candidates are
  buildings >= min_height, in a seeded Fisher-Yates order, each kept with chance, capped by
  max_by_tier; the squad stands on a top-layer cell. It fires every fire_interval in range;
  volley = damage_by_tier x threat_scale(). It dies when its roof chunk dies or a hit_area splash
  reaches its floor (splash() also clears dead tanks), and pays rooftop_rubble[tier]. result()["rooftops"].
- data/tuning.json army.rooftop (all the numbers, incl. max_drawn 36). Pacing: no change (0.58/4.45 h
  vs 0.59/4.46 h).
- scenes/rooftop_view.gd, built and fed by scenes/powers_view.gd (rampage.gd sits at its 400-line cap):
  - VoxelPerson.rifleman figures at 1.5x.
  - Flashes and sparks are 4-point star billboards counted in frames: flash 0.5 u for 3 frames, rifles
    1 frame apart; spark 0.9 u for 4 frames, no depth test.
  - Tracers are 1.75 u streaks at 60 u/s, depth-tested. None when the shot is point-blank (<3 frames)
    or its screen path is under 60 px.
  - Rounds strike the centre of the nearest upper-body bone (TARGETS), held to the bone.
- Tests: tests/lib/sim_rooftops.gd (11 sim checks incl. the player-effect fixture "army.rooftop") and
  2 flow checks; floors sim 50, flow 115.
- Tools: tools/capture/capture_rooftops.gd picks the stand spot with the most squads firing on screen
  and logs volleys and sparks. tools/capture/rooftop_hit_gate.gd (headless silhouette gate) and
  tools/capture/spark_gain.py (spark brightness measured from the movie).

## Lessons (for the lead to judge for the playbook / skills)
- The headless (dummy) renderer keeps no MultiMesh instance data: get_instance_transform returns
  nothing useful. A gate built on it passed 27/27 while the footage missed. Build masks from source
  data (KaijuRig.voxels_of cells) and prove the gate on a known-bad control: hits shifted 2.5 u gave
  9/27 and exit 1.
- get_viewport().get_texture().get_image() inside a capture lags the sim by a frame or two; measure
  effects from the recorded movie instead (spark_gain.py found the offset itself).
- Rig voxels (KaijuRig.skins) don't match the drawn VoxelSkin closely enough to hit "the surface";
  aiming at bone centres the body surrounds is robust.

## Open (lead's post-merge notes; a follow-up card was proposed to the user)
- Some sparks sit on the shoulder edge: move the targets 8-10 px inward onto the spine/arm mass.
- Flashes come out about 8 px at the game camera and are still easy to miss.
- About 1 s dead gaps make the fire feel sparse; the lead puts the density/visibility question to the
  director first.

## Evidence
Lead notes folder rooftops/ (fix through fix6): clips, crops, gate logs, spark_gain.json, bench and
pacing logs.

## Don't touch (when this was assigned)
scenes/biped_swing.gd, scenes/gait_clip.gd, scenes/city_ground.gd, scenes/ui_kit.gd.
