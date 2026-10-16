# Ability VFX handoff, 2026-10-16 20:45
## State: awaiting lead (PR #6 open into claude/look-options, CI pending, Auto-fix on)

## Task
D-026: distinct VFX for every unlockable power + an SFX sourcing proposal (one director
decision, asked through the lead). Started by lead session local_9fac90d2.

## Branch and commit
claude/ability-vfx (worktree affectionate-goldstine-64c8fb), head 41f6bdf (merged latest
look-options: street-life + city-layout). PR https://github.com/gabebartolo-spec/Kaiju-Incremental/pull/6

## Done
- scenes/ability_fx.gd (AbilityFx): breath beam + scorch wedge, leap trail/crater/dust,
  tentacle sweep + spray, heavy-stomp cracks, ready halo, armour deflect, regen motes.
- Shaders: beam, scorch (disc/wedge + cracks), sweep. fx.gd: breath jet ramp, tinted shockwave.
- Tunables: data/tuning.json "fx". Flow floor 14 -> 22; flow/smoke/sim green locally.
- tools/capture/capture_powers.gd (stills + --write-movie). Board in
  docs/captures/2026-10-16-powers/. Clip in scratchpad powers3/powers.mp4 (not in repo).

## Unfinished changes
None uncommitted.

## Attempts (breath beam visibility from the behind-kaiju camera)
1. Edge-glow (fresnel) core: invisible when viewed down the beam axis.
2. depth_test_disabled + depth-texture x-ray: covered the kaiju (breaks D-025); reverted.
3. Now: beam depth-tested with a flat glow floor; the white-hot jet carries the read.
Next idea (lead/director call): slight camera orbit while breathing.

## Open decisions
- Lead art-qa of the board/clip; whether subtle upgrade cues need boosting.
- SFX source (packet: side-session-notes/local_9fac90d2.../ability-vfx-sfx.md). Recommend
  Sonniss GDC + Freesound CC0 + Kenney; nothing downloaded or spent; register has no audio.
- My message to the lead was not delivered (session busy); resend if no reply.

## Running jobs
None. No override.cfg left. C: had 2.9 GB free.
