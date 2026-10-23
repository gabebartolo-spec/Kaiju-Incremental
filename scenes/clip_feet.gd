class_name ClipFeet
extends RefCounted
## A clip-driven biped's hind feet (ClipGait): planted feet hold their spot in the world (a heavy
## body's where the sim put them down, D-208), a lifted foot follows its clip path from where it
## left the ground (SwingPath; a heavy body's on the sim's way), a foot left too far behind takes a
## catch step (ClipStomp); then the body sinks if a leg would lock straight and the legs are
## re-solved to reach (two-bone IK, LegReach). Part of ClipGait; presentation only.

## How fast a lifted foot's toes swing back to the clip's yaw after the body turned over them (1/s).
const FOOT_YAW_DECAY := 12.0
## A planted foot that ends this far from its clip spot (strides), or past a straight leg (fraction
## of the leg's length), takes a quick catch step back to the clip (ClipStomp). At 0.98 the
## adolescent's long legs, nearly straight at heel strike, re-stepped on every plant (PR #54).
const RESTEP_GAP := 0.3
const RESTEP_REACH := 1.0

var gait: ClipGait
var _stomp: ClipStomp  # catch steps, and the standing stomp (the gait's)
var _steps: ClipSteps  # the walk clip against the sim's step clock (the gait's)
var _clip_feet := false  # a heavy body's feet follow the clip alone (D-201)
var _path: SwingPath  # a lifted foot's way to its clip path
var _lock: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var _lag: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
## The body's world yaw when each foot went down, and the turn (rad) its toes are held to: a planted
## foot keeps its world yaw while the body turns over it, and swings back to the clip's in the air.
var _plant_yaw: Array[float] = [0.0, 0.0]
var _yaw_fix: Array[float] = [0.0, 0.0]
var _was_planted: Array[bool] = [false, false]
var _hold: FootHold  # a planted foot's world yaw
var _ik: LegReach  # the leg solve, the body sunk so no knee pops
var _primed := false


## parts: [the gait's ClipStomp, its ClipSteps, whether its feet follow the clip alone].
func _init(p_gait: ClipGait, parts: Array) -> void:
	gait = p_gait
	_stomp = parts[0]
	_steps = parts[1]
	_clip_feet = parts[2]
	_path = SwingPath.new(_steps.swing_frames)
	_hold = FootHold.new(gait.rig)
	_ik = LegReach.new(gait)


## Planted feet hold their spot in the world; a lifted foot follows its clip path, starting from
## where it left the ground. The body sinks if a leg would lock straight, then the legs are
## re-solved to reach (two-bone IK, LegReach).
func plant(pose: KaijuClips.Pose, dt: float) -> void:
	var legs := gait.legs
	var targets: Array[Vector3] = []
	var fixes: Array[float] = []  # each foot's yaw: a planted one held, a lifted one easing back
	for i: int in mini(legs.size(), 2):
		gait.clip_planted[i] = pose.planted[i]
		targets.append(_foot_target(i, pose, dt))
		var held := wrapf(_plant_yaw[i] - _hold.rig_yaw(), -PI, PI)
		fixes.append(held if legs[i].planted else _yaw_fix[i] * exp(-FOOT_YAW_DECAY * dt))
	_ik.lower_body(gait, targets, fixes, dt)
	for i: int in targets.size():
		var planted := legs[i].planted
		_yaw_fix[i] = _hold.held(legs[i], gait.s, targets[i], fixes[i]) if planted else fixes[i]
		_ik.reach(gait, i, targets[i], _yaw_fix[i])
	_primed = true


## Where foot i's toe goes this frame (world), and whether it is down (leg.planted): a catch step,
## a planted foot's lock, or its path through the air.
func _foot_target(i: int, pose: KaijuClips.Pose, dt: float) -> Vector3:
	var leg := gait.legs[i]
	var clip_toe := gait.rig.global_transform * _stepped(gait.clips.to_rig(pose.feet[i]))
	var planted := pose.planted[i] and not _stomp.catching(i)
	if planted and _was_planted[i] and not _clip_feet and _overreached(leg, _lock[i], clip_toe):
		_stomp.restep(i)  # the body got away from this foot: step after it
		planted = false
	var target := clip_toe + _lag[i]
	if _stomp.catching(i):
		var k := _stomp.advance(i, dt)
		_lag[i] *= 1.0 - smoothstep(0.0, 1.0, k)
		target = clip_toe + _lag[i] + Vector3.UP * _stomp.rise(i, k) * gait.hip_height * gait.s
		if not _stomp.catching(i):  # on the street this frame: it plants now, not a frame on
			planted = pose.planted[i]
			target = _put_down(i, target, clip_toe) if planted else target
	elif planted:
		target = _put_down(i, target, clip_toe)
	else:
		target = _in_air(i, clip_toe, dt)
	leg.planted = planted
	_was_planted[i] = planted
	return target


## Foot i up: it leaves where it stood (lifting now) and follows its way back to its clip path at
## `clip_toe` (SwingPath; a heavy body's on the sim's way, D-208: its volume holds it there).
func _in_air(i: int, clip_toe: Vector3, dt: float) -> Vector3:
	_stomp.forget(i)
	if _was_planted[i]:
		_path.lift(i, gait.walk_frames, clip_toe, _lock[i])
	var target := _path.target(gait, i, dt, clip_toe)
	_lag[i] = _path.lag[i]
	var sim := gait.sim_feet()
	var air := sim.toe_air(i) if sim != null else Vector2.INF
	return Vector3(air.x, target.y, air.y) if air.x != INF else target


## A foot the clip has down: it locks where it lands, its footfall goes out; returns its spot.
func _put_down(i: int, target: Vector3, clip_toe: Vector3) -> Vector3:
	var leg := gait.legs[i]
	if not _was_planted[i]:
		_lock[i] = target
		_plant_yaw[i] = _hold.rig_yaw()
		leg.plant_at = target
		leg.drift = 0.0
		var strength := _stomp.landing(i, clampf(0.2 + gait.speed_k(), 0.0, 1.0), gait.s)
		if _primed:  # the first frame's feet were already down: no step, no ring
			gait.rig.foot_planted.emit("left" if leg.side < 0.0 else "right", strength, target)
	var sim := gait.sim_feet()
	if sim != null:  # where the sim put the foot down (D-208): its footprint is there
		var spot := sim.toe_lock(i)
		_lock[i] = Vector3(spot.x, clip_toe.y, spot.y) if spot.x != INF else _lock[i]
	if _clip_feet:  # the spot holds over the ground; its height rides the street (a rise, rubble)
		_lock[i].y = clip_toe.y
	_lag[i] = _lock[i] - clip_toe
	return _lock[i]


## A foot spot of the clip with its fore-aft travel shortened to the step the sim takes (a quick
## step in a turn is a short one, ClipSteps.shortened); a body that turns smoothly (the young
## croc, D-131) bends it onto the curve it walks (ClipSteps.curved: its wide-set planted feet
## stayed straight and were re-stepped every plant on a held curve, motion gate 2.2 a second).
func _stepped(toe: Vector3) -> Vector3:
	if gait.state != "walk" or _clip_feet:
		return toe
	if gait.step_phase == INF:  # a smooth turner (D-131) walks the curve its body turns
		return _steps.curved(toe, -gait.yaw_rate / maxf(gait.speed, 0.01) * gait.s)
	return _steps.shortened(toe, gait.step_ratio)


## True when a planted foot has been left too far behind (or ahead) of its clip spot to hold.
func _overreached(leg: BipedGait.Leg, lock: Vector3, clip_toe: Vector3) -> bool:
	if (lock - clip_toe).length() > RESTEP_GAP * gait.stride():
		return true
	var rig := gait.rig
	var hip := rig.bone(leg.names[0]).global_position
	var ankle := lock + (rig.bone(leg.names[2]).global_position - rig.tail_world(leg.names[2]))
	return (ankle - hip).length() > RESTEP_REACH * (leg.l1 + leg.l2) * gait.s
