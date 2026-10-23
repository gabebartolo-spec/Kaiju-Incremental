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
  joint) keeping the tip 0.35 m off the street (render_walk1 lift_tail). turn_left/right = PLACEHOLDER (idle looped
  to 144 frames + a 90 deg eased yaw, f30-108; right mirrored).
- `tools/capture/capture_rampage_kaiju.gd`: `--stage=N` (Kit.STAGE_LEVELS) for the adult body.
- vskin baked with tools/kaiju_skin/bake.py on the adult only (= bake_all.sh's step; other skins untouched).

## Rebuild order
1. `blender -b --python tools/blender/komodo_import.py -- model <bridge>/komodo assets/kaiju/reptilian_adult 320`
2. Godot `--headless --script tools/kaiju_skin/dump_rest.gd -- rest.json`
3. `blender ... komodo_import.py -- clips <bridge>/komodo assets/kaiju/reptilian_adult rest.json`
4. `python tools/kaiju_skin/bake.py rest.json assets/kaiju` (or bake_all.sh)

## Evidence
- fit(): accepted; no "ClipGait: the clips do not fit" warning in the capture log; clips suite
  `_check_who_uses_clips` passes (adult is ClipGait).
- clips suite: 7 of 7 functions, 14 checks, 1 failure: `_check_tail_owner` (turn bends 0.009 <= 0.12): the
  placeholder turn has no tail drag. Lead ruled: leave it red on this branch.
- smoke suite: 13 of 13 functions, 47 checks, 5 failures: 3 turn checks (feet do not step in the placeholder
  turn: both feet up 9 frames, planted foot yaw 23.4 deg > 12, 5.0 skates/s) and 2 "Colossus step in the data is
  half the clip's stride" (data 3.150 vs clip 2.696 world: the Komodo stride 4 m on 10 m is shorter than the
  croc's). Stale-skin check passes.
- Converter: rebuilt-head error walk 0.0003 m, idle 0.004 m, roar 0.27 m (head0 f79: Cascadeur stretches the
  neck base; the game cannot translate a bone, so the roar's head sits up to 0.27 m off).
- Clip (local GPU, NVIDIA RTX 4070 SUPER, off-screen no_focus, 1080p60, autoplayed rampage, adult stage):
  scratchpad `komodo/cap/komodo_game_walk.mp4` (6 s, 11-17 s of the run; the controls panel covers 0-10 s).

## Open / for the lead
- Step length: data step 3.15 vs the clip's 2.70 per step: feet absorb ~17% by lock/restep. A tuning call.
- Roar neck stretch (0.27 m) and placeholder turns, as above. Arm pose not yet compared with komodo_walk_v5d.mp4.
