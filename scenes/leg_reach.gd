class_name LegReach
extends RefCounted
## ClipGait's leg solve (two-bone IK) without knee pops (motion gate, D-177; director 2026-10-23:
## "his legs so twitchy"). A leg near full stretch pops: the knee's bend snaps and its side flips,
## because the clip's near-straight knee gives the solve no side to bend to. So the body sinks
## (its root bone) just enough that no leg reaches past REACH_MAX of its length (eased in over
## SINK_SECONDS, back up over RISE_SECONDS), and the knee always bends toward its rest side (a
## pole that never vanishes).
## Presentation only.

## The furthest any leg reaches (share of its length), and the most the body may sink for it
## (hip heights).
const REACH_MAX := 0.92
const SINK_MAX := 0.12
## How fast the body sinks, and rises back to the clip's pose (s, exponential eases): a heel strike
## that sank it at once jolted the legs (shin jerk 7.5 deg/frame^2 at the other foot's plant).
const SINK_SECONDS := 0.04
const RISE_SECONDS := 0.12
## The rest knee's side, in leg lengths, added to the clip knee's side: it decides the bend only
## when the clip's knee is near straight.
const POLE_REST := 0.25

## How far the body is sunk now (world units; for tests and captures).
var sink := 0.0
var _rig: KaijuRig
var _root := ""
var _rest_pole: Array[Vector3] = []  # each leg's knee side at rest (rig space, unit)


func _init(gait: BipedGait) -> void:
	_rig = gait.rig
	_root = _rig.bone_names()[0]
	for leg: BipedGait.Leg in gait.legs:
		var hip := _rig.head_of(leg.names[0])
		var knee := _rig.head_of(leg.names[1])
		var line := (_rig.head_of(leg.names[2]) - hip).normalized()
		var side := (knee - hip) - line * (knee - hip).dot(line)
		_rest_pole.append(side.normalized() if side.length() > 0.0001 else Vector3.FORWARD)


## Sinks gait's body so no leg reaches past REACH_MAX toward its toe target (world) with its foot
## turned by its yaw (rad, ClipGait's hold), or rises back.
## (The gait is passed in, not kept: it owns this, and a kept one would be a reference cycle.)
func lower_body(gait: BipedGait, toes: Array[Vector3], yaws: Array[float], dt: float) -> void:
	var s := gait.s
	var need := 0.0
	for i: int in toes.size():
		var leg: BipedGait.Leg = gait.legs[i]
		var foot := _rig.bone(leg.names[2])
		var toe_off := _rig.tail_world(leg.tip) - foot.global_position
		var ankle := toes[i] - Basis(Vector3.UP, yaws[i]) * toe_off  # the foot turned as it will be
		var hip := _rig.bone(leg.names[0]).global_position
		var most := REACH_MAX * (leg.l1 + leg.l2) * s
		var flat := Vector2(ankle.x - hip.x, ankle.z - hip.z).length()
		var drop := hip.y - ankle.y
		if Vector2(flat, drop).length() > most:
			need = maxf(need, drop - sqrt(maxf(0.0, most * most - flat * flat)))
	need = clampf(need, 0.0, SINK_MAX * gait.hip_height * s)
	var ease := SINK_SECONDS if need > sink else RISE_SECONDS
	sink = lerpf(sink, need, 1.0 - exp(-dt / ease))
	var root := _rig.bone(_root)
	root.global_position -= Vector3.UP * sink


## Puts the toe at `toe` (two-bone IK) with the foot turned about the world's up by `yaw_fix`; the
## knee bends to the clip knee's side, or its rest side when the clip's knee is straight.
func reach(gait: BipedGait, i: int, toe: Vector3, yaw_fix: float) -> void:
	var leg: BipedGait.Leg = gait.legs[i]
	var s := gait.s
	var foot := _rig.bone(leg.names[2])
	var ankle_now := foot.global_position
	var foot_basis := Basis(Vector3.UP, yaw_fix) * foot.global_transform.basis.orthonormalized()
	var turned := Basis(Vector3.UP, yaw_fix) * (_rig.tail_world(leg.tip) - ankle_now)
	var ankle := toe - turned  # the toe stays on `toe` as the foot turns about the ankle
	if (ankle - ankle_now).length() < 0.0001 * s:
		_rig.set_world_basis(leg.names[2], foot_basis)
		return
	var hip := _rig.bone(leg.names[0]).global_position
	var knee_now := _rig.bone(leg.names[1]).global_position
	var rest := _rig.global_transform.basis.orthonormalized() * _rest_pole[i]
	var pole := knee_now - (hip + ankle_now) * 0.5 + rest * POLE_REST * (leg.l1 + leg.l2) * s
	var knee := KaijuGait.solve_knee(hip, ankle, leg.l1 * s, leg.l2 * s, pole)
	_rig.aim(leg.names[0], hip, knee)
	_rig.aim(leg.names[1], knee, ankle)
	_rig.set_world_basis(leg.names[2], foot_basis)
