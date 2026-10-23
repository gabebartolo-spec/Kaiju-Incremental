# Handoff: komodo-test (lead's builder, 2026-10-24)

Task: the Komodo (D-196, D-197 heavy) with its Cascadeur clips as the reptilian ADULT; pipeline adopted (D-199);
game-layer polish (footfall weight, tail, D-200 "Head aims, body follows"). Test only: Cascadeur Pro trial, D-194.
Branch `claude/komodo-test` (from origin/claude/look-options cc77576c). NO PR, no merge (lead's brief).
Worktree: `.claude/worktrees/agent-a59788940defe4976` (copied native/bin dll and an off-screen override.cfg, both
gitignored).

## State: polish + v6 walk / v2 roar pushed; awaiting the lead's review

## What is on the branch
- `tools/blender/komodo_import.py`: `model` voxelizes `komodo/mesh/komodo_10m.glb` with rig_voxel.py's functions
  (texture colours, height 320) on the skeleton of `komodo/rig/komodo.blend`; writes `reptilian_adult.kvox/.rig.json`
  and the skin `assets/kaiju/test/komodo.skin.json/.skinw/.skinf` (skin_weights.json points the adult at it). No
  clean_blemishes (croc fix).
- `clips`: `reptilian_adult.kclip` from walk `komodo_walk_v6_ap_joints.fbx` + `komodo_walk_v6_arms.json`, idle
  `komodo_idle_v1`, roar `komodo_roar_v2` (rebuilt-head error 0.04 m, was 0.27 with v1), turn_left
  `komodo_turn_left_v1` against its turning root (yaw 0 -> 90 deg over src f37-134), turn_right mirrored. 30 -> 24
  fps; root motion removed; planted = ball still and low; arm turns divided by the game's lowered-arm rest
  (dump_rest.gd rest.json); jaw shut except the roar (34 deg, peak f47, shut by f95); tail rest + small curl.
- `data/tuning.json`: Colossus step_len 2.33 -> 1.99 (= half the Komodo stride). New `body_class` (with _doc):
  kaiju reptilian_adult = heavy; heavy footfall, tail and aim numbers. camera_shake source `heavy_step`.
- Game layer (heavy class only; the croc stages unchanged):
  - `scenes/rampage.gd` `_on_footfall`: each plant at weight >= 0.85, a heavy_step shake, the stomp's shake held for
    the foot that delivers it, a camera drop put straight on the camera (`_heavy_dip`, back at dip_recover), dust x2
    uncapped, footstep +3 dB at pitch 0.8 (`Sfx.footstep(strength, extra_db, pitch)`).
  - `scenes/clip_tail.gd`: ClipTail numbers per class; heavy drives the tail in every clip (`always`).
  - `scenes/gait_clip.gd` + `kaiju_gait.gd` (`_top_turn`): D-200, the body eases to the sim heading (ease 5/s, at most
    50 deg/s, faster past 40 deg), dragged so the neck never passes 60 deg; head0/head1 show the rest at once.
  - `scenes/kaiju_rig.gd`: `kind` (asset base) and `body_class()`; `kaiju_model.gd` passes it on.
- `tools/capture/capture_rampage_kaiju.gd`: `--stage`, `--no-card`, `--cam=x,y,z`. `tools/capture/probe_body_weight.gd`:
  headless CSV per frame (state, heading, body yaw, plants, dip, trauma, camera y, tail tip, neck).

## Rebuild order
1. `blender -b --python tools/blender/komodo_import.py -- model <bridge>/komodo assets/kaiju/reptilian_adult 320`
2. Godot `--headless --script tools/kaiju_skin/dump_rest.gd -- rest.json`
3. `blender ... komodo_import.py -- clips <bridge>/komodo assets/kaiju/reptilian_adult rest.json`
4. `python tools/kaiju_skin/bake.py rest.json assets/kaiju` (or bake_all.sh)

## Evidence (probe, seed 0 autoplay, run 3-9 s = the game clip)
- Snap: the breath beam's sim turn (powers.beam_turn_rate, "whatever the size") swings the heading 134 deg in
  0.45 s; the lead/director kept it (D-200). Body yaw rate p50 68 -> 50 deg/s, p95 291 -> 136; largest yaw in 0.3 s
  87 -> 67 deg (the neck cap drags the body past 60 deg, max 638 deg/s for ~0.15 s); neck max 60.0 deg.
- Footfall: the heavy drop lands on the plant frame (0 ms); camera y drop per plant median ~0.12 -> ~0.5 units;
  every plant adds trauma that frame (other rises are topples/tanks).
- Tail tip off the body axis: p50 0.0 -> 2.1 m, p95 -> 4.3 m.
- clips: 14 checks, 1 failure `_check_tail_owner` (standing turn bend 0.047 < 0.12; was 0.017). Tail lag passes.
- smoke: 47 checks, 3 failures, all smoke_step_turn: both feet up 36 frames, yaw in slices 78% < 80%, 12.9
  skates/s. Planted-foot-yaw and Colossus curve now pass. D-200's eased body yaw no longer comes in the sim's slices.
- Clips (GPU NVIDIA RTX 4070 SUPER, off-screen, 1080p60, card hidden): scratchpad `komodo/cap/komodo_game_cam_v2.mp4`
  (game camera, 3-9 s) and `komodo_side_cam_v2.mp4` (low 3/4 side, 2.5-8.5 s).

## Open / for the lead
- smoke_step_turn reds parked (D-193); first suspect: ClipGait catch steps. D-200 changes what they measure.
- Footfall dust reads orange-brown (the existing street dust); heavy numbers are PLACEHOLDER for the motion critic.
