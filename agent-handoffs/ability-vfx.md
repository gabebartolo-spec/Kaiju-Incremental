# Ability VFX handoff, 2026-10-16 20:35
## State: awaiting lead (VFX PR open into claude/look-options; SFX decision packet ready)

## Task
D-026: distinct VFX for every unlockable power + an SFX sourcing proposal (one director
decision, asked through the lead). Started by the lead session local_9fac90d2.

## Branch
claude/ability-vfx (worktree affectionate-goldstine-64c8fb), PR into claude/look-options.

## Done
- scenes/ability_fx.gd (AbilityFx): breath beam + scorch wedge, leap trail/crater/dust,
  tentacle sweep + spray, heavy-stomp cracks, ready halo, armour deflect, regen motes.
- Shaders: beam.gdshader, scorch.gdshader (disc/wedge + cracks), sweep.gdshader.
- fx.gd: breath jet ramps white-hot -> species colour, heat 3; shockwave takes a tint.
- rampage.gd wires it; tunables in data/tuning.json "fx".
- Flow suite: 8 new checks (each signature's own effect, 4 upgrade cues, plain kaiju does
  not crack); floor flow 9 -> 17. flow/smoke/sim green locally.
- tools/capture/capture_powers.gd: stills + --write-movie clip.
- Board: docs/captures/2026-10-16-powers/powers_board.png. Clip (not in repo):
  scratchpad .../powers3/powers.mp4.

## Known weak spots (told the lead)
- Breath beam barely reads from the behind-kaiju camera (runs away from camera, hidden by
  body/buildings). Two fixes failed (edge glow; x-ray through walls broke D-025). The jet's
  white-hot ramp now carries the read. A better answer may be camera-side (slight orbit on
  breath) - lead/director call.
- Scorch hides under the building being breathed on; cues for cracks/ready/deflect/regen subtle.

## SFX
Packet in side-session-notes/local_9fac90d2.../ability-vfx-sfx.md. Nothing downloaded or spent.
Register has no audio CLEARED. Recommendation: Sonniss GDC bundle + Freesound CC0 + Kenney.

## Machine
C: drive had 2.9 GB free (tell the director before any big download). No override.cfg left.
