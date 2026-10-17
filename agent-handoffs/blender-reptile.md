# blender-reptile handoff, 2026-10-17 21:55
## State: running a check (7 CI captures for the D-047 evidence; PR not yet opened)
## Task (lead 21:14, D-047 "play your croc titan clips in the game")
One PR into claude/look-options from claude/croctitan-clips: 1 bake the r7 clips (idle, walk 48-frame
cycle, turn left/right, roar) to compact data in game axes; 2 a clip player for the croc titan (walk
phase driven by distance, IK planting on top, 0.2-0.3 s blends, sim stays the authority; other species
keep procedural); 3 tests (load + validate, phase vs distance, no NaN, others procedural; floors rise).
Evidence: in-game BEFORE vs AFTER at the game camera (~20 s 720p, same seed), 2x crops of feet at
contact and jaw at roar peak, a 4K species-select still, per-frame difference plot from PNG frames with
seams and blends marked. One round of self-checking, then report; list nits, no re-render loops.
Auto-fix off. Don't merge. Skin export must stay byte-identical (voxel-skin builds on it).
## Branch and commit
claude/croctitan-clips (this worktree, switched from claude/blender-reptile-f5388e, which is pushed and
kept). Base db8962f (look-options moved to 1bcced1 since: docs only, arm-length board).
Commits: 7dca14d (player, data, tests, tools), 3706b4e (capture frames + --procedural), 22a620a
(skin.json LF). 3706b4e pushed; 22a620a local until the captures finish.
## What is built
- tools/blender/motion_test.py task `clips` -> <stem>.kclip (KCLP v1: JSON header with the 27 game bones
  in rig.json order + the skin bones each gathers + rest heads + stride + clip table; 242 B/frame int16).
  New `idle` clip (breathing only). FK self-check: worst joint error 1.72 m = the collapsed meta+toe tip
  (game leg_x2 is one straight bone); the file carries the true toe targets for the IK layer.
- assets/kaiju/reptilian_adult.kclip (135,545 B, 552 frames). Re-export reproduces it byte for byte.
- scenes/kaiju_clips.gd (KaijuClips: read, fit to rig = bone order + least-squares rest-head fit,
  pose_at with slerp, mix). scenes/gait_clip.gd (ClipGait extends BipedGait: states idle/walk/turn_*/
  roar, 0.25 s blends, walk phase = distance/stride, walk entry frame matched to the feet, planted feet
  locked + 2-bone IK, re-step when overreached, turn on the spot when standing and heading error > 0.6
  rad, jaw held for the beam, tail whip via BipedSwing.tick_whip/whip_yaw). ClipGait.or_biped picks it
  in KaijuRig._build when <base>.kclip fits; ClipGait.off = procedural (captures' --procedural).
- tests/run_clips_tests.gd (11 checks; registered in run_tests.sh, ci_shards, floors, README).
  All suites green locally: smoke 27, sim 39, powers 24, tentacles 18, city 5, growth 24, load 6,
  flow 76, clips 11.
- tools/capture/capture_clips.gd (extends capture_motion: walk, stop, standing 90 left turn, roar;
  logs CLIPSTATE/CLIPSEAM; --frames=N --from --to save PNGs; --procedural).
## Running jobs
bash ban015cq4: 7 ci_capture.sh runs -> scratch ci/{after,before}_{game,jaw,feet}, ci/select4k.
Then: scratch ev/compose_ba.py (side by side), ev/pngdiff_game.py (plot), Blender encode_intra (r6/).
## Attempts (fix-loop record)
- First drift (0.425 vs 0.229): idle feet locked, walk started at f0 -> overreach. Walk entry frame
  matched to the planted feet + re-step guard -> 0.0.
- Debug script "hang" = compile error (CATCH_SECONDS clashed with BipedGait's): renamed RESTEP_*.
- Smoke "stale skin": my working copy of croctitan.skin.json had CRLF (copied from Blender output);
  restored from the index; exporter now writes LF.
- Local GPU captures blocked by the focus guard (director in League of Legends): CI instead.
## Open decisions
None for the director. Interpretation to state in the PR: turn clips play only for a standing turn
(heading error > 0.6 rad); walking curves use the walk clip + IK planting.
## Findings for the lead (theirs to record)
- Blender's Path.write_text on Windows writes CRLF; the skin stamp hashes bytes -> false "stale".
