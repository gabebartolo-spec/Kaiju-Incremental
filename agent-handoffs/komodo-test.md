# Handoff: komodo-test (lead's builder, 2026-10-24)

Task: the Komodo (D-196, D-197 heavy) with its Cascadeur clips as the reptilian ADULT; pipeline adopted (D-199);
game-layer polish (footfall weight, tail, D-200 "Head aims, body follows"). Test only: Cascadeur Pro trial, D-194.
Branch `claude/komodo-test` (from origin/claude/look-options cc77576c). NO PR, no merge (lead's brief).
Worktree b12: `.claude/worktrees/agent-a7894d1b8741adcd5` (local branch claude/komodo-test-fix, pushed
HEAD:claude/komodo-test; native/bin dll and off-screen override.cfg copied, gitignored). b11's worktree was
agent-ab04f2fd116e8be63. New class_name files need a Godot import before a --script run (else the run hangs).

## Sim review fixes (2026-10-24, b12; review said CHANGES NEEDED; commits 5d65c0f9, 95061a7d, 6d0fd1fb)
1. Phase snap (b13: now ANY body rounds at stride 0, heavy included; rolling re-press still no snap; sim_heavy_clock _stopped_restart_check: old line FAIL phase 6.126 -> PASS; carve 229/252 = 90.9%, 0 pass-through).
   sim_heavy_clock `_restart_check`: FAIL 0.349/step at step 192 (walking 0.034) -> PASS 0.034.
2. Croc = base: BodySteps.stepped_pace returns Array[float] (a Vector2 rounded the cadence to 32 bits).
   tests/lib/sim_croc_base.gd (SimCrocBase, sim suite) pins the reviewer's per-step hash on cc77576c (CityGrowth
   city, river rise, 900 steps at 60 Hz): adolescent run 5 turnmove FAIL 1180008155 -> PASS 4066838200.
3. Missing track: BodyClass.of is the one answer for sim and drawn body (a "sim" class counts only when
   HeavyTrack.of loads the track; push_error otherwise). `_missing_track_check` (planted heavy adolescent):
   FAIL sim plain / drawn heavy -> PASS both plain; every heavy kind has its track. EXPORT: include_filter had
   no *.kclip/*.ktrack, so exported builds shipped NO clips (procedural croc) and no track. Added; pck_check.py
   requires every assets/kaiju *.kclip/*.ktrack byte for byte, not an LFS pointer: local debug export (no release
   dll here) old preset FAIL 4 missing -> PASS "4 clips and tracks". .rig.json ships (JSON); .skinw/.skinf unused.
4. tuning `clip_motion` (one-line notes): still_hips_per_s, jaw_hold_s, clock, sink, swing; read by ClipClock,
   HeavyContact, LegSink, FootSwing and ClipGait/SwingPath/FootHold (duplicates removed). Roar cooldown once:
   sim/roar_gate.gd (BodyContact.roars) marks dash/ultimate events "roar": true; RoarCue sounds marked ones;
   HeavyContact roars on a marked ultimate; flow_dash goes through the gate. HeavyTrack.source_stamp = SHA-256/8
   over .kclip, .kvox, .rig.json, claw_fx, swipe_windup; bake writes header "source"; of() warns if stale; smoke
   `_check_tracks_fresh` (old track FAIL, no source). Re-baked: data bytes identical, source dbf6e59300208367.

## b12 results
- Suites (--quick, local): sim 11/11 functions, 76 checks, 0 failures; smoke 14/14, 47/0; tentacles 9/9, 20/0;
  flow 7/7, 249/0. Lints (gdlint, gdformat, tuning_keys, complexity ratchet) clean.
- Carve (seed 0, 25 s, --fixed-fps 60, _b10_carve.gd): 233/254 = 91.7% within 0.5, 0 pass-through, 0 beyond 2.0
  (worst 1.03) = BAR MET.
- Tick (_b11_tick.gd, alternated; base = git archive of c68bf656 + LFS): base 31.30/30.75 ms vs new 28.95/29.10.
- Other plants failing first: stale track (old .ktrack), RoarGate gap 0 (dash spam marked 3 -> 1).
- Not exercised: running the exported exe; a stamp change from a clip edit (only the no-source case).
- Scratch (uncommitted): tools/capture/_k_main.gd + _k_lib.gd (repros), _b10_carve.gd, _b11_tick.gd,
  _b11_feet.gd; base tree C:/Users/DANTE/AppData/Local/Temp/claude/kx/base_c68.
- Packet additions (b12): RoarGate._at is new sim state on every body (per run, not saved); invariant (1) is
  pinned (SimCrocBase); (5) adds BodyClass.of as the one heavy answer and the sim's roar the view only sounds.

## State (2026-10-24, builder b11)
- D-208 METHOD (lead, D-188): the heavy volume rides the drawn clips. `tools/capture/bake_heavy_tracks.gd`
  (headless, ~2 min) poses the rig from the .kclip every frame (idle, walk, roar, turn_left/right) plus the claw rake
  and writes `assets/kaiju/<kind>.ktrack` (LFS; VERSION 3 float32, 14.7 MB). Slots = each bone's voxels cut SEG 0.6
  along the bone, and across a lying bone SEG wide x BAND 0.6 high (720 slots). RE-RUN THE BAKE after any clip change.
- b11 slot shape: HeavyTrack.SLOT = 8 values, the hull of a disc at a slot's lowest and highest point (a
  leaning, tapering column; the bake keeps the tightest of LEANS x LEANS); BodyVolume._collect_slot tests each
  chunk row against the slot's disc at the row's bottom, middle and top.
- b11 foot swing: SwingPath's rule moved into pure `sim/foot_swing.gd` (FootSwing; SwingPath extends it, adds the
  arc). HeavyFeet carries a lifted hind foot's toe, ankle and slots by that lag (from where it stood back to the
  clip path); ClipGait (ClipFeet) draws a fed lifted foot on the sim's `toe_air`. Track header: stride, swing_frames.
  _b11_feet.gd: drawn toe = sim toe within 0.00 in rise/idle/roar/turn, worst 0.46 (7 frames, a walk plant at 21.6 s).
- Sim: `ClipClock` (sim/clip_clock.gd) is THE chooser; `HeavyContact` (class lookup now BodyClass.of, aim follow,
  hips pivot, turn pace, clock step, roar triggers, rake + jaw clocks, discs()); `HeavyPose` (samples/mixes the
  track, roar-on-the-move legs, rake, jaw, head look, TailSim bends; ends()/put_ends() move a slot's two ends);
  `HeavyFeet` (locks, toe_air, sink); `HeavyLegs` (the leg solve turns thigh/shin slots by both ends).
- CARVE history (b9-b11, bar: 0 pass-through, 0 > 2.0, >= 90% within 0.5): 80.1% at 1029ca02 -> foot swing
  84.6% -> 5x5 end-leaning columns 90.9% (b11); off chunks are mostly rise tops (domed back) and roar legs.
- Lint (D-159) done in b11 (ClipFeet, RigChains, SpringChain, BodyClass splits).
- Clips b11 (NVIDIA RTX 4070 SUPER, off-screen, 1080p60, card hidden, seed 0 stage 2): scratchpad
  `cap/komodo_game_cam_b11.mp4` (3-9 s), `cap/komodo_side_cam_b11.mp4` (--cam=-24,8,20, 2.5-8.5 s); cap_b11.sh.
- NEXT (lead decides): art/motion critic on the b11 clips; a fresh sim review of the b12 fixes.
- Probes: b11's in agent-ab04f2fd116e8be63/tools/capture/_b*.gd. ALWAYS `--fixed-fps 60`.

## D-201 (heavy only)
- Sim: turn <= 30 deg/s, accel 20, no slices, beam does not override; walk start/stop over 0.8 s; turns about the
  hips. Feet: plant only on clip bits (no restep/stomp lift). Tail sway 1.6 deg/bone, 2.13 s, lag 0.45 rad/bone.

## Sim-review packet (D-208 b10+b11: the heavy volume rides the drawn clips; heavy class only)
- New sim state: ClipClock (state, time, from, from_time, blend, legs_on, legs_t, roar queued), rake_t/side,
  jaw_hold, RoarGate._at (every body: the last roar's run clock), HeavyFeet locks (both slot ends)/toes/yaw_at/sink, FootSwing (air time,
  lift frame, lift toe, lock, lag) + walk frames played, _hips_at. All rebuilt by use_species at run start; none
  saved (the rampage has no mid-run save: a run replays from its seed).
- Transitions: rise (Emergence: emerging() steps the clock; idle while rising, walk while wading) -> run start ->
  idle/walk (hips travel > still_hips_per_s x hip height) -> roar (sim "ability" event, or an "ultimate" RoarGate
  marked: past roar_cooldown, dashes counting) -> roar end (to walk or idle) -> standing turn (heading - body_dir > 0.6 rad) ->
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

## body_class heavy numbers: data/tuning.json body_class.classes.heavy (footfall, tail, aim, sim, feet;
PLACEHOLDER for the motion critic).

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

## Open / for the lead
- Footfall dust reads orange-brown (the existing street dust); heavy numbers are PLACEHOLDER for the motion critic.

