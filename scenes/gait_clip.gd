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
## How fast a lifted foot's lag behind its clip path dies out (1/s): gone before it lands.
const LAG_DECAY := 10.0
## The roar clip's frame with the jaw at its widest (motion_test r7), held for the beam.
const ROAR_PEAK_FRAME := 47.0
const JAW_HOLD_SECONDS := 0.15
## The roar clip's frame where the tail tip hits the street (motion_test TAIL_SLAM), and how hard
## the hit lands as a footfall: about four steps' dust and ring and a camera dip of a few percent
## of the frame (the scene's footfall path; presentation only, no damage).
const ROAR_SLAM_FRAME := 47.0
const TAIL_SLAM_STRENGTH := 5.0
## A planted foot that ends this far from its clip spot (strides), or on a straight leg (fraction
## of the leg's length), takes a quick catch step (s, lift in hip heights) back to the clip.
const RESTEP_GAP := 0.3
const RESTEP_REACH := 0.98
const RESTEP_SECONDS := 0.25
const RESTEP_LIFT := 0.06
## The tail's mass on turns the clips don't carry (curves while walking, idle heading drift): a
## damped spring driven by the body's turning acceleration, natural frequency (rad/s) and damping
## ratio as the turn clips' whip (motion_test TAIL_SPRING); per-bone gain base -> tip (TAIL_WHIP),
## how long the swing takes to reach each next bone (s), and the swing it eases towards and never
## passes (rad; the sim turns faster than the clips, so a sharp turn would curl the tail too far).
const TAIL_SPRING := Vector2(14.0, 0.36)
const TAIL_GAIN := Vector2(7.8, 10.0)
const TAIL_DELAY := 0.021
const TAIL_MAX := 0.008

## Debug: true records the procedural gait instead (before/after captures, tools/capture).
static var off := false

var clips: KaijuClips
## The clip playing ("idle", "walk", "turn_left", "turn_right" or "roar") and its time (frames).
var state := "idle"
var clip_time := 0.0
## Walk cycles travelled so far (distance / stride), for tests and captures.
var walk_cycles := 0.0
## The tail spring's swing from the body's turning (rad; not counting the clips' own tail motion).
var tail_swing := 0.0
## The spring's swing, eased to TAIL_MAX: what the tail shows.
var tail_shown := 0.0
var _from := ""
var _from_time := 0.0
var _blend := 1.0
var _roar_queued := false
var _turn_from := 0.0
var _turn_span := {}  # turn clip -> Vector2(first, last frame of the yaw)
var _lock: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _lag: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _was_planted: Array[bool] = [false, false]
var _catch: Array[float] = [0.0, 0.0]  # seconds left of a catch step
var _jaw_hold := 0.0
var _jaw_peak := Quaternion.IDENTITY
## The tail spring's speed (rad/s), its swing as it reaches each bone, the body's last yaw rate.
var _tail_v := 0.0
var _tail_at: Array[float] = []
var _last_body_yaw := 0.0
var _last_yaw_rate := 0.0
var _tail_primed := false
var _tail_tip := ""  # the last tail bone (its tail is the tip)


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
		_turn_span[turn] = _yaw_span(turn)
	_jaw_peak = clips.pose_at("roar", ROAR_PEAK_FRAME).turns[clips.bones.find("jaw")]
	for bone_name: String in clips.bones:
		if bone_name.begins_with("tail"):
			_tail_at.append(0.0)
			_tail_tip = bone_name


func update(delta: float) -> void:
	track(delta)
	var dt := minf(delta, 1.0 / 20.0)
	var roar_was := clip_time if state == "roar" else -1.0
	_choose(dt)
	_swing_tail(dt)
	var pose := clips.pose_at(state, clip_time)
	if _blend < 1.0 and not _from.is_empty():
		pose = KaijuClips.mix(clips.pose_at(_from, _from_time), pose, smoothstep(0.0, 1.0, _blend))
	_apply(pose, dt)
	_slam_tail(roar_was)
	_plant_feet(pose, dt)
	_measure_slide()


## A roar starts at once, from whatever the kaiju is doing, and plays to its end.
func roar() -> void:
	_roar_queued = true


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
			_go(settle, _walk_entry() if moving else 0.0)
	elif state.begins_with("turn"):
		var span: Vector2 = _turn_span[state]
		if moving or clip_time >= span.y + TURN_SETTLE:
			_go(settle, _walk_entry() if moving else 0.0)
	elif moving:
		if state != "walk":
			_go("walk", _walk_entry())
	else:
		var err := wrapf(model_yaw - body_yaw, -PI, PI)
		if absf(err) > TURN_TRIGGER:
			var turn := "turn_left" if err > 0.0 else "turn_right"
			var span: Vector2 = _turn_span[turn]
			_turn_from = body_yaw
			_go(turn, maxf(0.0, span.x - TURN_PAD))
		elif state != "idle":
			_go("idle", 0.0)
	if state == "walk":
		var cycles := speed * dt / maxf(stride(), 0.0001)
		walk_cycles += cycles
		clip_time += cycles * float(clips.frames_of("walk")) / clips.cycles_of("walk")
	else:
		clip_time += dt * clips.fps
	_blend = minf(1.0, _blend + dt / BLEND_SECONDS)
	if state.begins_with("turn"):
		_steer_turn()


func _go(next: String, at: float) -> void:
	_from = state
	_from_time = clip_time
	_blend = 0.0
	state = next
	clip_time = at


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
	var yaw := absf(clips.pose_at(state, clip_time).yaw)
	var full := absf(clips.pose_at(state, clips.frames_of(state) - 1).yaw)
	var k := clampf(yaw / maxf(full, 0.001), 0.0, 1.0)
	body_yaw = lerp_angle(_turn_from, model_yaw, k)
	_body_yaw_v = 0.0
	rig.rotation.y = wrapf(body_yaw - model_yaw, -PI, PI)


## The first and last frames where a turn clip's yaw moves (0.5 deg from either end).
func _yaw_span(turn: String) -> Vector2:
	var n := clips.frames_of(turn)
	var full := clips.pose_at(turn, n - 1).yaw
	var first := 0
	while first < n - 1 and absf(clips.pose_at(turn, first).yaw) < 0.5:
		first += 1
	var last := first
	while last < n - 1 and absf(clips.pose_at(turn, last).yaw - full) > 0.5:
		last += 1
	return Vector2(first, last)


func _apply(pose: KaijuClips.Pose, dt: float) -> void:
	_jaw_hold = clampf(_jaw_hold + (dt if head.held_open else -dt) / JAW_HOLD_SECONDS, 0.0, 1.0)
	swing.tick_whip(dt)
	for i: int in clips.bones.size():
		var bone_name := clips.bones[i]
		var q := pose.turns[i]
		if bone_name == "jaw" and _jaw_hold > 0.0:
			q = q.slerp(_jaw_peak, smoothstep(0.0, 1.0, _jaw_hold))  # the maw held open (the beam)
		elif bone_name.begins_with("tail"):
			var i_tail := bone_name.to_int()
			var bend := swing.whip_yaw(i_tail) + _tail_at[i_tail] * _tail_gain(i_tail)
			q = Quaternion(Vector3.UP, bend) * q
		var offset := pose.offset * clips.rig_scale if i == 0 else Vector3.ZERO
		rig.pose_basis(bone_name, Basis(q), offset)


## The roar's tail slam lands as a heavy footfall where the tip meets the street.
func _slam_tail(roar_was: float) -> void:
	if state == "roar" and roar_was < ROAR_SLAM_FRAME and clip_time >= ROAR_SLAM_FRAME:
		var tip := rig.tail_world(_tail_tip)
		tip.y = rig.global_position.y
		rig.foot_planted.emit("tail", TAIL_SLAM_STRENGTH, tip)


## The tail lags the body's turns: the spring is pushed by the body's turning acceleration while
## walking (a standing turn plays a turn clip, which carries its own whip), and its swing reaches
## each bone a moment after the one before: a curve drags the tail wide, it whips back and settles.
func _swing_tail(dt: float) -> void:
	if not _tail_primed:  # the first frame: no turning yet
		_tail_primed = true
		_last_body_yaw = body_yaw
	var rate := wrapf(body_yaw - _last_body_yaw, -PI, PI) / dt
	var accel := (rate - _last_yaw_rate) / dt if state == "walk" else 0.0
	_last_body_yaw = body_yaw
	_last_yaw_rate = rate
	var wn := TAIL_SPRING.x
	_tail_v += (-wn * wn * tail_swing - 2.0 * TAIL_SPRING.y * wn * _tail_v - accel) * dt
	tail_swing += _tail_v * dt
	tail_shown = TAIL_MAX * tanh(tail_swing / TAIL_MAX)
	var reach := 1.0 - exp(-dt / TAIL_DELAY)
	var ahead := tail_shown
	for i: int in _tail_at.size():
		_tail_at[i] += (ahead - _tail_at[i]) * reach
		ahead = _tail_at[i]


func _tail_gain(i: int) -> float:
	var k := float(i) / maxf(1.0, _tail_at.size() - 1.0)
	return TAIL_GAIN.x + TAIL_GAIN.y * k


## Planted feet hold their spot in the world; a lifted foot follows its clip path, starting from
## where it left the ground. The legs are re-solved to reach (two-bone IK, the clip's knee side).
func _plant_feet(pose: KaijuClips.Pose, dt: float) -> void:
	var to_world := rig.global_transform
	for i: int in mini(legs.size(), 2):
		var leg := legs[i]
		var clip_toe := to_world * clips.to_rig(pose.feet[i])
		var planted := pose.planted[i] and _catch[i] <= 0.0
		if planted and _was_planted[i] and _overreached(leg, _lock[i], clip_toe):
			_catch[i] = RESTEP_SECONDS  # the body got away from this foot: step after it
			planted = false
		var target := clip_toe + _lag[i]
		if _catch[i] > 0.0:
			_catch[i] = maxf(0.0, _catch[i] - dt)
			var k := 1.0 - _catch[i] / RESTEP_SECONDS
			_lag[i] *= 1.0 - smoothstep(0.0, 1.0, k)
			target = clip_toe + _lag[i] + Vector3.UP * RESTEP_LIFT * hip_height * s * sin(PI * k)
		elif planted:
			if not _was_planted[i]:
				_lock[i] = target
				leg.plant_at = target
				leg.drift = 0.0
				var side := "left" if leg.side < 0.0 else "right"
				rig.foot_planted.emit(side, clampf(0.2 + speed_k(), 0.0, 1.0), target)
			target = _lock[i]
			_lag[i] = _lock[i] - clip_toe
		else:
			_lag[i] *= exp(-LAG_DECAY * dt)
		leg.planted = planted
		_was_planted[i] = planted
		_reach(leg, target)


## True when a planted foot has been left too far behind (or ahead) of its clip spot to hold.
func _overreached(leg: BipedGait.Leg, lock: Vector3, clip_toe: Vector3) -> bool:
	if (lock - clip_toe).length() > RESTEP_GAP * stride():
		return true
	var hip := rig.bone(leg.names[0]).global_position
	var ankle := lock + (rig.bone(leg.names[2]).global_position - rig.tail_world(leg.names[2]))
	return (ankle - hip).length() > RESTEP_REACH * (leg.l1 + leg.l2) * s


func _reach(leg: BipedGait.Leg, toe: Vector3) -> void:
	var foot := rig.bone(leg.names[2])
	var ankle_now := foot.global_position
	var shift := toe - rig.tail_world(leg.names[2])
	if shift.length() < 0.0001 * s:
		return
	var foot_basis := foot.global_transform.basis.orthonormalized()
	var hip := rig.bone(leg.names[0]).global_position
	var knee_now := rig.bone(leg.names[1]).global_position
	var ankle := ankle_now + shift
	var pole := knee_now - (hip + ankle_now) * 0.5
	var knee := KaijuGait.solve_knee(hip, ankle, leg.l1 * s, leg.l2 * s, pole)
	rig.aim(leg.names[0], hip, knee)
	rig.aim(leg.names[1], knee, ankle)
	rig.set_world_basis(leg.names[2], foot_basis)
