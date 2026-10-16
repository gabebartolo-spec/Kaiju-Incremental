# Ability VFX/SFX handoff, 2026-10-16 21:35
## State: awaiting lead (PR #8 open; stomps reworked after the director's "cellophane" note; stomp clip sent)

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
- Flow: +4 checks (each signature sounds; the upgraded kaiju has the crack/ready/deflect/regen
  sounds); floor flow 22 -> 26. smoke 11, sim 39, city 5, flow 26 green locally.
- VFX: ready_pulse(feet, head) = shockwave + eye flare; rim.gdshader is regen-only now;
  breath muzzle flare.

## Next
- PR #8 open (claude/ability-sfx into claude/look-options), do NOT merge: the director has heard
  only the stomps so far ("crinkly like they're walking on cellophane").
- Stomps reworked: 3 tiers by stomp power (tuning sfx.stomp_tiers [1.4, 1.8]): sub thump
  68->40/63->37/58->34 Hz + impactSoft_heavy low-passed at 2.5 kHz + 150 Hz knock + rumble tail;
  debris settle quiet and late on tiers 2-3; high-passed at 28 Hz. stomp_crack is gone.
  Measured: >99.9% of the energy below 500 Hz, >2 kHz down 43-60 dB, 15-38% in 80-250 Hz (TV
  speakers). Clip: scratchpad/stomps/stomps.mp4 (tools/capture/capture_stomps.gd).
- build_sfx.py reseeds per sound; decoded audio is identical across rebuilds (the ogg bytes
  differ only by the stream serial). The other sounds are new noise draws of the same design.
- Not done: creature roars (Sonniss); Freesound needs a login.

## Running jobs
None. No override.cfg left.
