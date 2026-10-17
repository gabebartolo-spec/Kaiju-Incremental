# Ability VFX/SFX handoff, 2026-10-18 03:50
## State: working (D-050 demo P4: SFX unpaused; PR #8 revive, do not merge)

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
claude/ability-sfx, worktree affectionate-goldstine-64c8fb. Merge of look-options dbff208, committed
locally with this handoff; NOT pushed yet.

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
1. Read the flow result (log: $TMP/../claude_sfx_tests.log). Set the flow floor to the reported count (76 + 3 if green).
2. Capture: write the no-focus override.cfg, run one Godot, then cut 3 x 3 s mp4 around the first stomp_*, collapse and breath; delete override.cfg.
   - Command: printf '[display]\nwindow/size/mode=0\nwindow/size/no_focus=true\nwindow/size/initial_position_type=0\nwindow/size/initial_position=Vector2i(-20000,-20000)\n' > override.cfg
   - GODOT is /c/Users/DANTE/Desktop/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe
3. Push, update the PR body, turn auto-fix on, report the SHA when CI is green.

## Notes
- Do NOT edit scenes/kaiju_rig.gd or scenes/kaiju_model.gd (kaiju-motion's files).
- build_sfx.py reseeds per sound; rebuilt unchanged oggs differ only by stream serial, so revert them.

## Running jobs
Flow suite (tools/run_tests.sh, background task beukis11h). No override.cfg present.
