# explosives-view (red-barrel blasts VFX, comments #19 #20) - handoff

Branch claude/city-explosives-v2 (the round-5 work cherry-picked onto origin/claude/look-options ef9212ca; the
old claude/city-explosives sits on the pre-squash history, backup ref claude/city-explosives-pre-rebase).
Full history of rounds 1-5 (measurements, critic notes):
side-session-notes/local_df2c2989-951e-4b20-9998-9c23b0a37f42/explosives-view/handoff.md.

## State (2026-10-22): round 5 finished, ready for the lead's QC and a PR
- Code: sim/explosives.gd, city_hazards.gd, hazard_shape.gd (the three models), scenes/blast_fx.gd,
  blast_parts.gd, blast_shock.gd, blast_break.gd, blast_voxel.gdshader, blast_ripple.gdshader, tuning "blast_fx".
- Clip: proof explosives_game_r5_final.mp4 (side-session-notes/.../explosives-view/proof/), 6.0 s, 1920x1080 60 fps,
  game camera, audio; local GPU (RTX 4070 SUPER, Forward+), --city=small --seconds=12 --fixed-fps 60, cut at the
  log's "film from frame 214" (-ss 214/60). Chain that blew: fuel silo + chem lab (2 hit-stops).
- series.py over the 360 frames (60 fps; crop x 850-1500, y 150-520): orange pixels hold ~1800-1900 from frame 88 to
  ~140 (0.9 s), gone by 158; gas (green) 700 at 108, 3900 at 118, 8300-12900 from 150 on, easing to ~7800 by 290;
  near-white peak 300 px at frame 118 (the flash); screen ripple shows as calm-area change 13.5 at frame 148.
- 2x crops judged: solid orange lit cubes with correct depth (trees cover them), yellow-green gas cubes, kaiju
  clear of the blast. Fireball saturation ~0.80 under AgX (lead accepted).

## Rebase notes (what differs from the old branch)
- Base added CameraShake (rotation trauma). The blasts keep their own aim jitter on top: BlastFx.jitter() scaled
  by the camera-motion setting, applied in Rampage._place_camera. Routing blasts through CameraShake.add_trauma
  (smooth, rotation only, no kick) is a feel change: the lead's call.
- Ratchet and 400-line cap fixes (behaviour kept): Rampage._read_input, AbilityFx.update_powers (was
  Rampage._update_powers), BuildStages.finish, BlastFx.attach, CityHazards.tag takes the quay sheds,
  HazardShape split into _silo_pipe / _silo_centre / _fireworks_sign / _fireworks_crates / _chem_walls /
  _chem_parapet / _chem_roof, HazardVoxels._outside_air. A carved building's blow is armed by Explosives' own
  polling (_hurt: carving.promoted) instead of a call in RampageSim.hit_area (one step later at most).

## Left / not exercised
- Frame times not measured; fireworks factory did not blow in the clip's chain (out of reach); day only; no night clip.
- Open: sfx-pool hero category; ElevenLabs takes (blast_crack, blast_body, blast_rumble, sonic_boom,
  fireworks_crackle, chem_hiss) still wanted.
