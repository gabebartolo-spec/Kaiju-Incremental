# Ability VFX handoff, 2026-10-16 21:00 (rev 21:05)
## State: working (waiting for the GPU to recapture; lead review FIX items implemented)

## Task
D-026: a distinct VFX for every unlockable power, plus the SFX sourcing proposal. The lead is
asking the director about SFX. Lead review of PR #6 was FIX: breath (camera orbit approved, beam
reaches its target, visible scorch), lash (no filled fan; tip streaks, spray, debris, scrapes),
boost the deflect/regen/ready/cracks cues, no placeholder HUD timer. Then a new board
(same labels A-J) and a clip at the gameplay camera.

## Branch and commit
claude/ability-vfx (worktree affectionate-goldstine-64c8fb), PR #6 into claude/look-options.
Local commits not pushed yet (review fixes + merge + tuning); push after the board passes QA.

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
- flow 22, smoke 11, sim 39 gree## Next
Merged look-options (8cf4a16: no project-wide fullscreen; D-030 SFX decided). Recapture
powers4 (scratchpad) passed for leap and breath impact, but showed: body overlay far too strong
(kaiju turned solid pink/mint), lash streaks too faint, and the breath voxels washed out to peach.
Tuned in the latest commit (rim strength/power, streak width, heat 2.0 + ramp 0.15).
1. Once the GPU is free (watcher biuo13l46; other agents' Godot PIDs 21188/320188): run
   scratchpad dbg_breath.gd (kaiju at (4.5,30) facing +X) to confirm which way the scorch wedge
   points, then capture_powers.gd -> powers5, board.py (scratchpad) -> check with 2x crops.
2. Copy the board into docs/captures/2026-10-16-powers/, convert the clip to mp4, push, and
   message the lead.
3. Then the SFX follow-up PR per D-030 (Sonniss/Kenney/Freesound CC0; synthesize hums, beams,
   pings, sizzles, regen in-house; register + provenance before assets/).

ith paths.

## Attempts (beam visibility)
Edge glow (failed), x-ray through walls (covered the kaiju, reverted), flat glow floor plus a
white-hot jet ramp; now the camera orbit (lead-approved) plus a beam that ends on its target.

## Running jobs
GPU-wait watcher biuo13l46; a wakeup at 21:14 as a fallback. No Godot of mine running.
No override.cfg left.
