# Ability VFX handoff, 2026-10-16 21:00 (rev 21:05)
## State: awaiting lead (FIX list done; new board + clip sent)

## Task
D-026: a distinct VFX for every unlockable power, plus the SFX sourcing proposal. The lead is
asking the director about SFX. Lead review of PR #6 was FIX: breath (camera orbit approved, beam
reaches its target, visible scorch), lash (no filled fan; tip streaks, spray, debris, scrapes),
boost the deflect/regen/ready/cracks cues, no placeholder HUD timer. Then a new board
(same labels A-J) and a clip at the gameplay camera.

## Branch and commit
claude/ability-vfx (worktree affectionate-goldstine-64c8fb), PR #6 into claude/look-options.
Pushed through 1635ab2 (merged look-options with #7 real city; floors city 5, flow 22; all 4 suites
green). The board has NOT passed my QA yet; the PR stays on HOLD with the lead.

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
- FIX list done and pushed. Board (A-J, gameplay camera): docs/captures/2026-10-16-powers/
  powers_board.png; H/I/J from tools/capture/capture_cues.gd (clear street). Clip (powers8):
  scratchpad .../powers8/powers.mp4.
- Known: the breath at 0.25 s is still mostly behind the body when the kaiju faces away (the
  orbit is 25 deg as approved); the ready flash tints the body red for about 0.5 s.
- Findings for the lead's learnings (not mine to record): additive unshaded quads need
  fog_disabled; MODEL_MATRIX in a MultiMesh shader excludes the instance transform.
- After the lead passes this: the SFX follow-up PR per D-030 (Sonniss/Kenney/Freesound CC0;
  synthesize hums, beams, pings, sizzles, regen in-house; register + provenance first).

## Attempts (beam visibility)
Edge glow (failed), x-ray through walls (covered the kaiju, reverted), flat glow floor plus a
white-hot jet ramp; now the camera orbit (lead-approved) plus a beam that ends on its target.

## Running jobs
None. No Godot of mine running.
No override.cfg left.
