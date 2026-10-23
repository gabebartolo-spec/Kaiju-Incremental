# Handoff: komodo-test (lead's builder, 2026-10-24)

Task: the Komodo (D-196, D-197 heavy) with its Cascadeur clips as the reptilian ADULT, a TEST build so the
director can judge the Cascadeur walk at the game camera (D-193). Test only: Cascadeur Pro trial, D-194, nothing
ships. Branch `claude/komodo-test` (from origin/claude/look-options cc77576c). NO PR, no merge (lead's brief).
Worktree: `.claude/worktrees/agent-a59788940defe4976` (copied native/bin dll and an off-screen override.cfg, both
gitignored).

## State: done, pushed; awaiting the lead's review of the clip

## What is on the branch
- `tools/blender/komodo_import.py`: `model` task voxelizes `komodo/mesh/komodo_10m.glb` with rig_voxel.py's
  functions (texture colours, height 320 = the croc adult's block size) on the skeleton of `komodo/rig/komodo.blend`
  (= build_komodo.py J, FBX rest identical); writes `assets/kaiju/reptilian_adult.kvox/.rig.json` and the Blender
  skin `assets/kaiju/test/komodo.skin.json/.skinw/.skinf` (skin_weights.json points the adult at it). Voxel bone =
  strongest skin weight; toes count for leg_x2 (the foot ends at the ball). No clean_blemishes (croc fix; it
  recoloured 22k Komodo voxels).
- `clips` task: `reptilian_adult.kclip` from `komodo_walk_v5c_joints.fbx` + `komodo_walk_v5d_arms.json`,
  `komodo_idle_v1_joints.fbx`, `komodo_roar_v1_joints.fbx` (30 -> 24 fps: walk 51 frames, idle 72, roar 108).
  Root motion removed (walk 4.000 m / cycle, 1 cycle). Planted = ball still (< 2.5 cm/frame) and low. Arm turns
  divided by the game's lowered-arm rest (from dump_rest.gd's rest.json) so arms show the Cascadeur pose.
  Jaw: shut in idle/walk; roar opens 34 deg, peak game f47, shut by f95. Tail: rest + a small curl (0.5-2 deg a
  joint) keeping the tip 0.35 m off the street (render_walk1 lift_tail). turn_left = Cascadeur
  `komodo_turn_left_v1_joints.fbx` (180 -> 144 frames), stored against its turning root (motion_test path("turn")
  shape: yaw 0 -> 90 deg left over src f37-134, pivot under the pelvis; matches the FBX pelvis yaw exactly, root
  within 0.2 m); turn_right = its mirror.
- `data/tuning.json`: Colossus (contact.bodies.reptilian[2]) step_len 2.33 -> 1.99 = half the Komodo clip's stride
  (lead, D-193 test). TEST BRANCH ONLY.
- `tools/capture/capture_rampage_kaiju.gd`: `--stage=N` (Kit.STAGE_LEVELS), `--no-card` (hides the controls
  card), `--cam=x,y,z` (camera rest offset; side shot used -24,8,20 vs the game's 0,16,30).
- vskin baked with tools/kaiju_skin/bake.py on the adult only (= bake_all.sh's step; other skins untouched).

## Rebuild order
1. `blender -b --python tools/blender/komodo_import.py -- model <bridge>/komodo assets/kaiju/reptilian_adult 320`
2. Godot `--headless --script tools/kaiju_skin/dump_rest.gd -- rest.json`
3. `blender ... komodo_import.py -- clips <bridge>/komodo assets/kaiju/reptilian_adult rest.json`
4. `python tools/kaiju_skin/bake.py rest.json assets/kaiju` (or bake_all.sh)

## Evidence
- fit(): accepted; no "ClipGait: the clips do not fit" warning in the capture log; clips suite
  `_check_who_uses_clips` passes (adult is ClipGait).
- clips suite (real turn): 14 checks, 1 failure `_check_tail_owner` (standing turn bends 0.017 <= 0.12: the
  tail has no drag; lead ruled leave red).
- smoke suite (step_len 1.99, real turn): 47 checks, 3 failures, all smoke_step_turn (the WALKING 90 deg turn on
  the walk clip + sim step clock, not the turn clip): both feet up 9 frames while yawing, planted foot yaw
  22.0 deg > 12, 4.9 skates/s vs the walk's 1.3. Stride checks now pass; stale-skin passes.
- Converter: rebuilt-head error walk 0.0003 m, idle 0.004 m, roar 0.27 m (head0 f79: Cascadeur stretches the
  neck base; the game cannot translate a bone, so the roar's head sits up to 0.27 m off).
- Clips (local GPU, NVIDIA RTX 4070 SUPER, off-screen no_focus, 1080p60, autoplayed rampage, adult, card
  hidden): scratchpad `komodo/cap/komodo_game_cam.mp4` (game camera, 3-9 s) and `komodo_side_cam.mp4` (low 3/4
  side, 2.5-8.5 s). Earlier: `komodo_game_walk.mp4` (placeholder turns).

## Open / for the lead
- smoke_step_turn reds: why the walk clip lifts both feet / twists a planted foot in a stepped walking turn is
  not diagnosed (catch steps from ClipStomp overreach are the first suspect).
- Roar neck stretch (0.27 m), as above. Arm pose not yet compared with komodo_walk_v5d.mp4.
