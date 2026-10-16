class_name BipedGait
extends KaijuGait
## The reptilian's walk: halfway between Godzilla and the Jurassic Park tyrannosaur, with the
## tyrannosaur's grace (D-031). Feet plant and stay planted (two-bone IK to the knee, the
## metatarsus rolling over the toes); stride and cadence follow the real speed. BipedBody carries
## the weight, BipedHead the head, BipedSwing the tail and arms. A young body steps quicker.

## Swing share of a stride walking (both feet are down twice per stride) and at a run.
const SWING_WALK := 0.4
const SWING_RUN := 0.5
## A young body runs with a flight phase (fewer, longer strides); a stomp beat adds this weight.
const SWING_YOUNG := 0.7
const HEAVY_STEP := 0.2
## How far a foot may travel under the body while planted (hip heights), so it stays in reach.
const STANCE_REACH := 0.48
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
## A planted foot stretched past this share of its reach steps; past the second it hops.
const REACH_STEP := 0.99
const REACH_HOP := 1.02
## A foot lands within this share of the leg's reach, and stays down at least this share of a
## stride before a stretch can lift it again (unless it is past REACH_HOP).
const LAND_REACH := 0.9
const MIN_STANCE := 0.3
## Two footfalls never land closer together than this (s).
const PLANT_GAP := 0.2
## A trip's catch step (s at scale 1); stride-to-stride timing jitter (share of a stride).
const CATCH_SECONDS := 0.22
const STRIDE_JITTER := 0.05
## At most this much (hip heights) the pelvis sinks to keep a stretched foot planted.
const MAX_REACH_DROP := 0.18
## Body scale of an adult and a baby: in between, the walk is that much younger.
const ADULT_SCALE := 1.3
const BABY_SCALE := 0.5
## Footfall ids for KaijuRig.foot_planted, and a stage's share of a full adult step.
const SIDES := {-1.0: "left", 1.0: "right"}


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
	var down_for := 0.0  ## seconds since it planted
	## Foot-slide meter: where the foot was planted, worst drift during this stance (world units).
	var plant_at := Vector3.ZERO
	var drift := 0.0


var legs: Array[Leg] = []
var head: BipedHead
var swing: BipedSwing
var body: BipedBody
## 0 for an adult .. 1 for a baby: how young the walk is.
var youth := 0.0
var _phase := 0.0
var _cycle := 1.0
var _swing := SWING_WALK
var _heavy_next := false
var _jitter := 1.0
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
	body = BipedBody.new(self)


func update(delta: float) -> void:
	track(delta)
	youth = clampf((ADULT_SCALE - s) / (ADULT_SCALE - BABY_SCALE), 0.0, 1.0)
	var dt := minf(delta, 1.0 / 20.0)
	var root := rig.global_transform
	var hip_w := hip_height * s
	var standing := speed < STAND_SPEED * hip_w
	var step_len := hip_w * clampf(STEP_MIN + STEP_PER_SPEED * speed / hip_w, STEP_MIN, STEP_MAX)
	if not standing:
		var k := sqrt(s)
		_swing = lerpf(SWING_WALK, SWING_RUN, clampf(speed / (2.0 * hip_w), 0.0, 1.0))
		_swing = lerpf(_swing, SWING_YOUNG, youth)
		var cycle := 2.0 * step_len / maxf(speed, 0.001)
		cycle = minf(cycle, STANCE_REACH * hip_w / (maxf(speed, 0.001) * (1.0 - _swing)))
		_cycle = clampf(cycle, CYCLE_MIN * k, CYCLE_MAX * k) * _jitter
	_step_feet(dt, root, standing)
	body.update(dt, root, head.roar_lean())
	_solve_legs(root)
	head.update(dt, standing)
	swing.hip_drop = body.pelvis_speed / maxf(0.001, hip_height)
	swing.youth = youth
	swing.yaw_rate = yaw_rate
	swing.update(time, body.hip_yaw, head.roar_open(), dt)
	rig.simulate_chains(delta)
	_measure_slide()


func stomp() -> void:
	_stomp_times.append(time)
	if _stomp_times.size() > 3:
		_stomp_times.pop_front()
	var stomping := false
	for leg: Leg in legs:
		if leg.stomping and not leg.planted:
			leg.t = 1.0
			stomping = true
	if not stomping:
		_heavy_next = true  # walking: the next footfall is the stomp
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
	var hurry := 1.0
	for leg: Leg in legs:
		if leg.planted:
			leg.down_for += dt
		var settled := leg.down_for > MIN_STANCE * _cycle
		if leg.planted and _stretch(leg, root) > (REACH_STEP if settled else REACH_HOP):
			var other_left := 0.0  # seconds until the other foot lands, if it is in the air
			for o: Leg in legs:
				if o != leg and not o.planted:
					other_left = maxf(other_left, (1.0 - o.t) * o.swing_time)
			if other_left == 0.0 or _stretch(leg, root) > REACH_HOP:
				# A hard turn may need both feet up: then it lands well after the other (no pop).
				var swing := minf(_cycle * _swing, SETTLE_SECONDS * sqrt(s))
				_lift_foot(leg, maxf(swing, other_left + PLANT_GAP), LIFT_SLOW)
				leg.walking = false
				leg.last_cycle = roundi(_phase - leg.offset)  # this counts as its next stride slot
			else:
				hurry = 2.5
	# Walking: each leg swings once per stride, in its slot.
	if not standing:
		for leg: Leg in legs:
			var p := _phase - leg.offset
			var cycle := floori(p)
			var local := p - cycle
			if leg.planted and local < _swing and cycle != leg.last_cycle:
				_lift_foot(leg, _cycle * _swing, lerpf(LIFT_SLOW, LIFT_FAST, speed_k()))
				_jitter = 1.0 + rng.randf_range(-STRIDE_JITTER, STRIDE_JITTER)
				leg.walking = true
				leg.last_cycle = cycle
				leg.t = local / _swing
	else:
		_settle_cool -= dt
		var roaring := head.roar_open() > 0.0 or head.roar_lean() != 0.0
		if not roaring:  # roaring, the feet stay planted and still
			_plan_stomp()
		if not swinging and _settle_cool <= 0.0 and not roaring:
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
		land = _within_reach(leg, land, root)
		var e := leg.t * leg.t * (3.0 - 2.0 * leg.t)
		if leg.stomping:
			e = leg.t * leg.t  # hangs, then drives down
		var arc := sin(PI * pow(clampf(leg.t, 0.0, 1.0), 0.7))
		leg.foot = leg.lift_from.lerp(land, clampf(e, 0.0, 1.0))
		leg.foot.y = ground + arc * leg.lift * hip_height * s
		if leg.t >= 1.0:
			leg.foot = land
			_plant(leg, standing)


## Pulls a landing spot in so the leg reaches it comfortably from the hip, even while the body
## hangs back on the next plant.
func _within_reach(leg: Leg, land: Vector3, root: Transform3D) -> Vector3:
	var fwd := -root.basis.z.normalized()
	var hip := rig.bone(leg.names[0]).global_position - fwd * body.hold_back()
	var ankle := land + (_ankle(leg, root) - leg.foot)
	var reach := (leg.l1 + leg.l2) * s * LAND_REACH
	var dy := minf(hip.y - ankle.y, reach * 0.85)  # a high pelvis sinks to the foot
	var flat := Vector2(ankle.x - hip.x, ankle.z - hip.z)
	var most := sqrt(maxf(0.0, reach * reach - dy * dy))
	if flat.length() <= most:
		return land
	var fixed := flat.normalized() * most - flat
	return land + Vector3(fixed.x, 0.0, fixed.y)


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
	leg.down_for = 0.0
	leg.plant_at = leg.foot
	leg.drift = 0.0
	var weight := 0.35 + 0.45 * speed_k()
	if leg.stomping:
		weight = 1.0
	elif _heavy_next:  # walking, the stomp beat makes this step a little heavier, not a slam
		weight = minf(1.0, weight + HEAVY_STEP)
	_heavy_next = false
	body.plant(weight)
	var stage := clampf(sqrt(s / ADULT_SCALE), 0.4, 1.0)
	rig.foot_planted.emit(str(SIDES[leg.side]), weight * stage, leg.foot)
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


## 0..1: how fast it is going, in strides (2 hip heights a second = 1).
func speed_k() -> float:
	return clampf(speed / (2.0 * hip_height * s), 0.0, 1.0)


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
