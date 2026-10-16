# Ability VFX/SFX handoff, 2026-10-16 21:35
## State: working (SFX PR built and committed; waiting for the GPU to capture the clip with audio)

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
1. Capture (background bcbmfsgnl, output scratchpad/sfx1): check ready (cue_ready) and the
   breath muzzle flash; convert powers.avi to mp4 WITH audio (aac) and a waveform image.
2. Merge origin/claude/look-options (49072a7), push, open the PR into claude/look-options
   (kaiju-pr template), message the lead with the clip; ask the lead to listen (I cannot hear).
3. Not done: Sonniss and Freesound were not needed yet (Freesound needs an account login, which
   I cannot create). Creature roars are the likely next need (Sonniss creature sounds).

## Running jobs
bcbmfsgnl: waits for the GPU, then runs capture_powers.gd + capture_cues.gd with override.cfg
(it deletes override.cfg itself).
