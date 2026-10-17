# Ability VFX/SFX handoff, 2026-10-17 14:50
## State: paused by the director ("pause vfx until the locomotion is done"); PR #8 on HOLD, do not merge

## Task
D-026 + D-030. PR #6 (ability VFX) PASSED round 2 and is merged into claude/look-options.
Now: the SFX follow-up PR, including two VFX fixes from the lead's round-2 notes:
(1) the ready flash read as damage -> an eye flare + foot ring; (2) the breath is hidden behind
the body for about 0.25 s -> a muzzle flash at the jaw on frame 1.
D-030 (director): download the free stuff (Sonniss GDC, Kenney CC0, Freesound CC0 only),
synthesize in-house when that sounds better; register + per-file provenance; raw downloads
outside the repo.

## Branch and commit
claude/ability-sfx (worktree affectionate-goldstine-64c8fb, from origin/claude/look-options
ea8eae8). Local commit 3d7f5a2 + this handoff, NOT pushed yet. No PR yet.

## Done (3d7f5a2)
- tools/sfx/build_sfx.py: builds assets/sfx/*.ogg (11 files, about 180 KB) from Kenney Impact +
  Sci-fi packs (raw in C:/Users/DANTE/AppData/Local/Temp/claude/sfx_dl, outside the repo) plus
  numpy synthesis. Seeded. Run: python tools/sfx/build_sfx.py --kenney <that dir>.
- Sounds: stomp_0..2, stomp_crack, breath, leap_whoosh, leap_land, lash, ready, deflect,
  regen_loop. Peaks -0.7 to -6 dB, no clipping (volumedetect). Not listened to by a human yet.
- scenes/sfx.gd (Sfx): pooled AudioStreamPlayers, pitch jitter from Seeds "sfx", volumes in
  tuning.json "sfx". Rampage calls it next to every AbilityFx call; Rampage.sfx is public.
- docs/LICENSING_REGISTER.md rows (Kenney CC0, our mixes, build tool); docs/provenance/sfx.md
  lists every layer per file.
- tests.yml: each Godot job runs `git lfs pull --include="assets/sfx/*"` (audio is LFS).
- Flow: +4 sound checks on top of the base (flow floor 30 after the 2026-10-17 merge).
  sounds); floor flow 22 -> 26. smoke 11, sim 39, city 5, flow 26 green locally.
- VFX: ready_pulse(feet, head) = shockwave + eye flare; rim.gdshader is regen-only now;
  breath muzzle flare.

## First task when this resumes (after kaiju-motion lands)
1. Stomps must sound low and weighty (director: "crinkly like they're walking on cellophane").
   Rework done in a4df2b5 (3 low-end tiers, >99.9% energy < 500 Hz), but the director has not
   heard it yet. Clip: scratchpad/stomps/stomps.mp4 (tools/capture/capture_stomps.gd).
2. Stomps must land on the feet (director: "the stomping noises also sound divorced from the
   actual footfalls of the kaiju"). Lead's plan: footstep sound + small dust + light shake on
   the rig's foot-plant moment; the sim stomp (damage + shockwave) keeps its own timing, and its
   heavy sound becomes the NEXT footfall's sound made bigger (no separate thud).
   - AGREED with kaiju-motion (local_fd14d508...): `KaijuModel.foot_planted(side: String,
     strength: float, at: Vector3)`, emitted once on the IK touch-down frame; `at` = world
     contact point. Ids: biped "left"/"right"; mantis "fl"/"fr"/"bl"/"br"; tentacles "t0".."t7".
     strength 0..1 = walk speed x stage (adult ~0.6-0.8, baby ~0.3; 1 = stomp slam). kaiju-motion
     adds the signal to kaiju_rig.gd + kaiju_model.gd in PR #10; DO NOT edit those two files.
     I only connect to it in Rampage (and Sfx/AbilityFx for the dust).
   - Current rig (before the IK walk): KaijuRig.animate drives leg_l0/leg_r0 by sin(_phase)
     (sign +/- per side); leg_*1 lifts by max(0, -cos * sign), so a foot plants where its lift
     returns to 0 (cos(_phase) crosses 0 per side, i.e. _phase = PI/2 + k*PI alternating
     sides). Non-rig kaiju: KaijuModel._walk_phase, a step at each |sin| minimum.
   - Sfx: footstep = a light stomp variant, quiet; heavy = tier sound (sfx.stomp_tiers) on
     the first plant after a sim stomp event; fallback: if no plant within ~0.4 s (standing
     still), play it at the sim stomp.
   - Proof: a clip where every audible thump lines up with a foot landing (frame-step it).
3. Then the director listens to the rest of PR #8 (breath, leap, lash, ready, deflect, regen).

## Notes
- build_sfx.py reseeds per sound; decoded audio is identical across rebuilds.
- Not done: creature roars (Sonniss); Freesound needs a login.

## Running jobs
None. No override.cfg left. Last action (2026-10-17): merged look-options again (register conflict kept both sides; floors now flow 30 = base 26 + my 4; smoke 15, sim 39, powers 24, tentacles 17, city 5, flow 30 green), pushed.
