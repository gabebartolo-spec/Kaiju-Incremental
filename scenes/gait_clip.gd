class_name ClipGait
extends BipedGait
## A biped that moves by its baked Blender clips (KaijuClips, D-047: the croc titan) instead of
## BipedGait's procedural motion: it idles, walks, turns on the spot and roars from the clips and
## cross-fades between them, as a clip clock (ClipClock) picks: the sim's own for a heavy body in a
## rampage (D-208: the sim's contact volume rides the same pose), else one this gait runs on what
## it sees the node do. The walk's phase follows the distance the kaiju travels (one stride
## per cycle), so planted feet do not slide; on top, planted feet are locked in the world and the
## legs re-solved (ClipFeet: curves, reversals, a turn on the spot). Presentation only: like every
## gait it reads the sim's motion and never moves the kaiju. Kaiju without clips keep BipedGait.

## The roar clip's frame with the jaw at its widest (motion_test r7), held for the beam.
const ROAR_PEAK_FRAME := 47.0
const JAW_HOLD_SECONDS := 0.15
## The roar's tail slam lands when the tip stops falling: watched from ROAR_SLAM_FRAME (motion_test:
## hit 37 + TAIL_SLAM_DELAY x the tip joint 9 = 44.2, the earliest it can land), fired on the tip's
## lowest frame, at the latest SLAM_WINDOW frames on (lead review PR #54: a fixed frame fired early
## on the adolescent). How hard it lands as a footfall: the camera drops about 9 px at 1080p (the
## scene's footfall path, presentation only, no damage); its puffs are sized by Fx.shockwave.
const ROAR_SLAM_FRAME := 44.0
const SLAM_WINDOW := 10.0
const TAIL_SLAM_STRENGTH := 1.6
## The head looks into a turn before the body makes it (director comments #16): it eases (1/s)
## toward the yaw still to turn (KaijuGait.turn_ahead), at most HEAD_LEAD_MAX (rad), the neck
## taking NECK_SHARE of it and the skull the rest, on top of the clip's pose.
const HEAD_LEAD_MAX := 0.6
const HEAD_LEAD_EASE := 10.0
const NECK_SHARE := 0.4
## Ground speed (hip heights a second) under which a body whose clip leads counts as standing.
const CLIP_STILL := 0.005

## Debug: true records the procedural gait instead (before/after captures, tools/capture).
static var off := false

var clips: KaijuClips
## The clip playing ("idle", "walk", "turn_left", "turn_right" or "roar") and its time (frames).
var state := "idle"
var clip_time := 0.0
## Walk cycles travelled so far (distance / stride), for tests and captures, and walk clip frames
## played so far.
var walk_cycles := 0.0
var walk_frames := 0.0
## The tail spring's swing from the body's turning, and as shown (ClipTail; for tests and captures).
var tail_swing := 0.0
var tail_shown := 0.0
## The clip's planted bits this frame, left then right, as the feet were given them (for tests: a
## body whose clip leads plants exactly on them, D-201).
var clip_planted: Array[bool] = [false, false]
var _from := ""
var _from_time := 0.0
var _blend := 1.0
var _clock: ClipClock  # the clip clock: the sim's (fed_heavy), else this gait's own
var _own_clock: ClipClock
var _turn_from := 0.0
var _steps: ClipSteps  # the walk clip against the sim's step clock
var _stomp := ClipStomp.new()  # catch steps, and the standing stomp
var _feet: ClipFeet  # the hind feet: planted, lifted, the leg solve
var _jaw_hold := 0.0
var _jaw_peak := Quaternion.IDENTITY
var _tail: ClipTail
## The roar's tail slam: the tip's lowest point so far, and whether it has landed.
var _slam_low := Vector3(0, INF, 0)
var _slammed := false
var _tail_tip := ""  # the last tail bone (its tail is the tip)
var _look := 0.0  # the head's look-ahead into the turn (rad)
## A heavy body's aim (tuning "body_class" aim, D-200; {} for none): the head shows the heading,
## the body follows slower.
var _aim: Dictionary = {}
## A heavy body's feet follow the clip alone (D-201): its walk clock is the sim's step clock, its
## feet plant on the clip's planted bits, never a catch step, re-plant or standing stomp lift.
var _clip_feet := false
var _hips_at := Vector3(INF, 0, 0)  # where the hips stood over the ground last frame (world)


## The gait for a biped rig: ClipGait when it has clips baked for this skeleton, else BipedGait.
static func or_biped(p_rig: KaijuRig, p_clips: Variant) -> KaijuGait:
	if p_clips is KaijuClips and not off:
		var baked: KaijuClips = p_clips
		var why := baked.fit(p_rig)
		if why.is_empty():
			return ClipGait.new(p_rig, baked)
		push_warning("ClipGait: the clips do not fit this rig (%s); walking procedurally" % why)
	return BipedGait.new(p_rig)


func _init(p_rig: KaijuRig, p_clips: KaijuClips) -> void:
	super(p_rig)
	clips = p_clips
	_own_clock = ClipClock.new(_meta(clips))
	_clock = _own_clock
	_steps = ClipSteps.new(clips)
	_jaw_peak = clips.pose_at("roar", ROAR_PEAK_FRAME).turns[clips.bones.find("jaw")]
	var tail_bones := 0
	for bone_name: String in clips.bones:
		if bone_name.begins_with("tail"):
			tail_bones += 1
			_tail_tip = bone_name
	var weight := BodyClass.of_kind(p_rig.kind)
	_aim = weight.get("aim", {})
	var feet: Dictionary = weight.get("feet", {})
	_clip_feet = feet.get("clip_plants_only", false) == true
	var tail_tune: Dictionary = weight.get("tail", {})
	_tail = ClipTail.new(tail_bones, tail_tune)
	_feet = ClipFeet.new(self, [_stomp, _steps, _clip_feet])
	swing.trail = ClawTrail.new(rig)


func update(delta: float) -> void:
	track(delta)
	if _clip_feet:
		_hip_travel()
	if _fed():  # the sim's own body yaw (D-208): the body volume and the tail ride it
		body_yaw = fed_yaw
		_body_yaw_v = 0.0
		rig.rotation.y = wrapf(body_yaw - model_yaw, -PI, PI)
	var dt := minf(delta, 1.0 / 20.0)
	var roar_was := clip_time if state == "roar" else -1.0
	_choose(dt)
	_hold_neck()
	_turn_about_hips()
	_swing_tail(dt)
	var pose := clips.pose_at(state, clip_time)
	if _blend < 1.0 and not _from.is_empty():
		pose = KaijuClips.mix(clips.pose_at(_from, _from_time), pose, smoothstep(0.0, 1.0, _blend))
	if _clip_feet:
		_walking_legs(pose)
	_apply(pose, dt)
	_look_ahead(dt)
	_slam_tail(roar_was)
	_feet.plant(pose, dt)
	_measure_slide()


## A roar starts at once, from whatever the kaiju is doing, and plays to its end (a body the sim
## feeds roars on the sim's clock, which takes the same events).
func roar() -> void:
	_own_clock.roar()


## The clips as a ClipClock reads them.
static func _meta(p_clips: KaijuClips) -> Dictionary:
	var rows := {}
	for clip: String in ["idle", "walk", "roar", "turn_left", "turn_right"]:
		if p_clips.has_clip(clip):
			rows[clip] = [p_clips.frames_of(clip), p_clips.loops(clip)]
	var spans := {}
	for turn: String in ["turn_left", "turn_right"]:
		if p_clips.has_clip(turn):
			var span := p_clips.yaw_span(turn)
			spans[turn] = [span.x, span.y]
	return {"fps": p_clips.fps, "clips": rows, "spans": spans}


## Standing, a sim stomp lifts a foot and drives it down for the ring and cracks (ClipStomp);
## walking or turning, the clip footfalls deliver it; roaring, the feet stay planted.
func stomp() -> void:
	if not _clip_feet:
		_stomp.stomp(state == "idle")


## The foot the latest stomp lifted ("left" or "right"); "" when it lifted none (walking, a roar).
func stomped_side() -> String:
	return "" if _stomp.lifted < 0 else ("left" if legs[_stomp.lifted].side < 0.0 else "right")


## The sim's heavy contact when its clip clock leads this gait (D-208: the feet go where it puts
## them), else null.
func sim_feet() -> HeavyContact:
	return fed_heavy if _clock != _own_clock else null


## World length of one walk cycle.
func stride() -> float:
	return clips.stride_m * clips.rig_scale * s


func _choose(dt: float) -> void:
	var was := state
	var was_time := clip_time
	_clock = fed_heavy.clock if _fed() and fed_heavy != null else _own_clock
	if _clock == _own_clock:
		var err := wrapf(model_yaw - body_yaw, -PI, PI)
		_own_clock.step(dt, _moving(dt), err, _walk_at.bind(dt))
	state = _clock.state
	clip_time = _clock.time
	_from = _clock.from
	_from_time = _clock.from_time
	_blend = _clock.blend
	if state != was:
		if was == "walk" and state == "idle":
			_stomp.settle()  # the weight settles as he stops
		if state.begins_with("turn"):
			_turn_from = body_yaw
	if state == "walk":
		var cycles := (moved if _clip_feet else speed * dt) / maxf(stride(), 0.0001)
		walk_cycles += cycles
		if was == "walk":
			walk_frames += fposmod(clip_time - was_time, float(clips.frames_of("walk")))
	if state.begins_with("turn"):
		_steer_turn()


## The walk frame for this gait's own clip clock: the sim's step clock when it gives one (the
## footfalls land where it turns), else the distance walked on from the clip's frame; a walk that
## starts off the step clock starts at the frame nearest the feet (_walk_entry).
func _walk_at(entering: bool, dt: float) -> float:
	if step_phase != INF:
		return _steps.frame_at(step_phase)
	if entering:
		return _walk_entry()
	var cycles := (moved if _clip_feet else speed * dt) / maxf(stride(), 0.0001)
	var at := _own_clock.legs_t if _own_clock.state == "roar" else _own_clock.time
	return at + cycles * float(clips.frames_of("walk")) / clips.cycles_of("walk")


## The walk frame to start from: the one whose planted feet stand nearest where the feet are now
## (rig space), so the first stance does not overreach.
func _walk_entry() -> float:
	var best := 0.0
	var best_cost := INF
	var to_rig := rig.global_transform.affine_inverse()
	for t: int in clips.frames_of("walk"):
		var pose := clips.pose_at("walk", t)
		var cost := 0.0
		for i: int in mini(legs.size(), 2):
			if pose.planted[i]:
				var now := to_rig * rig.tail_world(legs[i].names[2])
				cost += (clips.to_rig(pose.feet[i]) - now).length()
		if cost < best_cost:
			best_cost = cost
			best = t
	return best


## The body follows the turn clip's yaw from where it faced to the new heading.
func _steer_turn() -> void:
	if _fed():  # the sim turns the body (D-208); the clip only steps the feet
		return
	var yaw := absf(clips.pose_at(state, clip_time).yaw)
	var full := absf(clips.pose_at(state, clips.frames_of(state) - 1).yaw)
	var k := clampf(yaw / maxf(full, 0.001), 0.0, 1.0)
	body_yaw = lerp_angle(_turn_from, model_yaw, k)
	_body_yaw_v = 0.0
	rig.rotation.y = wrapf(body_yaw - model_yaw, -PI, PI)


func _apply(pose: KaijuClips.Pose, dt: float) -> void:
	_jaw_hold = clampf(_jaw_hold + (dt if head.held_open else -dt) / JAW_HOLD_SECONDS, 0.0, 1.0)
	swing.tick_whip(dt)
	if _clock != _own_clock:  # the sim's maw and claw rake (D-208): its volume rides them
		_jaw_hold = fed_heavy.jaw_hold
		swing.feed_rake(fed_heavy.rake_t, fed_heavy.rake_side)
	else:
		swing.tick_rake(dt)
	var drop := Vector3.DOWN * _stomp.dip(dt) * hip_height  # a stomp landing sinks the body
	for i: int in clips.bones.size():
		var bone_name := clips.bones[i]
		var q := pose.turns[i]
		if bone_name == "jaw" and _jaw_hold > 0.0:
			q = q.slerp(_jaw_peak, smoothstep(0.0, 1.0, _jaw_hold))  # the maw held open (the beam)
		elif bone_name.begins_with("tail"):
			var i_tail := bone_name.to_int()
			var bend := swing.whip_yaw(i_tail) + _tail.bend(i_tail)
			if _fed() and i_tail < fed_tail.size():
				bend = fed_tail[i_tail]  # the sim's tail (D-208): no swing of its own
			q = Quaternion(Vector3.UP, bend) * q
		var offset := pose.offset * clips.rig_scale + drop if i == 0 else Vector3.ZERO
		rig.pose_basis(bone_name, Basis(q), offset)
	swing.youth = clampf((ADULT_SCALE - s) / (ADULT_SCALE - BABY_SCALE), 0.0, 1.0)
	swing.pose_rake(dt)  # the claw rake, over the clip's arms


## Whether the body walks: the smoothed speed over a stand; a body whose clip leads (D-201) walks
## whenever its node moves over the ground at all (a slow drift too: its feet must step it).
func _moving(dt: float) -> bool:
	if _clip_feet:
		return moved > CLIP_STILL * hip_height * s * dt
	return speed >= STAND_SPEED * hip_height * s


## True when the sim gives this heavy body its yaw and tail (KaijuModel.follow_body, D-208).
func _fed() -> bool:
	return _clip_feet and fed_yaw != INF


## A body whose clip leads walks as far as its hips go over the ground (D-201): in a turn its node
## also swings about them (BodyContact._turn_about_hips), and that swing is no ground walked (the
## node's own travel played the walk about twice as fast as the hips went: planted feet slid).
func _hip_travel() -> void:
	var hips := rig.head_of(clips.bones[0])
	hips.y = 0.0
	var at := rig.get_parent_node_3d().global_transform * hips
	at.y = 0.0
	moved = 0.0 if _hips_at.x == INF else at.distance_to(_hips_at)
	_hips_at = at


## A heavy body roaring while it walks keeps the walk on its legs, pelvis and tail (D-201): no
## clip-less re-plants under a roar that stands still.
func _walking_legs(pose: KaijuClips.Pose) -> void:
	if not _clock.legs_on:
		return
	var legs := clips.pose_at("walk", _clock.legs_t)
	for i: int in clips.bones.size():
		var n := clips.bones[i]
		if n == "spine0" or n.begins_with("leg") or n.begins_with("tail"):
			pose.turns[i] = legs.turns[i]
	pose.offset = legs.offset
	pose.feet = legs.feet
	pose.planted = legs.planted


## A heavy body eases toward the heading at its own pace (D-200): ease_per_s, at most follow_deg_s,
## faster past catch_from_deg (the head shows the rest, _look_ahead).
func _top_turn(err: float) -> float:
	if _aim.is_empty():
		return super(err)
	var past := maxf(0.0, rad_to_deg(absf(err)) - Num.f(_aim["catch_from_deg"]))
	var top := deg_to_rad(Num.f(_aim["follow_deg_s"]) + Num.f(_aim["catch_per_deg"]) * past)
	return minf(top, absf(err) * Num.f(_aim["ease_per_s"]))  # eases in, no bang-bang


## A body whose clip leads turns about its hips, as its turn clip does (D-201): the rig's lag
## behind the heading is swung about the pelvis, not the rig's middle.
func _turn_about_hips() -> void:
	if not _clip_feet:
		return
	var hips := rig.head_of(clips.bones[0])
	hips.y = 0.0
	rig.position = hips - Basis(Vector3.UP, rig.rotation.y) * hips


## A heavy body is dragged round so its neck never turns past neck_max_deg from it (D-200).
func _hold_neck() -> void:
	if _aim.is_empty() or _fed():
		return
	var most := deg_to_rad(Num.f(_aim["neck_max_deg"]))
	var err := wrapf(model_yaw - body_yaw, -PI, PI)
	if absf(err) > most:
		body_yaw = wrapf(model_yaw - signf(err) * most, -PI, PI)
		rig.rotation.y = wrapf(body_yaw - model_yaw, -PI, PI)


## Turns the neck and skull about the world's up into the turn still to make (after the clip); a
## heavy body's head shows the heading its body has not turned to yet, at once (the beam's aim).
func _look_ahead(dt: float) -> void:
	var ahead := clampf(0.0 if turn_ahead == INF else turn_ahead, -HEAD_LEAD_MAX, HEAD_LEAD_MAX)
	_look = lerpf(_look, ahead, minf(1.0, dt * HEAD_LEAD_EASE))
	var neck_share := NECK_SHARE
	if not _aim.is_empty():
		_look = wrapf(model_yaw - body_yaw, -PI, PI)
		neck_share = Num.f(_aim["neck_share"])
	for bone_name: String in ["head0", "head1"]:
		if rig.has_bone(bone_name):
			var share := neck_share if bone_name == "head0" else 1.0 - neck_share
			var b := rig.bone(bone_name).global_transform.basis.orthonormalized()
			rig.set_world_basis(bone_name, Basis(Vector3.UP, _look * share) * b)


## The roar's tail slam lands as a heavy footfall where the tip meets the street.
func _slam_tail(roar_was: float) -> void:
	if state != "roar":
		return
	if roar_was < 0.0 or clip_time < roar_was:  # a new roar
		_slam_low = Vector3(0, INF, 0)
		_slammed = false
	if _slammed or clip_time < ROAR_SLAM_FRAME:
		return
	var tip := rig.tail_world(_tail_tip)
	if tip.y < _slam_low.y and clip_time < ROAR_SLAM_FRAME + SLAM_WINDOW:
		_slam_low = tip
		return
	_slammed = true  # the tip rose: it was lowest last frame
	var at := _slam_low if _slam_low.y < INF else tip
	at.y = rig.global_position.y
	rig.foot_planted.emit("tail", TAIL_SLAM_STRENGTH, at)


## The tail lags the body's turns (ClipTail): a curve drags it wide, it whips back and settles.
func _swing_tail(dt: float) -> void:
	_tail.step(body_yaw, state == "walk", dt)
	tail_swing = _tail.swing
	tail_shown = _tail.shown
