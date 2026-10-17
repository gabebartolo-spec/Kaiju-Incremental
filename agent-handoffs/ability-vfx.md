# Ability VFX/SFX handoff, 2026-10-18 04:40
## State: available (asked the lead "LEAD"/Game demo planning, local_106fc100..., for a job; doing prep meanwhile)

## Task
From the demo-planning session (local_106fc100..., "Game demo planning"), director 2026-10-18 03:35:
revive PR #8 (claude/ability-sfx) as demo phase P4. Croc titan (reptilian) only, baby -> Behemoth.
Priority: stomps, stomp_crack, building collapse/debris, Atomic Breath, ready, deflect, regen.
Leap and lash stay, but they are not reviewed. Stomps are pitched by size tier, not by model.
Steps:
1. Sync onto origin/claude/look-options.
2. Licence rows CLEARED and provenance complete.
3. LFS pull in tests.yml.
4. Suites green; flow base 76, raised for my checks.
5. Three 3 s clips with audio (stomp, building fall, breath) at the game camera, 1080p, plus my listening note.
6. PR body: Board and log "D-050 demo: SFX unpaused". Auto-fix on.
When CI is green, report the head SHA to the lead (local_9fac90d2...) and to Game demo planning.

## Branch and commit
claude/ability-sfx, worktree affectionate-goldstine-64c8fb. Synced to look-options dbff208, pushed;
PR #8 body updated, Auto-fix ON. Do not merge.

## Done this pass
- Merge conflicts resolved, keeping both sides: tuning.json (sfx + growth), register (heli + audio rows), floors (base).
- New sounds in build_sfx.py: footstep, stomp_crack, collapse (Kenney impactMining/impactGlass,
  explosionCrunch, lowFrequency_explosion + synthesis). Raw packs are re-extracted in
  C:/Users/DANTE/AppData/Local/Temp/claude/sfx_dl (outside the repo).
- Sfx:
  - footstep(strength)
  - stomp(power, crack): waits for the next foot plant; plays alone after stomp_wait 0.4 s
  - collapse(topple)
  - set_size_tier (size_pitch [1.3, 1.12, 1.0, 0.88])
  - last_pitch()
- Rampage wiring:
  - foot_planted -> sfx.footstep
  - stomp -> sfx.stomp(power, ability_fx.stomp_cracks(...)), which now returns bool
  - fall_land -> sfx.collapse
- Flow checks (+3):
  - _check_stomp_timing: the stomp is deferred to the next plant; baby pitch is higher than Behemoth
  - the rampage hears footstep + collapse
  - stomp_crack added to the upgraded cues
- Provenance rows for the 3 new files; register date note.
- tools/capture/capture_sfx_clips.gd: 20 s autoplayed croc run that prints "SOUND <frame> <name>".
- PR body draft: scratchpad/pr8_body.md (placeholders EVIDENCE/FLOORS/SYNC).

## Next
- When CI is green, send the head SHA to the lead (local_9fac90d2...) and Game demo planning
  (local_106fc100...).
- Clips (stomp, building_fall, breath .mp4) + run.log are in the shared notes folder
  side-session-notes/local_9fac90d2.../ability-sfx-d050/.
- The director's listen is the gate.
- Flow floor is 83.

## Unpushed (lead said no pushes yet; branch is ahead of 2195d54)
- 2dc3297: the director's dials in tuning "sfx":
  - footstep_min_interval 0.25
  - crack_min_interval 2.5
  Flow is green at 83.
- v2 clips with the dials are in shared notes ability-sfx-d050/v2-dials/. Cracks dropped from 29 to 7 in 20 s.
- roar.ogg (croc titan end-card roar, synth only, 2.2 s, timed to the biped head's roar):
  - in build_sfx.py build_roar, with a provenance row;
  - NOT wired in, because the end card is demo P5's;
  - the ogg and its spectrogram are in shared notes ability-sfx-d050/roar/.
Push only when the lead says.

## Notes
- Do NOT edit scenes/kaiju_rig.gd or scenes/kaiju_model.gd (kaiju-motion's files).
- build_sfx.py reseeds per sound; rebuilt unchanged oggs differ only by stream serial, so revert them.

## Running jobs
CI on PR #8 (Auto-fix watches it). No Godot, no override.cfg.
