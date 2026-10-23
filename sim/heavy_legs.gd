class_name HeavyLegs
extends RefCounted
## A heavy body's hind legs in its volume as the leg solve draws them (D-208; LegReach.reach):
## the thigh from the hip to a knee solved toward the ankle's target (two bones, the knee bending
## to the clip knee's side plus the rest side, LegSink.knee), the shin from that knee to the ankle;
## their slots turn with them. Part of HeavyFeet; pure, no randomness.

## The rest knee's side, in leg lengths, added to the clip knee's side (LegReach.POLE_REST).
const POLE_REST := 0.25

var _track: HeavyTrack
var _pose: HeavyPose
var _slots := 0
var _bones: Array[Vector3i] = []  # per leg: (thigh, shin, foot) bone


func _init(p_track: HeavyTrack, p_pose: HeavyPose, legs: Array[String]) -> void:
	_track = p_track
	_pose = p_pose
	_slots = _track.slot_bone.size()
	for leg: String in legs:
		var b := _track.bones
		_bones.append(Vector3i(b.find(leg + "0"), b.find(leg + "1"), b.find(leg + "2")))


## Leg i reaches `ankle` (rig axes: x across, y up, z back); `drop`: how far the body sank (its clip
## knee and ankle went down with it before the solve).
func reach(pose: PackedFloat32Array, i: int, ankle: Vector3, drop: float) -> void:
	var leg := _bones[i]
	var hip := _head(pose, leg.x)
	var knee_was := _head(pose, leg.y)
	var ankle_was := _head(pose, leg.z) + Vector3.DOWN * drop
	var parts: Vector2 = _track.leg_parts[i]
	var rest: Vector3 = _track.leg_poles[i]
	var pole := knee_was - (hip + ankle_was) * 0.5 + rest * POLE_REST * (parts.x + parts.y)
	var knee := LegSink.knee(hip, ankle, parts, pole)
	_turn(pose, leg.x, [hip, knee_was - hip, knee - hip, hip])
	_turn(pose, leg.y, [knee_was, ankle_was - knee_was, ankle - knee, knee])
	_set_head(pose, leg.y, knee)


## Turns bone b's slots and head about `at[0]` from direction at[1] onto at[2], moving it to at[3].
func _turn(pose: PackedFloat32Array, b: int, at: Array) -> void:
	var from: Vector3 = at[0]
	var was: Vector3 = at[1]
	var now: Vector3 = at[2]
	var to: Vector3 = at[3]
	if was.length() < 0.0001 or now.length() < 0.0001:
		return
	var turn := Quaternion(was.normalized(), now.normalized())
	for j: int in _pose.slots_of(_track.bones[b]):
		var k := j * HeavyTrack.SLOT
		var e := HeavyPose.ends(pose, k)
		HeavyPose.put_ends(pose, k, to + turn * (e[0] - from), to + turn * (e[1] - from))


func _head(pose: PackedFloat32Array, b: int) -> Vector3:
	var k := _slots * HeavyTrack.SLOT + b * 3
	return Vector3(pose[k + 1], pose[k + 2], -pose[k])


func _set_head(pose: PackedFloat32Array, b: int, at: Vector3) -> void:
	var k := _slots * HeavyTrack.SLOT + b * 3
	pose[k] = -at.z
	pose[k + 1] = at.x
	pose[k + 2] = at.y
