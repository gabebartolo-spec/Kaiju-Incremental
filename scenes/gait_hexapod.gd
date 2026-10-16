class_name HexapodGait
extends KaijuGait
## The insectoid's walk (a mantis: four walking legs, two raptorial arms): it never walks, it
## skitters. Moving, it alternates hard holds (body, legs, head and scythes dead still while the
## sim moves on) with darts that snap the body to where the sim is, the legs scrambling in
## diagonal pairs under it. Holds and darts are irregular. A turn is led by the legs: they
## step round to the new heading first and the body swings after them, in about 0.3 s. The
## upper body (HexapodUpper) snaps between held poses and twitches at rest.

const LEGS: Array[String] = ["leg_l", "leg_r", "hind_l", "hind_r"]
## Diagonal pairs step together: front-left with hind-right, then front-right with hind-left.
const PAIR := {"leg_l": 0, "hind_r": 0, "leg_r": 1, "hind_l": 1}
## Holds (s): usually short, sometimes long; a dart catches up at this many times the sim's
## speed and lasts at least DART_MIN (s). The body may fall this far behind (hip heights).
const HOLD := Vector2(0.1, 0.3)
const LONG_HOLD := Vector2(0.3, 0.45)
const LONG_HOLD_CHANCE := 0.3
const DART_RATE := 2.4
const DART_MIN := 0.06
const MAX_LAG := 2.2
## A hold needs the body facing within this of the sim's heading (rad); a dart's body waits this
## long (s) for its legs to lead.
const FACING := 0.1
const LEG_LEAD := 0.05
## More than this off heading (rad), the body waits for a leg to be in the air before it swings.
const BIG_TURN := 0.06
## How fast the body swings round after its legs (rad/s at scale 1).
const TURN_RATE := 9.5
const STAND_SPEED := 0.1
## A pair steps when its feet are this far (hip heights) from where they belong; swing times
## (s at scale 1) in a dart and settling; lift (hip heights); stretch that forces a step.
const STEP_AT := 0.2
const SETTLE_AT := 0.1
const SWING_DART := 0.075
const SWING_SETTLE := 0.11
const LIFT := 0.5
const REACH_STEP := 0.97
## A leg tap at rest: swing (s) and how far it shifts (hip heights).
const TAP_SWING := 0.09
const TAP_SHIFT := 0.12
## A planted leg's knee flicks out and back (snap rate 1/s, how far in hip-widths).
const KNEE_SNAP := 9.0
const KNEE_FLICK := 1.6
## An insect's footfall is light (KaijuRig.foot_planted strength at a standstill; doubles at speed).
const STEP_WEIGHT := 0.18
## Feet stand this share of the way out from the hips and land within this share of reach.
const HOME_IN := 0.85
const LAND_REACH := 0.9
## Body: abdomen pulse at rest (Hz, rad); a dart pitches the body down by this (rad).
const PULSE_HZ := 2.2
const PULSE := 0.05
const DART_PITCH := 0.12
## Perched: crouch (hip heights), forward pitch (rad).
const PERCH_CROUCH := 0.25
const PERCH_PITCH := 0.25
## How many stomps between scythe strikes.
const STRIKE_EVERY := 3


class Leg:
	var names: Array[String] = []
	var pair := 0
	var home := Vector3.ZERO
	var l1 := 0.0
	var l2 := 0.0
	var tarsus := Vector3.DOWN  ## rest ankle->foot, rig space
	var foot := Vector3.ZERO
	var planted := true
	var from := Vector3.ZERO
	var shift := Vector3.ZERO  ## a tap's landing offset (world)
	var t := 0.0
	var swing_time := 0.1
	var side := 1.0
	var plant_at := Vector3.ZERO
	var id := ""  ## footfall id: "fl", "fr", "bl", "br"
	var snap := 0.0  ## knee flick after a plant, 1 -> 0


var legs: Array[Leg] = []
## Perched on a roof (KaijuModel.climbing): a low, wide, coiled stance, scythes half raised.
var climbing := false
## True while the body is in a hard hold (for captures and tests).
var holding := false
var upper: HexapodUpper
var _hold_left := 0.0
var _dart_time := 0.0
var _held_yaw := 0.0
var _anchor := Vector3.ZERO
var _lag := Vector3.ZERO  # world offset the body is held back by
var _jolt := 0.0
var _stomps := 0
var _perch := 0.0
var _ready := false


func _init(p_rig: KaijuRig) -> void:
	super(p_rig)
	var hips := 0.0
	for prefix: String in LEGS:
		if not rig.has_bone(prefix + "2"):
			continue
		var leg := Leg.new()
		for i: int in 3:
			leg.names.append("%s%d" % [prefix, i])
		leg.pair = PAIR[prefix]
		leg.side = -1.0 if prefix.ends_with("_l") else 1.0
		leg.id = ("f" if prefix.begins_with("leg") else "b") + ("l" if leg.side < 0.0 else "r")
		leg.l1 = rig.dir_of(leg.names[0]).length()
		leg.l2 = rig.dir_of(leg.names[1]).length()
		leg.tarsus = rig.dir_of(leg.names[2])
		var foot := rig.head_of(leg.names[2]) + leg.tarsus
		var hip := rig.head_of(leg.names[0])
		var out := Vector2(foot.x - hip.x, foot.z - hip.z) * HOME_IN
		leg.home = Vector3(hip.x + out.x, 0.0, hip.z + out.y)
		hips += rig.head_of(leg.names[0]).y
		legs.append(leg)
	hip_height = hips / maxf(1.0, legs.size())
	for chain: KaijuRig.SpringChain in rig.chains:
		chain.stiffness = 60.0  # stiff, springy feelers
		chain.gravity_scale = 0.3
	upper = HexapodUpper.new(self)


func update(delta: float) -> void:
	track(delta)
	var dt := minf(delta, 1.0 / 20.0)
	var hip_w := hip_height * s
	var moving := speed > STAND_SPEED * hip_w
	_skitter(dt, hip_w, moving)
	if holding:
		# A hard hold: the body keeps its place and heading; nothing moves at all.
		rig.rotation.y = wrapf(_held_yaw - model_yaw, -PI, PI)
		body_yaw = _held_yaw
		return
	var root := rig.global_transform
	_step(dt, root, moving)
	_pose_body(dt)
	_solve(root, dt)
	upper.perch = _perch
	upper.update(dt, 0.0 if moving or _lag.length() > 0.05 * hip_w else 1.0)
	rig.simulate_chains(delta)
	for leg: Leg in legs:
		if leg.planted:
			var at := rig.tail_world(leg.names[2])
			max_drift = maxf(
				max_drift, Vector2(at.x - leg.plant_at.x, at.z - leg.plant_at.z).length()
			)


func stomp() -> void:
	_stomps += 1
	_jolt = 1.0
	if _stomps % STRIKE_EVERY == 0:
		upper.strike()


func roar() -> void:
	upper.roar()


## Holds and darts. Holding, the body stays put in the world (and keeps its heading) while the
## sim moves on; darting, it snaps to catch up, then holds again. A hold starts only with every
## foot down and the body facing the sim's heading, and ends early if the body falls too far
## behind. A dart that has to turn waits LEG_LEAD for the legs to start round first.
func _skitter(dt: float, hip_w: float, moving: bool) -> void:
	var frame := rig.get_parent_node_3d().global_transform
	if holding:
		_lag = frame.origin - _anchor
		_lag.y = 0.0
		_hold_left -= dt
		if _hold_left <= 0.0 or _lag.length() > MAX_LAG * hip_w or not moving:
			holding = false
			_dart_time = 0.0
	else:
		_dart_time += dt
		var rate := DART_RATE * maxf(speed, STAND_SPEED * hip_w * 4.0)
		_lag = _lag.move_toward(Vector3.ZERO, rate * dt)
		var facing := absf(wrapf(model_yaw - body_yaw, -PI, PI)) < FACING
		var down := true
		for leg: Leg in legs:
			down = down and leg.planted
		if moving and down and facing and _lag.length() < 0.01 * hip_w and _dart_time >= DART_MIN:
			holding = true
			_held_yaw = body_yaw
			_anchor = frame.origin
			var span := LONG_HOLD if rng.randf() < LONG_HOLD_CHANCE else HOLD
			_hold_left = rng.randf_range(span.x, span.y)
	rig.position = frame.basis.inverse() * -_lag
	if not holding:
		# The legs move first; then the body swings round after them at a constant, snappy rate.
		var airborne := false
		for leg: Leg in legs:
			airborne = airborne or not leg.planted
		var big := absf(wrapf(model_yaw - _held_yaw, -PI, PI)) > BIG_TURN
		if _dart_time >= LEG_LEAD and (airborne or not big):
			_held_yaw = rotate_toward(_held_yaw, model_yaw, TURN_RATE / sqrt(maxf(s, 0.01)) * dt)
		body_yaw = _held_yaw
		rig.rotation.y = wrapf(body_yaw - model_yaw, -PI, PI)


## Feet in diagonal pairs: a pair steps when it is out of place (it lands where the body is
## heading, on the sim's heading, so the legs lead a turn); a tap at rest moves one leg.
func _step(dt: float, root: Transform3D, moving: bool) -> void:
	var ground := root.origin.y
	var frame := rig.get_parent_node_3d().global_transform
	if not _ready:
		_ready = true
		for leg: Leg in legs:
			leg.foot = root * leg.home
			leg.plant_at = leg.foot
	var hip_w := hip_height * s
	var darting := _lag.length() > 0.05 * hip_w
	var swing := (SWING_DART if darting else SWING_SETTLE) * sqrt(s)
	# Where each foot belongs: under the body where it will be (the sim's place and heading).
	var lead := velocity * swing
	var swinging := PackedByteArray([0, 0])
	var worst := PackedFloat32Array([0.0, 0.0])
	for leg: Leg in legs:
		if not leg.planted:
			swinging[leg.pair] = 1
		var want := frame * leg.home + lead
		var off := Vector2(leg.foot.x - want.x, leg.foot.z - want.z).length()
		worst[leg.pair] = maxf(worst[leg.pair], off)
	var limit := (STEP_AT if moving or darting else SETTLE_AT) * hip_w
	if swinging[0] == 0 and swinging[1] == 0:
		var pick := 0 if worst[0] >= worst[1] else 1
		if worst[pick] > limit:
			for leg: Leg in legs:
				if leg.pair == pick:
					_lift(leg, swing, Vector3.ZERO)
		elif upper.tap_leg >= 0 and upper.tap_leg < legs.size():
			var tap := legs[upper.tap_leg]
			var shift := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1))
			_lift(tap, TAP_SWING * sqrt(s), shift.normalized() * TAP_SHIFT * hip_w)
	upper.tap_leg = -1
	for leg: Leg in legs:
		if leg.planted and _stretch(leg, root) > REACH_STEP:
			_lift(leg, swing, Vector3.ZERO)
		if leg.planted:
			leg.foot.y = ground
			continue
		leg.t = minf(1.0, leg.t + dt / leg.swing_time)
		var land := frame * leg.home + lead + leg.shift
		land.y = ground
		land = _within_reach(leg, land, root)
		# Snap: most of the travel happens at once, then it settles (a fast ease-out).
		var e := 1.0 - pow(1.0 - leg.t, 3.0)
		leg.foot = leg.from.lerp(land, e)
		var lift := LIFT * (1.0 if leg.shift == Vector3.ZERO else 0.6)
		leg.foot.y = ground + sin(PI * minf(1.0, leg.t * 1.2)) * lift * hip_w
		if leg.t >= 1.0:
			_plant(leg, land)


func _plant(leg: Leg, land: Vector3) -> void:
	leg.planted = true
	leg.foot = land
	leg.plant_at = land
	leg.snap = 1.0
	var stage := clampf(sqrt(s / 1.3), 0.4, 1.0)
	var weight := STEP_WEIGHT + STEP_WEIGHT * clampf(speed / (2.0 * hip_height * s), 0.0, 1.0)
	rig.foot_planted.emit(leg.id, weight * stage, land)


## Pulls a landing spot in so the leg can still reach it from the hip.
func _within_reach(leg: Leg, land: Vector3, root: Transform3D) -> Vector3:
	var hip := rig.bone(leg.names[0]).global_position
	var ankle := land - root.basis * leg.tarsus
	var reach := (leg.l1 + leg.l2) * s * LAND_REACH
	var dy := hip.y - ankle.y
	var flat := Vector2(ankle.x - hip.x, ankle.z - hip.z)
	var most := sqrt(maxf(0.0, reach * reach - dy * dy))
	if flat.length() <= most:
		return land
	var fixed := flat.normalized() * most - flat
	return land + Vector3(fixed.x, 0.0, fixed.y)


func _lift(leg: Leg, seconds: float, shift: Vector3) -> void:
	leg.planted = false
	leg.from = leg.foot
	leg.shift = shift
	leg.t = 0.0
	leg.swing_time = maxf(0.05, seconds)


func _stretch(leg: Leg, root: Transform3D) -> float:
	var hip := rig.bone(leg.names[0]).global_position
	return (hip - _ankle(leg, root)).length() / ((leg.l1 + leg.l2) * s)


func _ankle(leg: Leg, root: Transform3D) -> Vector3:
	return leg.foot - root.basis * leg.tarsus


func _pose_body(dt: float) -> void:
	_jolt = maxf(0.0, _jolt - dt * 8.0)
	_perch = lerpf(_perch, 1.0 if climbing else 0.0, minf(1.0, dt * 6.0))
	var hip_w := hip_height
	var dart := clampf(_lag.length() / maxf(0.001, 0.3 * hip_w * s), 0.0, 1.0)
	var jerk := upper.body_jerk
	var rear := upper.rear * HexapodUpper.REAR
	var drop := -_jolt * 0.06 * hip_w - PERCH_CROUCH * hip_w * _perch
	var pitch := rear - PERCH_PITCH * _perch - DART_PITCH * dart + jerk.y
	rig.pose("thorax0", Vector3(pitch, jerk.x, jerk.z), Vector3(0, drop, 0))
	rig.pose("thorax1", Vector3(rear * 0.6 - 0.05 * _jolt, 0, 0))
	var pulse := sin(time * TAU * PULSE_HZ) * PULSE
	for i: int in 3:
		var curl := (
			pulse * (i + 1) * 0.5 - rear * 0.3 + upper.abdomen_jerk * (0.6 if i == 0 else 0.3)
		)
		rig.pose("abdomen%d" % i, Vector3(curl, 0, 0))


func _solve(root: Transform3D, dt: float) -> void:
	var up := root.basis.y.normalized()
	var right := root.basis.x.normalized()
	for leg: Leg in legs:
		var hip := rig.bone(leg.names[0]).global_position
		var ankle := _ankle(leg, root)
		# An insect's knee rides high and out: the leg arches over the foot, rising further in a
		# swing and flicking out on the plant.
		leg.snap = maxf(0.0, leg.snap - KNEE_SNAP * dt)
		var swing_up := sin(PI * leg.t) if not leg.planted else 0.0
		var pole := up * (1.0 + swing_up) + right * leg.side * (0.6 + KNEE_FLICK * leg.snap)
		var knee := KaijuGait.solve_knee(hip, ankle, leg.l1 * s, leg.l2 * s, pole)
		rig.aim(leg.names[0], hip, knee)
		rig.aim(leg.names[1], knee, ankle)
		rig.aim(leg.names[2], ankle, leg.foot)
