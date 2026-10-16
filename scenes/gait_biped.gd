class_name BipedGait
extends KaijuGait
## The reptilian's walk: a heavy, graceful predator (the Jurassic Park tyrannosaur).
## Feet plant and stay planted (two-bone IK to the knee, the metatarsus rolling over the toes),
## stride and cadence follow the real speed, the pelvis drops into each footfall and rolls over
## the stance leg, the body leans into the walk with the tail swinging against the hips, and the
## head stays level, scans, and leads every turn with a little overshoot.

## Swing share of a stride walking (both feet are down twice per stride) and at a run.
const SWING_WALK := 0.4
const SWING_RUN := 0.5
## How far a foot may travel under the body while planted (hip heights), so it stays in reach.
const STANCE_REACH := 1.15
## Step length in hip heights: at a standstill, how much it grows with speed, and its cap.
const STEP_MIN := 0.45
const STEP_PER_SPEED := 0.3
const STEP_MAX := 1.1
## Stride duration bounds (seconds at body scale 1; bigger bodies step slower by sqrt(scale)).
const CYCLE_MIN := 0.45
const CYCLE_MAX := 1.5
## Below this speed (hip heights/s) the kaiju stands; feet only step to settle.
const STAND_SPEED := 0.12
## A standing foot further than this (hip heights) from where it belongs takes a settling step.
const SETTLE_DISTANCE := 0.16
const SETTLE_SECONDS := 0.55
## Foot lift (hip heights) when walking slowly / fast, and on a stomp.
const LIFT_SLOW := 0.1
const LIFT_FAST := 0.18
const LIFT_STOMP := 0.3
## Feet track narrower than the hips (a predator walks almost on a line).
const TRACK_NARROWING := 0.82
## Crouch: the pelvis sits this much lower (hip heights) standing and walking, so the knees bend.
const CROUCH_STAND := 0.03
const CROUCH_WALK := 0.05
## A planted foot stretched past this share of its reach steps; past the second it hops.
const REACH_STEP := 0.97
const REACH_HOP := 1.02
## At most this much (hip heights) the pelvis sinks to keep a stretched foot planted.
const MAX_REACH_DROP := 0.18
## Pelvis: footfall jolt (hip heights/s), spring, sway over the stance leg, roll, yaw, lean.
const FOOTFALL_JOLT := 0.55
const STOMP_JOLT := 1.1
const PELVIS_OMEGA := 10.0
const PELVIS_ZETA := 0.42
const SWAY := 0.075
const ROLL := 0.07
const HIP_YAW := 0.1
const LEAN_STAND := 0.3
const LEAN_WALK := 0.48
const LEAN_ACCEL := 0.02
## Chest counters the hips so the shoulders ride steady; slow breathing.
const CHEST_COUNTER := 0.5
const BREATH_HZ := 0.22
const BREATH := 0.022


class Leg:
	var names: Array[String] = []
	var side := 1.0  ## -1 left (-x), +1 right
	var offset := 0.0  ## phase offset in the stride
	var home := Vector3.ZERO  ## rig space, on the ground
	var l1 := 0.0
	var l2 := 0.0
	var l3 := 0.0
	var met_up := Vector3.UP  ## rest direction from foot to ankle, rig space
	var foot := Vector3.ZERO  ## world
	var planted := true
	var lift_from := Vector3.ZERO
	var t := 0.0
	var swing_time := 0.4
	var lift := 0.2
	var stomping := false
	var last_cycle := -1
	var tilt := 0.0
	var walking := false  ## this swing is a walk step (its pace follows the stride)
	## Foot-slide meter: where the foot was planted, worst drift during this stance (world units).
	var plant_at := Vector3.ZERO
	var drift := 0.0


var legs: Array[Leg] = []
var head: BipedHead
var swing: BipedSwing
var _phase := 0.0
var _cycle := 1.0
var _swing := SWING_WALK
var _pelvis_y := 0.0
var _pelvis_vy := 0.0
var _sway := Vector2.ZERO  # value, velocity
var _roll := Vector2.ZERO
var _yaw := Vector2.ZERO
var _lean := Vector2.ZERO
var _stomp_times: Array[float] = []
var _stomp_leg := 0
var _stomp_planned := -1.0
var _settle_cool := 0.0
var _was_standing := true


func _init(p_rig: KaijuRig) -> void:
	super(p_rig)
	var hips := 0.0
	for side: String in ["l", "r"]:
		var leg := Leg.new()
		for i: int in 3:
			leg.names.append("leg_%s%d" % [side, i])
		if not rig.has_bone(leg.names[2]):
			continue
		leg.side = -1.0 if side == "l" else 1.0
		leg.offset = 0.0 if side == "l" else 0.5
		leg.l1 = rig.dir_of(leg.names[0]).length()
		leg.l2 = rig.dir_of(leg.names[1]).length()
		leg.l3 = rig.dir_of(leg.names[2]).length()
		var toe := rig.head_of(leg.names[2]) + rig.dir_of(leg.names[2])
		var hip := rig.head_of(leg.names[0])
		leg.home = Vector3(toe.x * TRACK_NARROWING, 0.0, hip.z - 0.06 * hip.y)
		leg.met_up = -rig.dir_of(leg.names[2]).normalized()
		hips += rig.head_of(leg.names[0]).y
		legs.append(leg)
	hip_height = hips / maxf(1.0, legs.size())
	head = BipedHead.new(self)
	swing = BipedSwing.new(rig)


func update(delta: float) -> void:
	track(delta)
	var dt := minf(delta, 1.0 / 20.0)
	var root := rig.global_transform
	var hip_w := hip_height * s
	var standing := speed < STAND_SPEED * hip_w
	var step_len := hip_w * clampf(STEP_MIN + STEP_PER_SPEED * speed / hip_w, STEP_MIN, STEP_MAX)
	if not standing:
		var k := sqrt(s)
		_swing = lerpf(SWING_WALK, SWING_RUN, clampf(speed / (2.0 * hip_w), 0.0, 1.0))
		var cycle := 2.0 * step_len / maxf(speed, 0.001)
		cycle = minf(cycle, STANCE_REACH * hip_w / (maxf(speed, 0.001) * (1.0 - _swing)))
		_cycle = clampf(cycle, CYCLE_MIN * k, CYCLE_MAX * k)
	_step_feet(dt, root, standing)
	_pose_body(dt, root)
	_solve_legs(root)
	head.update(dt, standing)
	swing.update(time, _yaw.x, head.roar_open())
	rig.simulate_chains(delta)
	_measure_slide()


func stomp() -> void:
	_stomp_times.append(time)
	if _stomp_times.size() > 3:
		_stomp_times.pop_front()
	for leg: Leg in legs:
		if leg.stomping and not leg.planted:
			leg.t = 1.0
	_pelvis_vy -= STOMP_JOLT * hip_height
	head.dip()
	var tail := rig.chain_named("tail0")
	if tail != null:
		tail.kick(Vector3(0, 9.0, 0) * s, 1.0 / 60.0)


func roar() -> void:
	head.roar()


# --- feet ----------------------------------------------------------------------------------------


func _step_feet(dt: float, root: Transform3D, standing: bool) -> void:
	var ground := root.origin.y
	if legs.size() < 2:
		return
	if legs[0].foot == Vector3.ZERO and legs[1].foot == Vector3.ZERO:
		for leg: Leg in legs:
			leg.foot = (root * leg.home)
			leg.plant_at = leg.foot
	var swinging := false
	for leg: Leg in legs:
		swinging = swinging or not leg.planted
	if not standing and _was_standing and not swinging:
		# Setting off: the foot furthest behind the direction of travel steps first.
		var first := legs[0]
		for leg: Leg in legs:
			if (leg.foot - root.origin).dot(velocity) < (first.foot - root.origin).dot(velocity):
				first = leg
		_phase = first.offset + 0.001 + ceilf(_phase)
		for leg: Leg in legs:
			leg.last_cycle = -999
	_was_standing = standing
	if not standing or swinging:
		_phase += dt / maxf(_cycle, 0.2)
	var stance_time := _cycle * (1.0 - _swing)
	# A planted foot left out of reach (a sudden turn or burst) steps now rather than slide;
	# if the other foot is still in the air, that one hurries down first.
	# A hard reversal can leave it no time: then it hops (both feet briefly off the ground).
	var hurry := 1.0
	for leg: Leg in legs:
		if leg.planted and _stretch(leg, root) > REACH_STEP:
			var other_air := 0.0
			for o: Leg in legs:
				if o != leg and not o.planted:
					other_air = maxf(other_air, 1.0 - o.t)
			if other_air == 0.0 or other_air < 0.55 or _stretch(leg, root) > REACH_HOP:
				var quick := 0.6 if other_air > 0.0 else 1.0
				_lift_foot(leg, minf(_cycle * _swing, SETTLE_SECONDS * sqrt(s)) * quick, LIFT_SLOW)
				leg.walking = not standing
			else:
				hurry = 2.5
	# Walking: each leg swings once per stride, in its slot.
	if not standing:
		for leg: Leg in legs:
			var p := _phase - leg.offset
			var cycle := floori(p)
			var local := p - cycle
			if leg.planted and local < _swing and cycle != leg.last_cycle:
				var speed_k := clampf(speed / (2.0 * hip_height * s), 0.0, 1.0)
				_lift_foot(leg, _cycle * _swing, lerpf(LIFT_SLOW, LIFT_FAST, speed_k))
				leg.walking = true
				leg.last_cycle = cycle
				leg.t = local / _swing
	else:
		_settle_cool -= dt
		_plan_stomp()
		if not swinging and _settle_cool <= 0.0:
			var worst: Leg = null
			var worst_d := SETTLE_DISTANCE * hip_height * s
			for leg: Leg in legs:
				var d := _flat(leg.foot - (root * leg.home)).length()
				if d > worst_d:
					worst_d = d
					worst = leg
			if worst != null:
				_lift_foot(worst, SETTLE_SECONDS * sqrt(s), LIFT_SLOW)
	for leg: Leg in legs:
		if leg.planted:
			leg.foot.y = ground
			continue
		if leg.walking:
			leg.swing_time = _cycle * _swing
		leg.t += dt * hurry / leg.swing_time
		var remaining := maxf(0.0, 1.0 - leg.t) * leg.swing_time
		var land := root * leg.home
		if not standing:
			land += velocity * (remaining + stance_time * 0.5)
		land.y = ground
		var e := leg.t * leg.t * (3.0 - 2.0 * leg.t)
		if leg.stomping:
			e = leg.t * leg.t  # hangs, then drives down
		var arc := sin(PI * pow(clampf(leg.t, 0.0, 1.0), 0.7))
		leg.foot = leg.lift_from.lerp(land, clampf(e, 0.0, 1.0))
		leg.foot.y = ground + arc * leg.lift * hip_height * s
		if leg.t >= 1.0:
			leg.foot = land
			_plant(leg, standing)


## How far a planted foot's ankle is from its hip, as a share of the leg's reach.
func _stretch(leg: Leg, root: Transform3D) -> float:
	var hip := rig.bone(leg.names[0]).global_position
	return (hip - _ankle(leg, root)).length() / ((leg.l1 + leg.l2) * s)


func _lift_foot(leg: Leg, seconds: float, lift: float) -> void:
	leg.planted = false
	leg.stomping = false
	leg.walking = false
	leg.lift_from = leg.foot
	leg.t = 0.0
	leg.swing_time = maxf(0.12, seconds)
	leg.lift = lift


func _plant(leg: Leg, standing: bool) -> void:
	leg.planted = true
	leg.plant_at = leg.foot
	leg.drift = 0.0
	var speed_k := clampf(speed / (2.0 * hip_height * s), 0.0, 1.0)
	var jolt := FOOTFALL_JOLT * (0.35 + 0.65 * speed_k) * hip_height
	if leg.stomping:
		jolt = STOMP_JOLT * hip_height
	_pelvis_vy -= jolt
	leg.stomping = false
	if standing:
		_settle_cool = 0.12


## Standing still, the sim's stomp arrives on a beat: lift a foot early so it slams down on it.
func _plan_stomp() -> void:
	if _stomp_times.size() < 2:
		return
	var interval := _stomp_times[-1] - _stomp_times[-2]
	if interval < 0.2 or interval > 3.0:
		return
	var next := _stomp_times[-1] + interval
	if _stomp_planned >= next - 0.001:
		return
	var windup := minf(0.3, interval * 0.55)
	if time < next - windup:
		return
	for leg: Leg in legs:
		if not leg.planted:
			return
	_stomp_planned = next
	_stomp_leg = 1 - _stomp_leg
	var leg := legs[_stomp_leg]
	_lift_foot(leg, next - time, LIFT_STOMP)
	leg.stomping = true


# --- body ----------------------------------------------------------------------------------------


func _pose_body(dt: float, root: Transform3D) -> void:
	var speed_k := clampf(speed / (2.0 * hip_height * s), 0.0, 1.0)
	var w_l := 1.0 if legs[0].planted else 0.0
	var w_r := 1.0 if legs[1].planted else 0.0
	var fwd := -root.basis.z.normalized()
	var mid := (legs[0].foot + legs[1].foot) * 0.5
	var ahead := (legs[0].foot - mid).dot(fwd) - (legs[1].foot - mid).dot(fwd)
	_sway = spring(_sway.x, _sway.y, SWAY * hip_height * (w_r - w_l), 6.0, 0.8, dt)
	_roll = spring(_roll.x, _roll.y, -ROLL * (w_r - w_l), 6.0, 0.7, dt)
	var yaw_target := -HIP_YAW * clampf(ahead / (hip_height * s), -1.0, 1.0)
	_yaw = spring(_yaw.x, _yaw.y, yaw_target, 8.0, 0.8, dt)
	var forward_accel := accel.dot(fwd) / maxf(0.001, s)
	var lean_target := lerpf(LEAN_STAND, LEAN_WALK, speed_k)
	lean_target += clampf(forward_accel * LEAN_ACCEL, -0.08, 0.1)
	lean_target += head.roar_lean()
	_lean = spring(_lean.x, _lean.y, lean_target, 5.0, 0.9, dt)
	var crouch := lerpf(CROUCH_STAND, CROUCH_WALK, speed_k) * hip_height
	var p := spring(_pelvis_y, _pelvis_vy, -crouch, PELVIS_OMEGA, PELVIS_ZETA, dt)
	_pelvis_y = p.x
	_pelvis_vy = p.y
	var breath := sin(time * TAU * BREATH_HZ) * BREATH
	var euler := Vector3(-_lean.x, _yaw.x, _roll.x)
	rig.pose("spine0", euler, Vector3(_sway.x, _pelvis_y, 0))
	# Keep every planted foot in reach: drop the pelvis rather than let a foot slide.
	var drop := 0.0
	for leg: Leg in legs:
		if not leg.planted:
			continue
		var hip := rig.bone(leg.names[0]).global_position
		var ankle := _ankle(leg, root)
		var reach := (leg.l1 + leg.l2) * s * 0.995
		var d := hip - ankle
		var up := Vector3.UP
		var du := d.dot(up)
		var disc := du * du - d.length_squared() + reach * reach
		if d.length() > reach:
			drop = maxf(drop, du - sqrt(maxf(0.0, disc)))
	if drop > 0.0:
		var sink := minf(drop / s, MAX_REACH_DROP * hip_height)
		rig.pose("spine0", euler, Vector3(_sway.x, _pelvis_y - sink, 0))
	rig.pose("spine1", Vector3(breath + 0.03 * _lean.x, -CHEST_COUNTER * _yaw.x, -0.4 * _roll.x))
	rig.pose(
		"spine2", Vector3(breath * 0.6 + 0.03 * _lean.x, -CHEST_COUNTER * _yaw.x, -0.3 * _roll.x)
	)


# --- legs ----------------------------------------------------------------------------------------


func _ankle(leg: Leg, root: Transform3D) -> Vector3:
	var right := root.basis.x.normalized()
	var up := (root.basis * leg.met_up).normalized()
	return leg.foot + up.rotated(right, leg.tilt) * leg.l3 * s


func _solve_legs(root: Transform3D) -> void:
	var fwd := -root.basis.z.normalized()
	var right := root.basis.x.normalized()
	for leg: Leg in legs:
		var hip := rig.bone(leg.names[0]).global_position
		var behind := (hip - leg.foot).dot(fwd) / (hip_height * s)
		if leg.planted:
			# The heel rises as the body passes over the toes.
			leg.tilt = lerpf(leg.tilt, -clampf(behind * 0.4, -0.1, 0.25), 0.35)
		else:
			var fold := sin(PI * clampf(leg.t, 0.0, 1.0))
			leg.tilt = lerpf(leg.tilt, -0.3 * fold + 0.06 * leg.t, 0.5)
		var ankle := _ankle(leg, root)
		var pole := fwd + right * leg.side * 0.2
		var knee := KaijuRig.solve_knee(hip, ankle, leg.l1 * s, leg.l2 * s, pole)
		rig.aim(leg.names[0], hip, knee)
		rig.aim(leg.names[1], knee, ankle)
		rig.aim(leg.names[2], ankle, leg.foot)


func _measure_slide() -> void:
	for leg: Leg in legs:
		if not leg.planted:
			continue
		var at := rig.tail_world(leg.names[2])
		leg.drift = maxf(leg.drift, _flat(at - leg.plant_at).length())
		max_drift = maxf(max_drift, leg.drift)


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)
