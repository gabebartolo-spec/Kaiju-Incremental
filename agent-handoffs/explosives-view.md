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

## Round 6 (clip critic FIX, 2026-10-22): code committed 2b099979, suite + final clip pending
- Fireball 2-3x footprint (spread 1.5, speed 2.6, top 2.0, 520 cubes of 0.34), spawns over 0.08 s and grows in
  (size_curve), holds orange to 0.45 of 2.2 s then settles over ~0.6 s; measured orange bbox ~300x165 (first
  blast) to ~430x270 px at 1080p (was ~115x80), fade 62k -> 2k orange px over 36 frames (was 8).
- BlastFlash (scenes/blast_flash.gd): white sheet under the HUD, alpha 0.3 (x0.75 for small blasts), 0.05 s;
  measured mean luminance +16 / +21 / +15 on the three blasts' first frame, back to normal in 3 frames.
- Camera: ONE kick (BlastFx.jitter), up and away from the blast, squared ease-out over 0.15 s, x camera-motion
  setting; measured shift peaks ~17 px and decays monotonically over ~9 frames per blast (30 frames, 3 blasts).
  Firework bursts no longer kick.
- Removed: screen ripple (blast_ripple.gdshader, BlastShock.ripple) and the hit-stop (BlastFx.hold, Rampage).
- Audio: every blast cracks once at any distance (crack_within gone), body/rumble tail_db -4; blast sounds in the
  hero "explosion" voice category (cap 8) so a chained blast's crack is never dropped.
- Tools: scratchpad xfix/render.sh <tag> (render + cut + measure), xfix/measure2.py (luminance, orange bbox, camera
  shift). Do not export APPDATA for python (user site-packages live there).
- Not changed: the still stretch between chained blasts (fuse 0.35 s is a sim value); fireball cubes settle by 1 s.

## Round 9 (VFX lead FIX on r8: change of method, D-151 "Fire's tongues", 2026-10-23)
- Flames are Fire's exactly: Fire.FLAME_CUBE (0.18) at Fire.FLAME_SCALE, Fire.EMBER_SHADER at its own heat 1.4,
  Fire.FLAME_COLORS on Fire.FLAME_AT (an 8-bit ramp like Fire's), rising on spread 15, gravity +2.5, shrinking to
  0.1; a bigger blast is more flames (amount x radius/5). Spawned over 0.3 s (burst rate), life 2.0 s, damped to
  stop top_scale (3.5) site heights up. Tuning blast_fx.fireball. The real Fire left at the site stays burning
  (blast_fx.fire.seconds 0 = no timeout, like any wreck) with its light and smoke.
- Constants added to fire.gd (FLAME_CUBE, FLAME_SCALE, FLAME_AT); fire.gd is edited on other branches: merge
  one at a time and check the in-game fire is unchanged (they are the same numbers as before).
- Dust: BlastShock.ground = Fx.shockwave band at the blast's reach + Fx.dust puffs round the rim (tuning shock.ring
  puffs, puff_size). Gas: smoke.gdshader quads tinted green (cloud.shades, puff), not cubes. blast_ember.gdshader
  and blast_voxel.gdshader deleted; core and fireworks sparks use Fire.EMBER_SHADER at heat 1.0.
- Open for the VFX lead (their family call): a dense burst of Fire's flames blooms pale (cream/tan) under AgX and the
  city haze where the building fire's few flames read saturated orange. Thinning to 1100 flames helps a little;
  more flames (scale, pillar 3) whites out more. Raising Fire's own look (heat/ramp/bloom) would fix both together.
- Proof: scratchpad clip_c6 (day), clip_c7 (night), side_by_side_r9.png. capture_vfx_sheet does not exist on this
  branch (vfx-lead branch only): no fire_ground panel beside it.
- The pink triangle in front of the kaiju in every frame is BreathAim: the real game's breath aim wedge (shows where
  a ready breath will burn, drawn over the city, hidden while the breath cools down); not a debug overlay.

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
