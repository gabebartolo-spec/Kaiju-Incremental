class_name HeavyFeet
extends RefCounted
## A heavy body's hind feet in its contact volume (D-208): a foot the clip has down holds where it
## came down, its toe and every slot of the foot (the leg solve holds the drawn foot there: ClipGait
## puts it down on toe_lock), turned no more as the body turns over it; and the body sinks as the
## leg solve sinks it (LegSink) so no leg overreaches. Part of HeavyContact; pure, no randomness.

const LEGS: Array[String] = ["leg_l", "leg_r"]  # the hind legs, as the clips' planted bits

## How far the body is sunk now (world units).
var sink := 0.0
var _track: HeavyTrack
var _pose: HeavyPose
var _slots := 0
var _locks: Array[Dictionary] = [{}, {}]  # per hind foot: slot -> its spot (world) while down
var _toes: Array[Vector2] = [Vector2.INF, Vector2.INF]
var _yaw_at: Array[float] = [0.0, 0.0]  # the body's yaw when each foot came down
var _hips: Array[int] = []  # per leg: its thigh's, shin's and foot's bone
var _shins: Array[int] = []
var _feet: Array[int] = []
var _lowered: Array[float] = []  # per bone: how much of the sink it takes (a foot none)
var _legs: HeavyLegs


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


## The world spot hind foot i's toe holds, INF while it is up.
func toe(i: int) -> Vector2:
	return _toes[i]


## Slot j's spot (world) while its foot is down, else INF.
func spot(j: int) -> Vector2:
	for lock: Dictionary in _locks:
		if lock.has(j):
			var at: Vector2 = lock[j]
			return at
	return Vector2.INF


## The feet down this step (bits: the clip's planted feet) lock or let go, then the body sinks.
## frame: [centre, the drawn body's way, body scale] of the pose (world).
func step(pose: PackedFloat32Array, bits: int, frame: Array, dt: float) -> void:
	var dir: Vector2 = frame[1]
	var yaw := atan2(-dir.x, -dir.y)
	for i: int in LEGS.size():
		if bits & (1 << i) == 0:
			_locks[i].clear()
			_toes[i] = Vector2.INF
		elif _toes[i].x == INF:
			_toes[i] = _world(pose, _pose.toe(i), frame)
			_yaw_at[i] = yaw
			for j: int in _pose.slots_of(_track.bones[_feet[i]]):
				_locks[i][j] = _world(pose, j * 5, frame)
	var s: float = frame[2]
	var need := 0.0
	for i: int in LEGS.size():
		need = maxf(need, _need(pose, i, frame, yaw))
	sink = LegSink.eased(sink, need, _track.hip_height * s, dt)
	_lower(pose, sink / s)
	for i: int in LEGS.size():  # the legs solved onto their feet, as LegReach.reach draws them
		_legs.reach(pose, i, _ankle(pose, i, frame, yaw), sink / s)


## The drop leg i needs (LegSink.need) with its toe on its spot, the foot turned as it is held.
func _need(pose: PackedFloat32Array, i: int, frame: Array, yaw: float) -> float:
	var s: float = frame[2]
	var dir: Vector2 = frame[1]
	var t := _pose.toe(i)
	var a := _slots * 5 + _feet[i] * 3
	var toe_at := _world(pose, t, frame) if _toes[i].x == INF else _toes[i]
	var off := Vector2(pose[t + 1] - pose[a + 1], pose[a] - pose[t])  # toe from ankle (x, z)
	off = off.rotated(-atan2(-dir.x, -dir.y)) * s  # into the world
	if _toes[i].x != INF:
		off = off.rotated(-(_yaw_at[i] - yaw))  # the planted foot keeps its world yaw
	var ankle := toe_at - off
	var hip_at := _world(pose, _slots * 5 + _hips[i] * 3, frame)
	var hip := Vector3(hip_at.x, pose[_slots * 5 + _hips[i] * 3 + 2] * s, hip_at.y)
	var ankle_y := pose[a + 2] * s
	return LegSink.need(hip, Vector3(ankle.x, ankle_y, ankle.y), _track.legs[i] * s)


## Where leg i's ankle goes (rig axes, x across, y up, z back): under a planted toe, the foot turned
## as it is held; the clip's ankle while the foot is up.
func _ankle(pose: PackedFloat32Array, i: int, frame: Array, yaw: float) -> Vector3:
	var a := _slots * 5 + _feet[i] * 3
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
		var k := j * 5
		var by := drop * _lowered[_track.slot_bone[j]]
		pose[k + 3] -= by
		pose[k + 4] -= by
	for b: int in _track.bones.size():
		pose[_slots * 5 + b * 3 + 2] -= drop * _lowered[b]


## Point k of the pose ([forward, across, ...] body space) in the world.
static func _world(pose: PackedFloat32Array, k: int, frame: Array) -> Vector2:
	var centre: Vector2 = frame[0]
	var dir: Vector2 = frame[1]
	var s: float = frame[2]
	return centre + (dir * pose[k] + Vector2(-dir.y, dir.x) * pose[k + 1]) * s
