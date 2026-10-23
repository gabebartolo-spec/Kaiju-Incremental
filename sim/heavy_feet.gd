class_name HeavyFeet
extends RefCounted
## A heavy body's hind feet in its contact volume (D-208): a foot the clip has down holds where it
## came down, its toe and every slot of the foot (the leg solve holds the drawn foot there: ClipGait
## puts it down on toe_lock), turned no more as the body turns over it; a lifted foot swings from
## there back to its clip path (FootSwing; ClipGait draws the foot on toe_air); and the body sinks
## as the leg solve sinks it (LegSink) so no leg overreaches. Part of HeavyContact; pure.

const LEGS: Array[String] = ["leg_l", "leg_r"]  # the hind legs, as the clips' planted bits
const S := HeavyTrack.SLOT

## How far the body is sunk now (world units).
var sink := 0.0
var _track: HeavyTrack
var _pose: HeavyPose
var _slots := 0
var _locks: Array[Dictionary] = [{}, {}]  # per hind foot: slot -> its ends' spots while down
var _toes: Array[Vector2] = [Vector2.INF, Vector2.INF]
var _yaw_at: Array[float] = [0.0, 0.0]  # the body's yaw when each foot came down
var _hips: Array[int] = []  # per leg: its thigh's, shin's and foot's bone
var _shins: Array[int] = []
var _feet: Array[int] = []
var _lowered: Array[float] = []  # per bone: how much of the sink it takes (a foot none)
var _legs: HeavyLegs
var _swing: FootSwing
var _air: Array[Vector2] = [Vector2.INF, Vector2.INF]  # a lifted toe's spot (world)
var _walked := 0.0  # walk clip frames played (ClipGait.walk_frames)
var _walk_was := -1.0  # the walk clip's frame last step, < 0 when it did not play
var _walking := false


func _init(p_track: HeavyTrack, p_pose: HeavyPose) -> void:
	_track = p_track
	_pose = p_pose
	_slots = _track.slot_bone.size()
	for leg: String in LEGS:
		_hips.append(_track.bones.find(leg + "0"))
		_shins.append(_track.bones.find(leg + "1"))
		_feet.append(_track.bones.find(leg + "2"))
	for b: int in _track.bones.size():
		_lowered.append(0.0 if b in _feet else 1.0)
	_legs = HeavyLegs.new(_track, _pose, LEGS)
	_swing = FootSwing.new(_track.swing_frames)


## The world spot hind foot i's toe holds, INF while it is up.
func toe(i: int) -> Vector2:
	return _toes[i]


## Where lifted hind foot i's toe is in the world (on its way back to its clip path), INF while
## it is down.
func toe_air(i: int) -> Vector2:
	return _air[i]


## The clip clock this step: the walk clip frames played (as ClipGait counts them).
func walk(clock: ClipClock) -> void:
	_walking = clock.state == "walk"
	if _walking and _walk_was >= 0.0:
		_walked += fposmod(clock.time - _walk_was, float(_track.frames_of("walk")))
	_walk_was = clock.time if _walking else -1.0


## Slot j's ends' spots (world: bottom x, z, top x, z) while its foot is down, else x INF.
func spot(j: int) -> Vector4:
	for lock: Dictionary in _locks:
		if lock.has(j):
			var at: Vector4 = lock[j]
			return at
	return Vector4(INF, INF, INF, INF)


## The feet down this step (bits: the clip's planted feet) lock or let go, then the body sinks.
## frame: [centre, the drawn body's way, body scale] of the pose (world).
func step(pose: PackedFloat32Array, bits: int, frame: Array, dt: float) -> void:
	var dir: Vector2 = frame[1]
	var yaw := atan2(-dir.x, -dir.y)
	for i: int in LEGS.size():
		if bits & (1 << i) == 0:
			_lifted(pose, i, frame, dt)
		elif _toes[i].x == INF:
			_air[i] = Vector2.INF
			_toes[i] = _world(pose, _pose.toe(i), frame)
			_yaw_at[i] = yaw
			for j: int in _pose.slots_of(_track.bones[_feet[i]]):
				var lo := _world(pose, j * S, frame)
				var hi := _world(pose, j * S + 5, frame)
				_locks[i][j] = Vector4(lo.x, lo.y, hi.x, hi.y)
	var s: float = frame[2]
	var need := 0.0
	for i: int in LEGS.size():
		need = maxf(need, _need(pose, i, frame, yaw))
	sink = LegSink.eased(sink, need, _track.hip_height * s, dt)
	_lower(pose, sink / s)
	for i: int in LEGS.size():  # the legs solved onto their feet, as LegReach.reach draws them
		_legs.reach(pose, i, _ankle(pose, i, frame, yaw), sink / s)


## Hind foot i is up: it lets go of its spot (lifting now) and swings back to its clip path
## (FootSwing): its toe, ankle and slots are carried by the way it still has to go.
func _lifted(pose: PackedFloat32Array, i: int, frame: Array, dt: float) -> void:
	var s: float = frame[2]
	var dir: Vector2 = frame[1]
	var toe := _world(pose, _pose.toe(i), frame)
	var clip_toe := Vector3(toe.x, 0.0, toe.y)
	if _toes[i].x != INF:
		_swing.lift(i, _walked, clip_toe, Vector3(_toes[i].x, 0.0, _toes[i].y))
		_locks[i].clear()
		_toes[i] = Vector2.INF
	_swing.lag_at(i, dt, clip_toe, [_walked, _walking, _track.stride * s])
	var lag := Vector2(_swing.lag[i].x, _swing.lag[i].z)
	_air[i] = toe + lag
	var by := Vector2(lag.dot(dir), lag.dot(Vector2(-dir.y, dir.x))) / s  # body space
	var at: Array[int] = [_pose.toe(i), _slots * S + _feet[i] * 3]
	for j: int in _pose.slots_of(_track.bones[_feet[i]]):
		at.append_array([j * S, j * S + 5])
	for k: int in at:
		pose[k] += by.x
		pose[k + 1] += by.y


## The drop leg i needs (LegSink.need) with its toe on its spot, the foot turned as it is held.
func _need(pose: PackedFloat32Array, i: int, frame: Array, yaw: float) -> float:
	var s: float = frame[2]
	var dir: Vector2 = frame[1]
	var t := _pose.toe(i)
	var a := _slots * S + _feet[i] * 3
	var toe_at := _world(pose, t, frame) if _toes[i].x == INF else _toes[i]
	var off := Vector2(pose[t + 1] - pose[a + 1], pose[a] - pose[t])  # toe from ankle (x, z)
	off = off.rotated(-atan2(-dir.x, -dir.y)) * s  # into the world
	if _toes[i].x != INF:
		off = off.rotated(-(_yaw_at[i] - yaw))  # the planted foot keeps its world yaw
	var ankle := toe_at - off
	var hip_at := _world(pose, _slots * S + _hips[i] * 3, frame)
	var hip := Vector3(hip_at.x, pose[_slots * S + _hips[i] * 3 + 2] * s, hip_at.y)
	var ankle_y := pose[a + 2] * s
	return LegSink.need(hip, Vector3(ankle.x, ankle_y, ankle.y), _track.legs[i] * s)


## Where leg i's ankle goes (rig axes, x across, y up, z back): under a planted toe, the foot turned
## as it is held; the clip's ankle while the foot is up.
func _ankle(pose: PackedFloat32Array, i: int, frame: Array, yaw: float) -> Vector3:
	var a := _slots * S + _feet[i] * 3
	var ankle := Vector3(pose[a + 1], pose[a + 2], -pose[a])
	if _toes[i].x == INF:
		return ankle
	var t := _pose.toe(i)
	var off := Vector2(pose[t + 1] - pose[a + 1], pose[a] - pose[t]).rotated(-(_yaw_at[i] - yaw))
	var centre: Vector2 = frame[0]
	var dir: Vector2 = frame[1]
	var s: float = frame[2]
	var rel := (_toes[i] - centre) / s
	var toe := Vector2(rel.dot(Vector2(-dir.y, dir.x)), -rel.dot(dir))  # (x across, z back)
	return Vector3(toe.x - off.x, ankle.y, toe.y - off.y)


## Lowers every slot and bone head by `drop` (body scale 1) as the root goes down: the feet stay
## on their spots (the leg solve then reaches them).
func _lower(pose: PackedFloat32Array, drop: float) -> void:
	if drop <= 0.0:
		return
	for j: int in _slots:
		var k := j * S
		var by := drop * _lowered[_track.slot_bone[j]]
		pose[k + 3] -= by
		pose[k + 4] -= by
	for b: int in _track.bones.size():
		pose[_slots * S + b * 3 + 2] -= drop * _lowered[b]


## Point k of the pose ([forward, across, ...] body space) in the world.
static func _world(pose: PackedFloat32Array, k: int, frame: Array) -> Vector2:
	var centre: Vector2 = frame[0]
	var dir: Vector2 = frame[1]
	var s: float = frame[2]
	return centre + (dir * pose[k] + Vector2(-dir.y, dir.x) * pose[k + 1]) * s
