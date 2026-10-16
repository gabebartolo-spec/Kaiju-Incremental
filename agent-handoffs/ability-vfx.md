# Ability VFX handoff, 2026-10-16 21:00
## State: working (waiting for the GPU to recapture; lead review FIX items implemented)

## Task
D-026: a distinct VFX for every unlockable power, plus the SFX sourcing proposal. The lead is
asking the director about SFX. Lead review of PR #6 was FIX: breath (camera orbit approved, beam
reaches its target, visible scorch), lash (no filled fan; tip streaks, spray, debris, scrapes),
boost the deflect/regen/ready/cracks cues, no placeholder HUD timer. Then a new board
(same labels A-J) and a clip at the gameplay camera.

## Branch and commit
claude/ability-vfx (worktree affectionate-goldstine-64c8fb), PR #6 into claude/look-options.
Pushed: 2e762fa. Local, NOT pushed: c5aa7e0 (review fixes) + this handoff.

## Done in c5aa7e0
- Breath: camera orbit 25 deg + rise (tuning fx.orbit_*); beam stops at the first standing
  chunk (AbilityFx._first_hit); flare (flare.gdshader), sparks, light on the struck face.
- Marks are Decals (scenes/fx_decals.gd; textures drawn once from FastNoiseLite): scorch wedge,
  crater, molten cracks, lash gouges. The kaiju's voxels moved to KaijuModel.BODY_LAYER (4) so
  decals (cull_mask 1) skip it. scorch.gdshader removed.
- Lash: sweep.gdshader is now two thin tip streaks; ink + water spray (FxParticles.spray with
  orbit velocity); debris kicked along the arc on timers; scrape decal. city.ring removed.
- Cues: deflect = 40 sparks + flare; regen = rim.gdshader green shimmer overlay on the body
  (AbilityFx.attach_body) + motes; ready = shockwave ring + body flash; cracks = wide molten.
- The capture uses Rampage.autoplay_signature instead of the 999 s cooldown hack. The "998 s"
  timer the lead saw came from the capture script, not the game.
- Particle recipes split out to scenes/fx_particles.gd (keeps ability_fx.gd under 400 lines).
- flow 22, smoke 11, sim 39 green locally.

## Next
1. When the GPU is free (another agent's Godot PID 161680 had it at 99%), write override.cfg
   WITH window/size/mode=0 (the project starts fullscreen, which re-centred the window on the
   director's screen last time), run capture_powers.gd, delete override.cfg.
2. Check every still with 2x crops: is the wedge's orientation right (texture top = local -Z,
   not yet verified)? Is the beam visible after the orbit? Are the decals on rubble?
3. Rebuild the board (python script in the earlier turn: crop centre 50%, labels A-J) into
   docs/captures/2026-10-16-powers/, convert the clip to mp4 (imageio-ffmpeg), push, and message
   the lead with paths.

## Attempts (beam visibility)
Edge glow (failed), x-ray through walls (covered the kaiju, reverted), flat glow floor plus a
white-hot jet ramp; now the camera orbit (lead-approved) plus a beam that ends on its target.

## Running jobs
Background GPU-wait watcher b81jjvvb4; a wakeup at 21:14 as a fallback. No Godot of mine running.
No override.cfg left.
