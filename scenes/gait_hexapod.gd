class_name HexapodGait
extends KaijuGait
## The insectoid's walk (a mantis: four walking legs, two raptorial arms): it skitters. Legs
## step in diagonal pairs with fast, snapping swings; it moves in bursts with micro-pauses where
## the body freezes and the sim's motion is caught up in a dash; joints snap from pose to pose
## like a machine: the head jerks between targets and cocks sideways, antennae and arms twitch,
## the abdomen pulses. A stomp is a quick strike of the arms.

const LEGS: Array[String] = ["leg_l", "leg_r", "hind_l", "hind_r"]
## Diagonal pairs step together: front-left with hind-right, then front-right with hind-left.
const PAIR := {"leg_l": 0.0, "hind_r": 0.0, "leg_r": 0.5, "hind_l": 0.5}
## Stride: duration bounds (s at scale 1), swing share, step length (hip heights) and lift.
const CYCLE_MIN := 0.22
const CYCLE_MAX := 0.5
const SWING := 0.45
const STEP := 0.7
const LIFT := 0.4
const STAND_SPEED := 0.1
const SETTLE_DISTANCE := 0.14
## Skitter: seconds moving, seconds frozen, catch-up rate (1/s), the most it may fall behind
## (hip heights), and how much quicker its steps are in a burst.
const BURST := Vector2(0.2, 0.5)
const FREEZE := Vector2(0.1, 0.4)
const CATCH_UP := 14.0
const MAX_LAG := 1.0
const BURST_CADENCE := 0.65
## Head: seconds between snaps, snap spring, how far it turns, pitches and cocks sideways.
const HEAD_HOLD := Vector2(0.15, 0.7)
const HEAD_OMEGA := 34.0
const HEAD_YAW := 0.7
const HEAD_PITCH := 0.25
const HEAD_COCK := 0.45
const HEAD_TREMBLE := 0.04
## Twitches: seconds between them; arm strike reach (rad) and how many stomps between strikes.
const TWITCH_EVERY := Vector2(0.12, 0.5)
const STRIKE := 0.9
const STRIKE_EVERY := 3
## Body: abdomen pulse (Hz, rad), stalking rock (Hz, hip heights), reach margin.
const PULSE_HZ := 2.2
const PULSE := 0.05
const ROCK_HZ := 1.3
const ROCK := 0.02
const REACH_STEP := 0.96
## Scythes: held raised and folded against the chest (femur forward-up, tibia folded back down
## along it, claw tucked); a strike throws them out; twitches jolt them (rad).
const FOLD_FEMUR := Vector3(0.15, 0.6, 0.7)  ## out, up, forward
const FOLD_TIBIA := Vector3(0.1, -0.75, -0.55)
const FOLD_CLAW := Vector3(0.0, -0.6, 0.6)
const STRIKE_FEMUR := Vector3(0.1, 0.25, 1.0)
const STRIKE_TIBIA := Vector3(0.0, -0.2, 1.0)
const TWITCH_JOLT := 0.5
## A planted leg's knee flicks out and back (snap rate 1/s, how far in hip-widths).
const KNEE_SNAP := 9.0
const KNEE_FLICK := 1.6
## An insect's footfall is light (KaijuRig.foot_planted strength at a standstill; doubles at speed).
const STEP_WEIGHT := 0.18
## Feet stand this share of the way out from the hips (the sculpt's legs are nearly straight)
## and land within this share of the leg's reach.
const HOME_IN := 0.85
const LAND_REACH := 0.9


class Leg:
	var names: Array[String] = []
	var offset := 0.0
	var home := Vector3.ZERO
	var l1 := 0.0
	var l2 := 0.0
	var tarsus := Vector3.DOWN  ## rest ankle->foot, rig space
	var foot := Vector3.ZERO
	var planted := true
	var from := Vector3.ZERO
	var t := 0.0
	var swing_time := 0.15
	var last_cycle := -1
	var side := 1.0
	var plant_at := Vector3.ZERO
	var id := ""  ## footfall id: "fl", "fr", "bl", "br"
	var snap := 0.0  ## knee flick after a plant, 1 -> 0


var legs: Array[Leg] = []
var _phase := 0.0
var _cycle := 0.4
var _frozen := false
var _state_left := 0.3
var _lag := Vector3.ZERO  # world offset the body is held back by
var _head := Vector3.ZERO  # yaw, pitch, roll offsets now
var _head_v := Vector3.ZERO
var _head_target := Vector3.ZERO
var _head_hold := 0.5
var _twitch_in := 0.8
var _arm_twitch := {"arm_l": 0.0, "arm_r": 0.0}
var _strike := 0.0
var _stomps := 0
var _rear := 0.0
var _jolt := 0.0
var _ready := false


func _init(p_rig: KaijuRig) -> void:
	super(p_rig)
	turn_max = 5.0
	var hips := 0.0
	for prefix: String in LEGS:
		if not rig.has_bone(prefix + "2"):
			continue
		var leg := Leg.new()
		for i: int in 3:
			leg.names.append("%s%d" % [prefix, i])
		leg.offset = PAIR[prefix]
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
		chain.stiffness = 40.0  # stiff, springy feelers
		chain.gravity_scale = 0.3


func update(delta: float) -> void:
	track(delta)
	var dt := minf(delta, 1.0 / 20.0)
	var hip_w := hip_height * s
	_skitter(dt, hip_w)
	var root := rig.global_transform
	var standing := speed < STAND_SPEED * hip_w or _frozen
	if not standing:
		var k := sqrt(s)
		_cycle = clampf(2.0 * STEP * hip_w / maxf(speed, 0.001), CYCLE_MIN * k, CYCLE_MAX * k)
		_cycle *= BURST_CADENCE  # it only steps in bursts: quick ones
	_step(dt, root, standing)
	_pose_body(dt)
	_solve(root, dt)
	_pose_head(dt)
	_twitch(dt)
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
		_strike = 1.0


func roar() -> void:
	_rear = 1.0
	_strike = 1.0


## Bursts and freezes: frozen, the body holds its place in the world while the sim moves on;
## then it dashes to catch up.
func _skitter(dt: float, hip_w: float) -> void:
	_state_left -= dt
	if _state_left <= 0.0:
		_frozen = not _frozen and speed > STAND_SPEED * hip_w
		var span := FREEZE if _frozen else BURST
		_state_left = rng.randf_range(span.x, span.y)
	if _frozen:
		_lag += velocity * dt
	else:
		_lag = _lag.lerp(Vector3.ZERO, minf(1.0, dt * CATCH_UP))
	_lag = _lag.limit_length(MAX_LAG * hip_w)
	var frame := rig.get_parent_node_3d().global_transform
	rig.position = frame.basis.inverse() * -_lag


func _step(dt: float, root: Transform3D, standing: bool) -> void:
	var ground := root.origin.y
	if not _ready:
		_ready = true
		for leg: Leg in legs:
			leg.foot = root * leg.home
			leg.plant_at = leg.foot
	var swinging := false
	for leg: Leg in legs:
		swinging = swinging or not leg.planted
	if not standing:
		_phase += dt / _cycle
		for leg: Leg in legs:
			var p := _phase - leg.offset
			var c := floori(p)
			if leg.planted and p - c < SWING and c != leg.last_cycle:
				leg.last_cycle = c
				_lift(leg, _cycle * SWING)
	elif not swinging:
		var worst: Leg = null
		var worst_d := SETTLE_DISTANCE * hip_height * s
		for leg: Leg in legs:
			var d := Vector2(leg.foot.x - (root * leg.home).x, leg.foot.z - (root * leg.home).z)
			if d.length() > worst_d:
				worst_d = d.length()
				worst = leg
		if worst != null:
			for leg: Leg in legs:
				if PAIR[leg.names[0].trim_suffix("0")] == worst.offset:
					_lift(leg, 0.12 * sqrt(s))
	for leg: Leg in legs:
		if leg.planted and _stretch(leg, root) > REACH_STEP:
			_lift(leg, 0.1 * sqrt(s))
		if leg.planted:
			leg.foot.y = ground
			continue
		leg.t = minf(1.0, leg.t + dt / leg.swing_time)
		var land := root * leg.home
		if not standing:
			land += velocity * ((1.0 - leg.t) * leg.swing_time + _cycle * (1.0 - SWING) * 0.5)
		land.y = ground
		land = _within_reach(leg, land, root)
		# Snap: most of the travel happens at once, then it settles (a fast ease-out).
		var e := 1.0 - pow(1.0 - leg.t, 4.0)
		leg.foot = leg.from.lerp(land, e)
		leg.foot.y = ground + sin(PI * minf(1.0, leg.t * 1.3)) * LIFT * hip_height * s
		if leg.t >= 1.0:
			leg.planted = true
			leg.foot = land
			leg.plant_at = land
			leg.snap = 1.0
			var stage := clampf(sqrt(s / 1.3), 0.4, 1.0)
			var weight := (
				STEP_WEIGHT + STEP_WEIGHT * clampf(speed / (2.0 * hip_height * s), 0.0, 1.0)
			)
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


func _lift(leg: Leg, seconds: float) -> void:
	leg.planted = false
	leg.from = leg.foot
	leg.t = 0.0
	leg.swing_time = maxf(0.06, seconds)


func _stretch(leg: Leg, root: Transform3D) -> float:
	var hip := rig.bone(leg.names[0]).global_position
	return (hip - _ankle(leg, root)).length() / ((leg.l1 + leg.l2) * s)


func _ankle(leg: Leg, root: Transform3D) -> Vector3:
	return leg.foot - root.basis * leg.tarsus


func _pose_body(dt: float) -> void:
	_jolt = maxf(0.0, _jolt - dt * 8.0)
	_rear = maxf(0.0, _rear - dt * 1.2)
	var rock := sin(time * TAU * ROCK_HZ) * ROCK * hip_height
	if not _frozen:
		rock *= 0.3
	# The rock is stepped, not smooth: a few twitchy positions a second.
	rock = snappedf(rock, ROCK * hip_height * 0.35)
	var rear := sin(PI * minf(1.0, _rear * 1.5)) * 0.5
	var drop := -_jolt * 0.06 * hip_height
	rig.pose("thorax0", Vector3(rear * 0.6, 0, 0), Vector3(rock, drop, 0))
	rig.pose("thorax1", Vector3(rear * 0.4 - 0.05 * _jolt, 0, 0))
	var pulse := sin(time * TAU * PULSE_HZ)
	for i: int in 3:
		rig.pose("abdomen%d" % i, Vector3(pulse * PULSE * (i + 1) * 0.5 - rear * 0.2, 0, 0))
	if rig.has_bone("abdomen1"):
		var swell := 1.0 + maxf(0.0, pulse) * 0.04
		rig.bone("abdomen1").scale = Vector3(swell, swell, 1.0)


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


func _pose_head(dt: float) -> void:
	if not rig.has_bone("head0"):
		return
	_head_hold -= dt
	if _head_hold <= 0.0:
		_head_hold = rng.randf_range(HEAD_HOLD.x, HEAD_HOLD.y)
		var lead := clampf(yaw_rate * 0.25, -0.5, 0.5)
		_head_target = Vector3(
			rng.randf_range(-HEAD_YAW, HEAD_YAW) * (0.4 if speed > 0.5 else 1.0) + lead,
			rng.randf_range(-HEAD_PITCH, HEAD_PITCH * 0.5),
			rng.randf_range(-HEAD_COCK, HEAD_COCK) if rng.randf() < 0.4 else 0.0
		)
	var target := _head_target + Vector3(0, -0.4 * _strike, 0)
	# A constant fine tremble under the snaps: it is never quite still.
	target += Vector3(rng.randf_range(-1, 1), rng.randf_range(-1, 1), 0) * HEAD_TREMBLE
	var a := (target - _head) * HEAD_OMEGA * HEAD_OMEGA - _head_v * (2.0 * 0.9 * HEAD_OMEGA)
	_head_v += a * dt
	_head += _head_v * dt
	var world := Basis(Vector3.UP, model_yaw + _head.x)
	world = world * Basis(Vector3.RIGHT, _head.y) * Basis(Vector3.BACK, _head.z)
	rig.set_world_basis("head0", world)


## Arms twitch and strike; antennae flick.
func _twitch(dt: float) -> void:
	_twitch_in -= dt
	if _twitch_in <= 0.0:
		_twitch_in = rng.randf_range(TWITCH_EVERY.x, TWITCH_EVERY.y)
		var arm := "arm_l" if rng.randf() < 0.5 else "arm_r"
		_arm_twitch[arm] = rng.randf_range(0.4, 1.0) * TWITCH_JOLT
		for chain: KaijuRig.SpringChain in rig.chains:
			if rng.randf() < 0.6:
				var kick := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.5, 1), 0) * 14.0 * s
				chain.kick(rig.global_transform.basis * kick / s, 1.0 / 60.0)
	_strike = maxf(0.0, _strike - dt * 3.2)
	# A strike shoots out fast and folds back slower.
	var lash := sin(PI * pow(1.0 - _strike, 0.5)) if _strike > 0.0 else 0.0
	for arm: String in ["arm_l", "arm_r"]:
		var tw: float = _arm_twitch[arm]
		_arm_twitch[arm] = maxf(0.0, tw - dt * 2.5)
		_pose_arm(arm, lash, snappedf(tw, 0.08))


## One scythe by aiming its three bones: folded against the chest at rest, thrown out on a strike
## (lash 0..1), jolted by a twitch.
func _pose_arm(arm: String, lash: float, jolt: float) -> void:
	if not rig.has_bone(arm + "2"):
		return
	var b := rig.global_transform.basis.orthonormalized()
	var side := -1.0 if arm.ends_with("_l") else 1.0
	var out := b.x * side
	var up := b.y
	var fwd := -b.z
	var dir := func(v: Vector3) -> Vector3: return (out * v.x + up * v.y + fwd * v.z).normalized()
	var femur: Vector3 = dir.call(FOLD_FEMUR.lerp(STRIKE_FEMUR, lash) + Vector3(0, jolt, 0))
	var tibia: Vector3 = dir.call(FOLD_TIBIA.lerp(STRIKE_TIBIA, lash) + Vector3(0, 0, jolt))
	var claw: Vector3 = dir.call(FOLD_CLAW.lerp(STRIKE_TIBIA, lash))
	var shoulder := rig.bone(arm + "0").global_position
	var elbow := shoulder + femur * rig.dir_of(arm + "0").length() * s
	var wrist := elbow + tibia * rig.dir_of(arm + "1").length() * s
	rig.aim(arm + "0", shoulder, elbow)
	rig.aim(arm + "1", elbow, wrist)
	rig.aim(arm + "2", wrist, wrist + claw * rig.dir_of(arm + "2").length() * s)
