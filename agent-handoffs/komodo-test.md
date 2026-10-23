# Handoff: komodo-test (lead's builder, 2026-10-24)

Task: the Komodo (D-196, D-197 heavy) with its Cascadeur clips as the reptilian ADULT; pipeline adopted (D-199);
game-layer polish (footfall weight, tail, D-200 "Head aims, body follows"). Test only: Cascadeur Pro trial, D-194.
Branch `claude/komodo-test` (from origin/claude/look-options cc77576c). NO PR, no merge (lead's brief).
Worktree: `.claude/worktrees/agent-a59788940defe4976` (copied native/bin dll and an off-screen override.cfg, both
gitignored).

## State (2026-10-24, builder b9, worktree agent-a9f99002139a20120, local branch komodo-test-b9 -> origin claude/komodo-test)
- DONE bd842360: drift 2.94 -> 0.000 over 0-12 s (probe seed 0). Causes: BodyContact.step turned a heavy heading a 2nd
  time without the hip swing; ClipGait walked by the node's travel (includes the hip swing) -> now `_hip_travel`;
  the wade crabbed 90 deg (lead's call D: heavy rises facing the wade target, emergence.start; use_species first).
- DONE: smoke_step_turn rewritten for heavy (4-5 s, <=45 deg/0.3 s, clip_planted, L/R, drift < 0.1, neck, aim). Smoke:
  only "_check_feet_of reptilian planted feet hold 3.697 > 0.101" fails (drives the adult model with a crab/reversal
  path the D-201 sim never makes: lead's call pending).
- Turn numbers (D-208): 90 deg in 4.13 s, heading mean 21.5 max 30 deg/s, body max 30; 7 footfalls L/R alternating;
  body yaws 232 frames, 41-42 with both hind feet planted; planted toes pivot up to 19 deg (swing 0.5); drift 0.
- Croc wade (no change, lead): 90 deg off facing, baby 51 / Behemoth 30 frames.
- IN PROGRESS (lead D-208): (a) the body volume sweeps during emergence (heavy); (b) sim-led tail: TailSim (port of
  ClipTail: sway, drag, spring) + the sim's body yaw (D-200 aim follow) + tail discs refit to the Komodo riding the
  chain; presentation reads the sim's body yaw and tail bends. Bar: 0 pass-through frames for every part over the
  25 s carve probe, no chunk broken > 0.5 units outside the drawn mesh. Write a sim-review packet here when done.
- Carve audit before (b): tail tip in standing chunks 59 frames (55 in turns), side 0.7-3.3 units off axis; rise
  (D) head/body/arm/leg inside a bankside building 0.3-3.0 s. Scratch probes (uncommitted): tools/capture/_b9_*.gd.

## D-201 (heavy only)
- SIM `sim/body_contact.gd`: body_class sim block by species_stage: turn <= 30 deg/s, accel 20 deg/s^2, smooth (no
  step slices), the beam's turn speed no longer overrides it; walk start over start_s 0.8, stop over stop_s 0.8
  (`rampage_sim.gd` rolls on while stride > 0). FEET `gait_clip.gd`: walk clock by distance, no restep, no standing
  stomp lift, no step shortening; a roar on the move keeps the walk on legs/pelvis/tail (`_walking_legs`). TAIL:
  sway 1.6 deg per bone, 2.13 s, lag 0.45 rad/bone, always. DIP: down over 0.03 s, back over 0.3 s, per plant.
- Probe (run 3-9 s): max body yaw in 0.3 s 15 deg (bar 45; was 67); plants L 4.42 5.97 7.50, R 3.58 5.17 6.77 8.13
  (alternating, 0.63-0.8 s apart, no same-frame pair); camera bottom 1-2 frames after a plant; tail tip half-range
  3.9 m (~11 deg).

## Sim-review packet (D-208, shared sim change; heavy class only, the croc and other species unchanged)
- What changed: `sim/tail_sim.gd` (new): ClipTail's spring/drag/sway moved into the sim, stepped from the drawn
  body's yaw; lays the tail chain (tuning heavy tail root + chain, fitted by tools/capture/fit_tail_chain.gd) and
  returns discs along it. `BodyContact`: `body_dir` (D-200 aim follow, neck cap) and `tail` for heavy; the volume's
  pose is the hips-pivoted body (`_centre`); `_sweep` carries tail discs from/to; `emerging(dt)` sweeps while a
  heavy body rises and wades (RampageSim.step calls it); `face_now`; heavy `sim.discs` replace the stage's discs.
  `BodyVolume.collect(..., free)` and `sweep(..., tail_from, tail_to)` (lerped per sample); `last_hits` for probes.
  Presentation: `KaijuModel.follow_body(sim.body)` -> gait `fed_yaw`/`fed_tail`; ClipGait shows them (no own neck
  drag, no turn-clip body steer, no own tail swing) when fed.
- Invariants: non-heavy bodies take identical paths (`_follow` sets body_dir = heading, `_centre` = kaiju_pos, no tail
  discs, `emerging` returns at once). The tail never holds the body (inside() ignores it); it only sweeps. Pure: no
  randomness, the sway clock is the tail's own accumulated dt. Tail discs are recomputed each step from state.
- Seeds: carve probe autoplay seed 0 (Kit.autoplay, stage 2), 25 s; smoke_step_turn seed army 0.

## body_class heavy numbers (data/tuning.json, PLACEHOLDER for the critic)
- footfall: strength_min 0.85, dust_gain 2.0, dip 0.35 (x body scale x weight), dip_recover 6.0, shake_source
  heavy_step (camera_shake 0.18), stomp_on_plant true, thud_db 3.0, thud_pitch 0.8.
- tail: spring_hz 9.0, spring_zeta 0.7, gain [2.0, 2.0], max 0.012, drag 0.008, drag_max 0.015, drag_smooth 0.25,
  delay 0.05, always true.
- aim (D-200): follow_deg_s 50, ease_per_s 5.0, catch_from_deg 40, catch_per_deg 8.0, neck_max_deg 60, neck_share 0.4.

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
- Clips (GPU NVIDIA RTX 4070 SUPER, off-screen, 1080p60, card hidden): scratchpad `komodo/cap/komodo_game_cam_v3.mp4`
  (game camera, 3-9 s) and `komodo_side_cam_v3.mp4` (low 3/4 side, 2.5-8.5 s); v2 = before D-201.

## Next steps (lead's order)
1. Finish the drift (item 4 above) to < 0.1 units in stance; re-probe (`tools/capture/probe_body_weight.gd`, scratchpad
   `komodo/an2.py <csv> 3 9` for the D-201 bars).
2. Rewrite tests/lib/smoke_step_turn.gd for heavy (D-201): a 90 deg turn ~4-5 s with <= 45 deg in any 0.3 s; plants
   only on clip bits, L/R alternating, never same-frame; planted drift < 0.1; neck <= cap, head on the sim aim.
3. Run clips + smoke, recapture both clips (game cam 3-9 s, side --cam=-24,8,20 2.5-8.5 s), push, report 6 lines.

## Open / for the lead
- smoke_step_turn reds parked (D-193); first suspect: ClipGait catch steps. D-200 changes what they measure.
- Footfall dust reads orange-brown (the existing street dust); heavy numbers are PLACEHOLDER for the motion critic.
