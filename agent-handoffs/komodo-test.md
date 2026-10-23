# Handoff: komodo-test (lead's builder, 2026-10-24)

Task: the Komodo (D-196, D-197 heavy) with its Cascadeur clips as the reptilian ADULT; pipeline adopted (D-199);
game-layer polish (footfall weight, tail, D-200 "Head aims, body follows"). Test only: Cascadeur Pro trial, D-194.
Branch `claude/komodo-test` (from origin/claude/look-options cc77576c). NO PR, no merge (lead's brief).
Worktree: `.claude/worktrees/agent-a59788940defe4976` (copied native/bin dll and an off-screen override.cfg, both
gitignored).

## State (2026-10-24, builder b10, worktree agent-a9b72dd9dd8061ff9, local branch komodo-test-b10 -> origin claude/komodo-test)
- D-208 METHOD CHANGE (lead, D-188): the hand-fitted discs are gone. The heavy volume rides the drawn clips:
  `tools/capture/bake_heavy_tracks.gd` (headless, ~30 s) poses the rig from the .kclip every frame (idle, walk,
  roar, turn_left/right) plus the claw rake (BipedSwing, fed rake time) and writes `assets/kaiju/<kind>.ktrack`
  (binary: per frame each slot's upright disc in body space, bone heads, hind toes, root quaternion, planted bits).
  Slots = each bone's voxels cut SEG along the bone, and across a lying bone SEG wide x BAND high (now 0.6: 720
  slots, 4.6 MB; 1.0 gave 321 slots and 56% within). RE-RUN THE BAKE after any clip/model change (Cascadeur).
- Sim: `ClipClock` (sim/clip_clock.gd) is THE chooser (idle/walk/roar/turn + 0.25 s fade + roar walking legs); the
  heavy sim's own clock picks the clip, ClipGait reads it when fed (fed_heavy), else runs its own ClipClock (croc,
  reveal screens): no second chooser. `HeavyContact` (sim/heavy_contact.gd): class lookup, aim follow, hips pivot,
  turn pace, clock step (moving = hips travel), roar triggers from sim events (ability; ultimate with RoarCue's
  cooldown), rake + jaw clocks, discs(). `HeavyPose`: samples/mixes the track, roar-on-the-move legs (upper body
  hung on the walk pelvis by the root quaternion), rake (blends the clip arm by the rake's rest weight), jaw open,
  head look, TailSim bends. `HeavyFeet`: planted toe + foot slots locked where they came down (ClipGait._put_down
  plants the drawn foot on `toe_lock`), and the IK sink (`LegSink`, shared with LegReach; drawn sink = sim's).
- Presentation reads the sim: clip state/time/fade, rake time (BipedSwing.feed_rake), jaw hold, sink, toe locks.
- Lint: body_contact 561 -> 385 (heavy -> heavy_contact.gd; stepped turn -> sim/body_steps.gd; over() -> volume);
  BodyVolume.sweep(Move, from, to), collect(pose, into, near, free), _collect_disc 3 args. rampage_sim.step and
  rampage._ready trimmed under the ratchet. STILL RED (pre-existing on this branch, not in brief): gait_clip.gd
  485 lines > 400, kaiju_rig.gd > 20 public methods.
- smoke `_check_feet_of`: the heavy adult is driven by the real sim (forward, 90 deg left on the move, back, stop),
  fed as Rampage does; the insectoid keeps its old route. Bar 0.02 x hip unchanged.
- New sim check `tests/lib/sim_heavy_clock.gd` (in run_sim_tests): same seed replays clock + volume step for step.
- Removed: tools/capture/fit_body_contact.gd, fit_tail_chain.gd; tuning heavy sim discs/neck/skull/feet/walk and
  tail root/chain (TailSim keeps only the swing).
- CARVE (seed 0, 25 s, --fixed-fps 60, _b9_carve.gd): 0 pass-through frames every part; 0 > 2.0 (bar met);
  within 0.5: 80.5% (256 broken, 50 off) at 0.6 slots; 80.1% (51 off) with the leg solve (HeavyLegs) added, so
  the leg solve did not move it. Top bins: rise leg_r2/walk 9, rise spine2/head0/arm_r0 idle ~17 (flat disc tops
  over the domed back breaking up through the street), run leg_r2/roar 6, legs roar ~6.
- NEXT (successor, lead 2026-10-24): (1) foot bins: run _b10_slots.gd --fixed-fps 60 on leg_r2 (locked foot slots
  vs the drawn IK foot; suspects: the presentation's lifted-foot path lag at touchdown, the held foot yaw, the
  foot slot's wide circle); (2) rise tops: sloped disc tops (top at the centre and at the rim, BodyVolume per
  column) or finer top bands; (3) gait_clip.gd (485 lines) and kaiju_rig.gd (> 20 public methods) splits,
  owed per D-159; (4) show sim_heavy_clock failing on a planted difference; (5) the .ktrack is in Git LFS
  (4.6 MB); finer slots grow it.
- Probes (scratch, uncommitted, copy from this worktree): tools/capture/_b9_carve.gd (bar), _b10_pose.gd (sim heads
  vs drawn), _b10_slots.gd (every sim slot vs the same slot cut live from the rig), _b10_carve.gd (off chunks with
  detail). Use `--fixed-fps 60`: without it headless runs ~8 physics steps per drawn frame (stale rig).

## D-201 (heavy only)
- Sim: turn <= 30 deg/s, accel 20, no slices, beam does not override; walk start/stop over 0.8 s; turns about the
  hips. Feet: plant only on clip bits (no restep/stomp lift). Tail sway 1.6 deg/bone, 2.13 s, lag 0.45 rad/bone.

## Sim-review packet (D-208 b10: the heavy volume rides the drawn clips; heavy class only)
- New sim state: ClipClock (state, time, from, from_time, blend, legs_on, legs_t, roar queued), rake_t/side,
  jaw_hold, _roar_at (ultimate cooldown), HeavyFeet locks/toes/yaw_at/sink, _hips_at. All rebuilt by
  use_species at run start; none saved (the rampage has no mid-run save: a run replays from its seed).
- Transitions: rise (Emergence: emerging() steps the clock; idle while rising, walk while wading) -> run start ->
  idle/walk (hips travel > CLIP_STILL x hip height) -> roar (sim "ability" event, or "ultimate" past RoarCue's
  roar_cooldown counting dashes) -> roar end (to walk or idle) -> standing turn (heading - body_dir > 0.6 rad) ->
  settle; any -> blend 0.25 s; swipe_windup/swipe -> rake; beam on/off -> jaw; plant/lift -> lock/unlock; airborne
  (leap): clock still steps, no sweep; dash: no hips pivot. Events are read after the step (after_events) and act
  on the next step, as the presentation's roar()/strike() did; the presentation now shows the sim's state.
- Invariants: (1) the croc and every non-heavy body: same paths as before (heavy_contact null; BodySteps is a
  move, not a change: tests sim + motion + smoke cover it). (2) The tail never holds the body (inside() drops tail
  slots). (3) Pure: no randomness, no clock, no Node in sim/ (HeavyTrack reads bytes with FileAccess, cached).
  (4) Same seed -> same clip, frame and volume every step (sim_heavy_clock, run_sim_tests). (5) Drawn = sim:
  ClipGait/LegReach/BipedSwing read clock, sink, rake, jaw and toe locks from fed_heavy; one chooser (ClipClock),
  ClipGait's own instance only when no sim feeds it.
- Evidence: carve probe above; _b10_slots per-slot sim-vs-drawn; sim_heavy_clock; smoke/clips/sim suite lines.
- Not exercised: the IK knee (thigh/shin slots follow the clip, not the solve); slot tops are flat; heavy at
  baby/adolescent (no track: falls back to the stage's discs); evolution reveal / demo-end (own clock, no sim).
- Seeds: carve probe autoplay seed 0 (Kit.autoplay, stage 2), 25 s, --fixed-fps 60; sim checks army seed 0.
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
- Footfall: the heavy drop lands on the plant frame (0 ms); camera y drop per plant median ~0.12 -> ~0.5 units;
  every plant adds trauma that frame (other rises are topples/tanks).
- Clips b10 (GPU NVIDIA RTX 4070 SUPER, off-screen, 1080p60, card hidden, seed 0 stage 2): b10 scratchpad
  `cap/komodo_game_cam_b10.mp4` (game camera 3-9 s), `cap/komodo_side_cam_b10.mp4` (--cam=-24,8,20, 2.5-8.5 s);
  recorder script `cap.sh` there. Older v3 clips: the b9 scratchpad `komodo/cap/`.
- Suites b10 (local, --quick): sim 70 checks 0 failures; smoke 46 checks, 1 failure = the uncommitted scratch probe
  _b9_probe.gd not compiling (fixed since), planted feet and smoke_step_turn pass; clips 14 checks, 1 failure
  `_check_tail_owner` (pre-existing: turn bend 0.061 vs 0.12).

## Open / for the lead
- Footfall dust reads orange-brown (the existing street dust); heavy numbers are PLACEHOLDER for the motion critic.
