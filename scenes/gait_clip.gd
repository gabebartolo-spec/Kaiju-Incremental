class_name ClipGait
extends BipedGait
## A biped that moves by its baked Blender clips (KaijuClips, D-047: the croc titan) instead of
## BipedGait's procedural motion: it idles, walks, turns on the spot and roars from the clips and
## cross-fades between them. The walk's phase follows the distance the kaiju travels (one stride
## per cycle), so planted feet do not slide; on top, planted feet are locked in the world and the
## legs re-solved (curves, reversals, a turn on the spot). Presentation only: like every gait it
## reads the sim's motion and never moves the kaiju. Kaiju without clips keep BipedGait.

## Cross-fade between states (s).
const BLEND_SECONDS := 0.25
## Heading error (rad) that makes a standing kaiju turn on the spot with a turn clip.
const TURN_TRIGGER := 0.6
## Frames of lead-in kept before the part of a turn clip that carries its yaw, and of settle
## after it (the tail's whip settles about half a second after the body stops).
const TURN_PAD := 6
const TURN_SETTLE := 24
## How fast a lifted foot's toes swing back to the clip's yaw after the body turned over them (1/s).
const FOOT_YAW_DECAY := 12.0
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
## A planted foot that ends this far from its clip spot (strides), or past a straight leg (fraction
## of the leg's length), takes a quick catch step back to the clip (ClipStomp). At 0.98 the
## adolescent's long legs, nearly straight at heel strike, re-stepped on every plant (PR #54).
const RESTEP_GAP := 0.3
const RESTEP_REACH := 1.0
## The head looks into a turn before the body makes it (director comments #16): it eases (1/s)
## toward the yaw still to turn (KaijuGait.turn_ahead), at most HEAD_LEAD_MAX (rad), the neck
## taking NECK_SHARE of it and the skull the rest, on top of the clip's pose.
const HEAD_LEAD_MAX := 0.6
const HEAD_LEAD_EASE := 10.0
const NECK_SHARE := 0.4

## Debug: true records the procedural gait instead (before/after captures, tools/capture).
static var off := false

var clips: KaijuClips
## The clip playing ("idle", "walk", "turn_left", "turn_right", "roar" or "stomp") and its time
## (frames).
var state := "idle"
var clip_time := 0.0
## Walk cycles travelled so far (distance / stride), for tests and captures, and walk clip frames
## played so far.
var walk_cycles := 0.0
var walk_frames := 0.0
## The tail spring's swing from the body's turning, and as shown (ClipTail; for tests and captures).
var tail_swing := 0.0
var tail_shown := 0.0
var _from := ""
var _from_time := 0.0
var _blend := 1.0
var _roar_queued := false
var _turn_from := 0.0
var _turn_span := {}  # turn clip -> Vector2(first, last frame of the yaw)
var _steps: ClipSteps  # the walk clip against the sim's step clock
var _path: SwingPath  # a lifted foot's way to its clip path
var _lock: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _lag: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## The body's world yaw and each foot's flat heading (FootHold.foot_yaw) when it went down, and the
## turn (rad) its toes are held to: a planted foot keeps its world yaw while the body turns over it
## and, up to FootHold.ROLL_HOLD_MAX, while a splayed foot rolls over the stance; it swings back to
## the clip's in the air.
var _plant_yaw: Array[float] = [0.0, 0.0]
var _plant_heading: Array[float] = [0.0, 0.0]
var _yaw_fix: Array[float] = [0.0, 0.0]
var _was_planted: Array[bool] = [false, false]
var _stomp := ClipStomp.new()  # catch steps, and the standing stomp (clips without one)
var _beat: StompBeat  # the standing stomp from the clip ("stomp", the adult's Cascadeur stomp)
var _jaw_hold := 0.0
var _jaw_peak := Quaternion.IDENTITY
var _tail: ClipTail
var _hold: FootHold  # a planted foot's world yaw
var _ik: LegReach  # the leg solve, the body sunk so no knee pops
var _feet_primed := false
## The roar's tail slam: the tip's lowest point so far, and whether it has landed.
var _slam_low := Vector3(0, INF, 0)
var _slammed := false
var _tail_tip := ""  # the last tail bone (its tail is the tip)
var _look := 0.0  # the head's look-ahead into the turn (rad)


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
	for turn: String in ["turn_left", "turn_right"]:
		_turn_span[turn] = clips.yaw_span(turn)
	_steps = ClipSteps.new(clips)
	_beat = StompBeat.new(clips)
	_path = SwingPath.new(_steps.swing_frames)
	_jaw_peak = clips.pose_at("roar", ROAR_PEAK_FRAME).turns[clips.bones.find("jaw")]
	var tail_bones := 0
	for bone_name: String in clips.bones:
		if bone_name.begins_with("tail"):
			tail_bones += 1
			_tail_tip = bone_name
	_tail = ClipTail.new(tail_bones)
	_hold = FootHold.new(rig)
	_ik = LegReach.new(self)
	swing.trail = ClawTrail.new(rig)


func update(delta: float) -> void:
	track(delta)
	var dt := minf(delta, 1.0 / 20.0)
	_beat.tick(dt)
	var roar_was := clip_time if state == "roar" else -1.0
	_choose(dt)
	_swing_tail(dt)
	var pose := clips.pose_at(state, clip_time)
	if _blend < 1.0 and not _from.is_empty():
		pose = KaijuClips.mix(clips.pose_at(_from, _from_time), pose, smoothstep(0.0, 1.0, _blend))
	_apply(pose, dt)
	_look_ahead(dt)
	_slam_tail(roar_was)
	_plant_feet(pose, dt)
	_measure_slide()


## A roar starts at once, from whatever the kaiju is doing, and plays to its end.
func roar() -> void:
	_roar_queued = true


## Standing, a sim stomp lifts a foot and drives it down for the ring and cracks: the stomp clip
## when the clips key one (StompBeat; the foot the sim names), else ClipStomp's lift; walking or
## turning, the clip footfalls deliver it; roaring, the feet stay planted.
func stomp() -> void:
	if _beat.keyed() and (state == "idle" or state == "stomp"):
		var i := _stomp.by_clip()
		var side := "left" if legs[i].side < 0.0 else "right"
		var at := _beat.on_stomp(state == "stomp", clip_time, side)
		if at >= 0.0:
			_go("stomp", at)
		return
	_stomp.stomp(state == "idle")


## The foot the next standing stomp lifts (the sim chose it: its damage is centred under that foot).
func prefer_foot(side: String) -> void:
	_stomp.prefer(side)


## The foot the latest stomp lifted ("left" or "right"); "" when it lifted none (walking, a roar).
func stomped_side() -> String:
	return "" if _stomp.lifted < 0 else ("left" if legs[_stomp.lifted].side < 0.0 else "right")


## World length of one walk cycle.
func stride() -> float:
	return clips.stride_m * clips.rig_scale * s


func _choose(dt: float) -> void:
	var moving := speed >= STAND_SPEED * hip_height * s
	var done := not clips.loops(state) and clip_time >= clips.frames_of(state) - 1
	var settle := "walk" if moving else "idle"
	if _roar_queued:
		_roar_queued = false
		_go("roar", 0.0)
	elif state == "roar":
		if done:
			_go(settle, _walk_start() if moving else 0.0)
	elif state.begins_with("turn"):
		var span: Vector2 = _turn_span[state]
		if moving or clip_time >= span.y + TURN_SETTLE:
			_go(settle, _walk_start() if moving else 0.0)
	elif moving:
		if state != "walk":
			_go("walk", _walk_start())
	elif state != "stomp" or _beat.done():  # a stomp plays out first
		_stand()
	if state == "walk":
		_walk_clock(dt)
	elif state == "stomp":
		clip_time = _beat.advance(clip_time, dt)
	else:
		clip_time += dt * clips.fps
	_blend = minf(1.0, _blend + dt / BLEND_SECONDS)
	if state.begins_with("turn"):
		_steer_turn()


## Standing: a heading error past TURN_TRIGGER turns on the spot with a turn clip, else the idle.
func _stand() -> void:
	var err := wrapf(model_yaw - body_yaw, -PI, PI)
	if absf(err) > TURN_TRIGGER:
		var turn := "turn_left" if err > 0.0 else "turn_right"
		var span: Vector2 = _turn_span[turn]
		_turn_from = body_yaw
		_go(turn, maxf(0.0, span.x - TURN_PAD))
	elif state != "idle":
		_go("idle", 0.0)


## The walk clip's clock: the sim's step clock when it gives one (the footfalls land where it
## turns), else the distance walked.
func _walk_clock(dt: float) -> void:
	var cycles := speed * dt / maxf(stride(), 0.0001)
	walk_cycles += cycles
	var was := clip_time
	if step_phase != INF:
		clip_time = _steps.frame_at(step_phase)
	else:
		clip_time += cycles * float(clips.frames_of("walk")) / clips.cycles_of("walk")
	walk_frames += fposmod(clip_time - was, float(clips.frames_of("walk")))


func _go(next: String, at: float) -> void:
	if state == "walk" and next == "idle":
		_stomp.settle()  # the weight settles as he stops
	_from = state
	_from_time = clip_time
	_blend = 0.0
	state = next
	clip_time = at


## The walk frame to start from: the sim's step clock when it gives one, else the nearest to the
## feet (ClipSteps.entry).
func _walk_start() -> float:
	return _steps.frame_at(step_phase) if step_phase != INF else _steps.entry(self)


## The body follows the turn clip's yaw from where it faced to the new heading.
func _steer_turn() -> void:
	var yaw := absf(clips.pose_at(state, clip_time).yaw)
	var full := absf(clips.pose_at(state, clips.frames_of(state) - 1).yaw)
	var k := clampf(yaw / maxf(full, 0.001), 0.0, 1.0)
	body_yaw = lerp_angle(_turn_from, model_yaw, k)
	_body_yaw_v = 0.0
	rig.rotation.y = wrapf(body_yaw - model_yaw, -PI, PI)


func _apply(pose: KaijuClips.Pose, dt: float) -> void:
	_jaw_hold = clampf(_jaw_hold + (dt if head.held_open else -dt) / JAW_HOLD_SECONDS, 0.0, 1.0)
	swing.tick_whip(dt)
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
			q = Quaternion(Vector3.UP, bend) * q
		var offset := pose.offset * clips.rig_scale + drop if i == 0 else Vector3.ZERO
		rig.pose_basis(bone_name, Basis(q), offset)
	swing.youth = clampf((ADULT_SCALE - s) / (ADULT_SCALE - BABY_SCALE), 0.0, 1.0)
	swing.pose_rake(dt)  # the claw rake, over the clip's arms


## Turns the neck and skull about the world's up into the turn still to make (after the clip).
func _look_ahead(dt: float) -> void:
	var ahead := clampf(0.0 if turn_ahead == INF else turn_ahead, -HEAD_LEAD_MAX, HEAD_LEAD_MAX)
	_look = lerpf(_look, ahead, minf(1.0, dt * HEAD_LEAD_EASE))
	for bone_name: String in ["head0", "head1"]:
		if rig.has_bone(bone_name):
			var share := NECK_SHARE if bone_name == "head0" else 1.0 - NECK_SHARE
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


## Planted feet hold their spot in the world; a lifted foot follows its clip path, starting from
## where it left the ground. The body sinks if a leg would lock straight, then the legs are
## re-solved to reach (two-bone IK, LegReach).
func _plant_feet(pose: KaijuClips.Pose, dt: float) -> void:
	var targets: Array[Vector3] = []
	var fixes: Array[float] = []  # each foot's yaw: a planted one held, a lifted one easing back
	for i: int in mini(legs.size(), 2):
		targets.append(_foot_target(i, pose, dt))
		var held := _hold.hold(_plant_yaw[i], _plant_heading[i], legs[i])
		fixes.append(held if legs[i].planted else _yaw_fix[i] * exp(-FOOT_YAW_DECAY * dt))
	_ik.lower_body(self, targets, fixes, dt)
	for i: int in targets.size():
		var planted := legs[i].planted
		_yaw_fix[i] = _hold.held(legs[i], s, targets[i], fixes[i]) if planted else fixes[i]
		_ik.reach(self, i, targets[i], _yaw_fix[i])
	_feet_primed = true


## Where foot i's toe goes this frame (world), and whether it is down (leg.planted): a catch step,
## a planted foot's lock, or its path through the air.
func _foot_target(i: int, pose: KaijuClips.Pose, dt: float) -> Vector3:
	var leg := legs[i]
	var clip_toe := rig.global_transform * _stepped(clips.to_rig(pose.feet[i]))
	var planted := pose.planted[i] and not _stomp.catching(i)
	if planted and _was_planted[i] and _overreached(leg, _lock[i], clip_toe):
		_stomp.restep(i)  # the body got away from this foot: step after it
		planted = false
	var target := clip_toe + _lag[i]
	if _stomp.catching(i):
		var k := _stomp.advance(i, dt)
		_lag[i] *= 1.0 - smoothstep(0.0, 1.0, k)
		target = clip_toe + _lag[i] + Vector3.UP * _stomp.rise(i, k) * hip_height * s
		if not _stomp.catching(i):  # on the street this frame: it plants now, not a frame on
			planted = pose.planted[i]
			target = _put_down(i, target, clip_toe) if planted else target
	elif planted:
		target = _put_down(i, target, clip_toe)
	else:
		_stomp.forget(i)
		if _was_planted[i]:
			_path.lift(i, walk_frames, clip_toe, _lock[i])
		target = _path.target(self, i, dt, clip_toe)
		_lag[i] = _path.lag[i]
	leg.planted = planted
	_was_planted[i] = planted
	return target


## A foot the clip has down: it locks where it lands, its footfall goes out; returns its spot.
func _put_down(i: int, target: Vector3, clip_toe: Vector3) -> Vector3:
	var leg := legs[i]
	if not _was_planted[i]:
		_lock[i] = target
		_plant_yaw[i] = _hold.rig_yaw()
		_plant_heading[i] = _hold.foot_yaw(leg)
		leg.plant_at = target
		leg.drift = 0.0
		var strength := (
			ClipStomp.weight(s)
			if state == "stomp"
			else _stomp.landing(i, clampf(0.2 + speed_k(), 0.0, 1.0), s)
		)
		if _feet_primed:  # the first frame's feet were already down: no step, no ring
			rig.foot_planted.emit("left" if leg.side < 0.0 else "right", strength, target)
	_lag[i] = _lock[i] - clip_toe
	return _lock[i]


## A foot spot of the clip with its fore-aft travel shortened to the step the sim takes (a quick
## step in a turn is a short one, ClipSteps.shortened); a body that turns smoothly (the young
## croc, D-131) bends it onto the curve it walks (ClipSteps.curved: its wide-set planted feet
## stayed straight and were re-stepped every plant on a held curve, motion gate 2.2 a second).
func _stepped(toe: Vector3) -> Vector3:
	if state != "walk":
		return toe
	if step_phase == INF:  # a smooth turner (D-131) walks the curve its body turns
		return _steps.curved(toe, -yaw_rate / maxf(speed, 0.01) * s)
	return _steps.shortened(toe, step_ratio)


## True when a planted foot has been left too far behind (or ahead) of its clip spot to hold.
func _overreached(leg: BipedGait.Leg, lock: Vector3, clip_toe: Vector3) -> bool:
	if (lock - clip_toe).length() > RESTEP_GAP * stride():
		return true
	var hip := rig.bone(leg.names[0]).global_position
	var ankle := lock + (rig.bone(leg.names[2]).global_position - rig.tail_world(leg.names[2]))
	return (ankle - hip).length() > RESTEP_REACH * (leg.l1 + leg.l2) * s
