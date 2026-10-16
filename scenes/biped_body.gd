class_name BipedBody
extends RefCounted
## The reptilian's trunk (BipedGait drives it): a Godzilla-to-T-rex forward lean, a pelvis that
## takes each footfall's weight (it drops, rolls and sways over the standing leg, and holds back
## a beat on every plant before surging on), a chest that counters the hips, slow breathing.
## A young body wobbles: more bounce and sway, and now and then it overbalances and catches itself.

## Lean from the sculpt's upright pose (rad): standing, walking, per unit of forward accel.
## The sculpt stands ~16 deg off vertical, so the torso reads ~24 deg standing, ~30 walking.
const LEAN_STAND := 0.14
const LEAN_WALK := 0.24
const LEAN_ACCEL := 0.02
## Crouch: the pelvis sits this much lower (hip heights) standing and walking, so the knees bend.
const CROUCH_STAND := 0.03
const CROUCH_WALK := 0.09
## Footfall: drop (hip heights/s) and the hold-back surge; pelvis spring (heavy, slow to rise).
const FOOTFALL_JOLT := 1.7
const STOMP_JOLT := 2.3
## On each plant the body hangs back against its own travel (share of the speed): a visible
## pause, then a surge as the spring brings it back up to the sim's position.
const SURGE_HOLD := 0.95
const SURGE_OMEGA := 5.0
## The plant's drop and hold build over this long (s), not in one frame.
const PLANT_EASE := 0.07
const PELVIS_OMEGA := 9.0
const PELVIS_ZETA := 0.7
## Weight shift over the stance leg: sideways (hip heights), roll and hip yaw (rad).
const SWAY := 0.12
const ROLL := 0.13
const HIP_YAW := 0.16
## A stretched planted foot: the pelvis sinks at most this much (hip heights), easing back up.
const MAX_SINK := 0.18
const SINK_RECOVER := 1.5
## The chest counters the hips' yaw and takes out their roll, so the shoulders ride level
## (director: the weight shows in the hips, not the shoulders); slow breathing (Hz, rad).
const CHEST_COUNTER := 0.5
const SHOULDER_LEVEL := 1.0
const BREATH_HZ := 0.22
const BREATH := 0.022
## Youth: extra bounce and sway, and an overbalance every few seconds (s) of this size (rad).
const YOUTH_BOUNCE := 0.6
const YOUTH_SWAY := 0.8
const STUMBLE_EVERY := Vector2(3.0, 6.0)
const STUMBLE := 0.22
## A trip: how deep the pelvis dips (hip heights) and over how long (s).
const TRIP_DIP := 0.35
## A trip pitches the body forward (rad/s kick); a young body's bounce varies step to step.
const TRIP_PITCH := 3.5
const YOUTH_BOB_VARY := 0.3
const TRIP_EASE := 0.15

var g: BipedGait
## Hip yaw this frame (rad): the tail and arms swing against it.
var hip_yaw := 0.0
## Pelvis drop speed this frame (rig units/s): the tail flicks against it.
var pelvis_speed := 0.0
var _pelvis := Vector2.ZERO  # height offset, velocity
var _surge := Vector2.ZERO  # how far the body hangs back, velocity
var _sway := Vector2.ZERO
var _roll := Vector2.ZERO
var _yaw := Vector2.ZERO
var _lean := Vector2.ZERO
var _sink := 0.0
var _stumble_in := 3.0
var _ease_left := 0.0
var _drop_rate := 0.0
var _hold_rate := 0.0


func _init(gait: BipedGait) -> void:
	g = gait


## How far (world units) the body hangs back at the deepest of a plant's hold.
func hold_back() -> float:
	return SURGE_HOLD * g.speed / SURGE_OMEGA * 0.5


## A foot came down (weight 0..1, 1 = a stomp): the body drops and hangs back for a beat.
func plant(weight: float) -> void:
	var jolt := lerpf(FOOTFALL_JOLT, STOMP_JOLT, weight) * (1.0 + YOUTH_BOUNCE * g.youth)
	jolt *= 1.0 + g.youth * g.rng.randf_range(-YOUTH_BOB_VARY, YOUTH_BOB_VARY)  # no two alike
	_ease_left = PLANT_EASE
	_drop_rate = jolt * g.hip_height / PLANT_EASE
	_hold_rate = SURGE_HOLD * g.speed / maxf(0.001, g.s) / PLANT_EASE


func update(dt: float, root: Transform3D, roar_lean: float) -> void:
	var speed_k := g.speed_k()
	var legs := g.legs
	var w_l := 1.0 if legs[0].planted else 0.0
	var w_r := 1.0 if legs[1].planted else 0.0
	var fwd := -root.basis.z.normalized()
	var mid := (legs[0].foot + legs[1].foot) * 0.5
	var ahead := (legs[0].foot - mid).dot(fwd) - (legs[1].foot - mid).dot(fwd)
	var h := g.hip_height
	var wobble := 1.0 + YOUTH_SWAY * g.youth
	_stumble(dt, speed_k)
	_sway = KaijuGait.spring(_sway.x, _sway.y, SWAY * h * (w_r - w_l) * wobble, 5.0, 0.6, dt)
	_roll = KaijuGait.spring(_roll.x, _roll.y, -ROLL * (w_r - w_l) * wobble, 5.0, 0.55, dt)
	var yaw_target := -HIP_YAW * clampf(ahead / (h * g.s), -1.0, 1.0)
	_yaw = KaijuGait.spring(_yaw.x, _yaw.y, yaw_target, 6.0, 0.7, dt)
	hip_yaw = _yaw.x
	var forward_accel := g.accel.dot(fwd) / maxf(0.001, g.s)
	var lean_target := lerpf(LEAN_STAND, LEAN_WALK, speed_k)
	lean_target += clampf(forward_accel * LEAN_ACCEL, -0.08, 0.1) + roar_lean
	_lean = KaijuGait.spring(_lean.x, _lean.y, lean_target, 4.0, 0.9, dt)
	var crouch := lerpf(CROUCH_STAND, CROUCH_WALK, speed_k) * h
	if _ease_left > 0.0:
		var step := minf(dt, _ease_left)
		_pelvis.y -= _drop_rate * step
		_surge.y += _hold_rate * step
		_ease_left -= step
	_pelvis = KaijuGait.spring(_pelvis.x, _pelvis.y, -crouch, PELVIS_OMEGA, PELVIS_ZETA, dt)
	_surge = KaijuGait.spring(_surge.x, _surge.y, 0.0, SURGE_OMEGA, 0.75, dt)
	pelvis_speed = _pelvis.y
	var euler := Vector3(-_lean.x, _yaw.x, _roll.x)
	var offset := Vector3(_sway.x, _pelvis.x, _surge.x)
	g.rig.pose("spine0", euler, offset)
	# Keep every planted foot in reach: sink the pelvis (at once) rather than let a foot slide,
	# and ease back up (never pop) once it is no longer needed.
	var need := 0.0
	for leg: BipedGait.Leg in legs:
		if leg.planted:
			need = maxf(need, reach_drop(leg, root) / g.s)
	need = minf(need, MAX_SINK * h)
	_sink = maxf(need, move_toward(_sink, need, dt * SINK_RECOVER * h))
	if _sink > 0.0:
		g.rig.pose("spine0", euler, offset - Vector3(0, _sink, 0))
	var breath := sin(g.time * TAU * BREATH_HZ) * BREATH
	var counter := -CHEST_COUNTER * _yaw.x
	var level := -SHOULDER_LEVEL * _roll.x
	g.rig.pose("spine1", Vector3(breath + 0.03 * _lean.x, counter, level * 0.65))
	g.rig.pose("spine2", Vector3(breath * 0.6 + 0.03 * _lean.x, counter, level * 0.35))


## A young body trips now and then while walking: the pelvis dips and lurches to one side, the
## body stalls, and the foot on that side swings out quickly to catch it; then it walks on.
func _stumble(dt: float, speed_k: float) -> void:
	if g.youth < 0.1 or speed_k < 0.1 or absf(g.yaw_rate) > 0.4:
		return  # only on a straight walk, so it reads as one clear stumble
	_stumble_in -= dt
	if _stumble_in > 0.0:
		return
	_stumble_in = g.rng.randf_range(STUMBLE_EVERY.x, STUMBLE_EVERY.y)
	var side := 1.0 if g.rng.randf() < 0.5 else -1.0
	_ease_left = TRIP_EASE
	_drop_rate = TRIP_DIP * g.youth * g.hip_height / TRIP_EASE
	_hold_rate = g.speed / maxf(0.001, g.s) / TRIP_EASE
	_roll.y -= side * STUMBLE * g.youth * 8.0
	_lean.y += TRIP_PITCH * g.youth  # it pitches forward over the caught foot
	_sway.y += side * STUMBLE * g.youth * g.hip_height * 5.0
	catch_step(side)


## A trip's catch: the foot on that side (-1 left, +1 right) swings out fast to catch the body.
func catch_step(side: float) -> void:
	for leg: BipedGait.Leg in g.legs:
		if not leg.planted:
			return  # mid-stride: no room for a catch without two feet landing together
	for leg: BipedGait.Leg in g.legs:
		if leg.side == side and leg.planted:
			g._lift_foot(leg, BipedGait.CATCH_SECONDS * sqrt(g.s), BipedGait.LIFT_SLOW)
			leg.last_cycle = roundi(g._phase - leg.offset)


## How far (world units) the pelvis must sink for a planted foot's ankle to be in reach.
func reach_drop(leg: BipedGait.Leg, root: Transform3D) -> float:
	var d := g.rig.bone(leg.names[0]).global_position - g._ankle(leg, root)
	var reach := (leg.l1 + leg.l2) * g.s * 0.995
	if d.length() <= reach:
		return 0.0
	var du := d.y
	return du - sqrt(maxf(0.0, du * du - d.length_squared() + reach * reach))
