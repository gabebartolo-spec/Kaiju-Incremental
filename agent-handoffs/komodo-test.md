# Handoff: komodo-test (lead's builder, 2026-10-24)

Task: the Komodo (D-196, D-197 heavy) with its Cascadeur clips as the reptilian ADULT; pipeline adopted (D-199);
game-layer polish (footfall weight, tail, D-200 "Head aims, body follows"). Test only: Cascadeur Pro trial, D-194.
Branch `claude/komodo-test` (from origin/claude/look-options cc77576c). NO PR, no merge (lead's brief).
Worktree b11: `.claude/worktrees/agent-ab04f2fd116e8be63` (local branch komodo-test-work -> origin claude/komodo-test;
copied native/bin dll and an off-screen override.cfg, both gitignored). New class_name files need a Godot import
before a --script run (else "Could not find type" and the run hangs to its timeout).

## State (2026-10-24, builder b11)
- D-208 METHOD (lead, D-188): the heavy volume rides the drawn clips. `tools/capture/bake_heavy_tracks.gd`
  (headless, ~1 min) poses the rig from the .kclip every frame (idle, walk, roar, turn_left/right) plus the claw rake
  and writes `assets/kaiju/<kind>.ktrack` (LFS; VERSION 2, 7.3 MB). Slots = each bone's voxels cut SEG 0.6 along the
  bone, and across a lying bone SEG wide x BAND 0.6 high (720 slots). RE-RUN THE BAKE after any clip/model change.
- b11 slot shape: each slot is HeavyTrack.SLOT = 8 values, the hull of a disc at its lowest and one at its highest
  (a leaning, tapering column); the bake keeps the tightest column over LEANS x LEANS (each end of the axis leaning
  0..1 from the slot's middle toward the middle of its lowest/highest third; radii fitted from either end, the
  smaller kept). BodyVolume._collect_slot tests each chunk row against the slot's disc at the row's bottom, middle
  and top (column reject past the widest reach; rows laid out only once a building is in reach).
  Cost (_b11_cost.gd, seed 0, 25 s): per pose 2.2 ms as upright discs vs 3.6 ms as columns (1.6x, each sweep sample).
- b11 foot swing: SwingPath's rule moved into pure `sim/foot_swing.gd` (FootSwing; SwingPath extends it, adds the
  arc). HeavyFeet carries a lifted hind foot's toe, ankle and slots by that lag (from where it stood back to the
  clip path); ClipGait (ClipFeet) draws a fed lifted foot on the sim's `toe_air`. Track header: stride, swing_frames.
  _b11_feet.gd: drawn toe = sim toe within 0.00 in rise/idle/roar/turn, worst 0.46 (7 frames, a walk plant at 21.6 s).
- Sim: `ClipClock` (sim/clip_clock.gd) is THE chooser; `HeavyContact` (class lookup now BodyClass.of, aim follow,
  hips pivot, turn pace, clock step, roar triggers, rake + jaw clocks, discs()); `HeavyPose` (samples/mixes the
  track, roar-on-the-move legs, rake, jaw, head look, TailSim bends; ends()/put_ends() move a slot's two ends);
  `HeavyFeet` (locks, toe_air, sink); `HeavyLegs` (the leg solve turns thigh/shin slots by both ends).
- CARVE (seed 0, 25 s, --fixed-fps 60, _b10_carve.gd; bar: 0 pass-through, 0 > 2.0, >= 90% within 0.5):
  baseline 1029ca02: 205/256 = 80.1% (51 off: rise back/head/shoulder tops 22, rise wading right hind foot 13,
  roar-on-the-move legs 16). + foot swing: 219/259 = 84.6% (40 off). + leaning slots (thirds, no choice):
  184/240 = 76.7% (56 off: worse; tilted thin slabs overreach at their low/high edge). + tightest of 5 joint leans:
  229/255 = 89.8%. + 5x5 end leans, two-way radii: 229/252 = 90.9% (23 off: rise tops 14, roar legs 7, tail 1,
  wading 2; worst 1.03) = BAR MET. Pass-through 0 and > 2.0 = 0 in every run.
- Lint (D-159) done: gait_clip.gd 485 -> 383 (feet -> scenes/clip_feet.gd ClipFeet, sim_feet()); kaiju_rig.gd
  24 -> 20 public methods (chains -> scenes/rig_chains.gd RigChains + scenes/spring_chain.gd SpringChain, callers use
  rig.springs.simulate/named/chains; weight class -> sim/body_class.gd BodyClass.of / of_kind). gdlint sim scenes
  tests clean; gdformat clean; complexity ratchet clean.
- sim_heavy_clock proven: a planted ClipClock static counter (start time += 0.5 per clock made) -> "off at step 0"
  FAIL; removed -> sim 11 of 11 functions, 70 checks, 0 failures (229 s, --quick). Plant script: scratchpad plant.py.
- Pushed 1478d516 to claude/komodo-test. Suites (--quick, local): sim 70/0; tentacles 20/0; smoke 46 checks, 1 failure
  = the uncommitted scratch probes not compiling (fixed after); clips 14 checks, 1 failure `_check_tail_owner` (off
  the clip 0.0276 rad; turn bends 0.061 < 0.12).
- Perf (lead: whole frame/tick vs the old build, > 20% worse = optimise now): bench_rampage --stage=3 (off-screen
  window) and _b11_tick.gd (headless, carve route) in this worktree and a temp base worktree `../b11-base` at
  1029ca02 (remove it when done: `git worktree remove ../b11-base`). Scripts: scratchpad perf_round.sh, tick.sh,
  bench.sh. Pushed build: tick mean base 28.9/32.2 vs new 39.1/35.2 ms; bench_rampage frames in 30 s base 103/102
  vs new 68/85/73 = REGRESSION. opt1 (Slot scratch, per-building reject, column helper, squared tests): contact on
  parity (_b11_split: slots 9.49 vs as discs 9.68 ms/step) but tick still base 29.8/30.5 vs new 35.6/40.0, bench 82.
  opt2 (prepared, scratchpad opt2.py): track stored as float32 (VERSION 3) so HeavyPose._sample indexes, no decode.
- NEXT: perf result; recapture both clips on NVIDIA (scratchpad cap_b11.sh); sim-review packet final.
- Probes (scratch, uncommitted; copy from this worktree): tools/capture/_b9_carve.gd, _b10_carve.gd (bar + off
  chunks with detail; reads the 6-value discs), _b10_pose.gd, _b10_slots.gd (still the 5-value cylinder cut: stale),
  _b11_feet.gd (sim toe vs drawn toe), _b11_cost.gd (contact test per pose), _b11_tick.gd (whole tick).
  ALWAYS `--fixed-fps 60`.

## D-201 (heavy only)
- Sim: turn <= 30 deg/s, accel 20, no slices, beam does not override; walk start/stop over 0.8 s; turns about the
  hips. Feet: plant only on clip bits (no restep/stomp lift). Tail sway 1.6 deg/bone, 2.13 s, lag 0.45 rad/bone.

## Sim-review packet (D-208 b10+b11: the heavy volume rides the drawn clips; heavy class only)
- New sim state: ClipClock (state, time, from, from_time, blend, legs_on, legs_t, roar queued), rake_t/side,
  jaw_hold, _roar_at (ultimate cooldown), HeavyFeet locks (both slot ends)/toes/yaw_at/sink, FootSwing (air time,
  lift frame, lift toe, lock, lag) + walk frames played, _hips_at. All rebuilt by use_species at run start; none
  saved (the rampage has no mid-run save: a run replays from its seed).
- Transitions: rise (Emergence: emerging() steps the clock; idle while rising, walk while wading) -> run start ->
  idle/walk (hips travel > CLIP_STILL x hip height) -> roar (sim "ability" event, or "ultimate" past RoarCue's
  roar_cooldown counting dashes) -> roar end (to walk or idle) -> standing turn (heading - body_dir > 0.6 rad) ->
  settle; any -> blend 0.25 s; swipe_windup/swipe -> rake; beam on/off -> jaw; plant -> lock; lift -> unlock and
  swing back to the clip path (FootSwing); airborne (leap): clock still steps, no sweep; dash: no hips pivot.
  Events are read after the step (after_events) and act on the next step; the presentation shows the sim's state.
- Invariants: (1) the croc and every non-heavy body: same paths as before (heavy_contact null; SwingPath = the old
  maths through FootSwing; ClipFeet/RigChains/BodyClass are moves). (2) The tail never holds the body (inside()
  drops tail slots). (3) Pure: no randomness, no clock, no Node in sim/. (4) Same seed -> same clip, frame and volume
  every step (sim_heavy_clock). (5) Drawn = sim: ClipGait/ClipFeet/LegReach/BipedSwing read clock, sink, rake, jaw,
  toe locks and lifted toes from fed_heavy; one chooser (ClipClock).
- Shape invariant: each slot column holds every support point of its posed voxels (bake: radii from the LP fit
  over all 26; conservative to the support hull, as the b10 discs were); a chunk row is hit if any of the slot's
  discs at the row's bottom, middle or top overlaps it (BodyVolume._collect_slot/_slot_in, Slot scratch, pure).
- Evidence: carve probe above (0 pass-through every part); _b11_feet toe match; sim_heavy_clock planted fail then
  pass; suite lines above.
- Not exercised: the yaw of a lifted foot easing back (sim: none; drawn: FOOT_YAW_DECAY); heavy at
  baby/adolescent (no track: falls back to the stage's discs); evolution reveal / demo-end (own clock, no sim).
- Seeds: carve probe autoplay seed 0 (Kit.autoplay, stage 2), 25 s, --fixed-fps 60; sim checks army seed 0.

## body_class heavy numbers (data/tuning.json, PLACEHOLDER for the critic)
- footfall: strength_min 0.85, dust_gain 2.0, dip 0.35 (x body scale x weight), dip_recover 6.0, shake_source
  heavy_step (camera_shake 0.18), stomp_on_plant true, thud_db 3.0, thud_pitch 0.8.
- tail: spring_hz 9.0, spring_zeta 0.7, gain [2.0, 2.0], max 0.012, drag 0.008, drag_max 0.015, drag_smooth 0.25,
  delay 0.05, always true.
- aim (D-200): follow_deg_s 50, ease_per_s 5.0, catch_from_deg 40, catch_per_deg 8.0, neck_max_deg 60, neck_share 0.4.

## What is on the branch
- `tools/blender/komodo_import.py`: `model` voxelizes `komodo/mesh/komodo_10m.glb` (texture colours, height 320) on
  the skeleton of `komodo/rig/komodo.blend`; writes `reptilian_adult.kvox/.rig.json` and the skin
  `assets/kaiju/test/komodo.skin.json/.skinw/.skinf`. `clips`: `reptilian_adult.kclip` from walk v6, idle v1, roar v2,
  turn_left v1 (turn_right mirrored); 30 -> 24 fps; root motion removed; planted = ball still and low.
- `data/tuning.json`: Colossus step_len 1.99 (= half the Komodo stride). `body_class`: reptilian_adult = heavy.
- Game layer (heavy class only): rampage.gd `_on_footfall` (heavy shake, camera drop, dust x2, thud); clip_tail.gd
  per-class numbers; gait_clip.gd + kaiju_gait.gd `_top_turn` (D-200); kaiju_rig.gd `kind`.
- `tools/capture/capture_rampage_kaiju.gd`: `--stage`, `--no-card`, `--cam=x,y,z`; `probe_body_weight.gd` CSV.

## Rebuild order
1. `blender -b --python tools/blender/komodo_import.py -- model <bridge>/komodo assets/kaiju/reptilian_adult 320`
2. Godot `--headless --script tools/kaiju_skin/dump_rest.gd -- rest.json`
3. `blender ... komodo_import.py -- clips <bridge>/komodo assets/kaiju/reptilian_adult rest.json`
4. `python tools/kaiju_skin/bake.py rest.json assets/kaiju` (or bake_all.sh); then the heavy track bake.

## Evidence (older)
- Footfall: the heavy drop lands on the plant frame (0 ms); camera drop per plant median ~0.5 units.
- Clips b10 (NVIDIA, off-screen, 1080p60, card hidden, seed 0 stage 2): scratchpad `cap/komodo_*_cam_b10.mp4`.

## Open / for the lead
- Footfall dust reads orange-brown (the existing street dust); heavy numbers are PLACEHOLDER for the motion critic.
