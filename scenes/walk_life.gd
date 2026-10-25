class_name WalkLife
extends RefCounted
## A walk kept alive on a rig that holds its arms in one pose (the young croc, director
## 2026-10-25): the arms swing a little with each step, each forward as the opposite foot comes
## forward, and the head dips a few cm just after each footfall (D-243). From rig.json "walk_life":
## "arm_swing_deg" (each way, from the shoulder) and "head_bob" (the snout's dip, a share of hip
## height). Driven by the walk clip's step clock (ClipSteps); eases in and out with the walk.
## Presentation only.

## Seconds to ease the swing and bob in as a walk starts, or out as it stops.
const EASE_S := 0.3
## The head's dip comes this share of a step after the footfall (the neck carries the jolt late).
const BOB_LAG := 0.15

var arm_rad := 0.0
var bob := 0.0
var dip := 0.0  # how far (world units) the nod drops the snout this frame
var _steps: ClipSteps
var _left_leads := true  # the left foot lands at step 0
var _weight := 0.0
var _phase := 0.0  # steps since the walk clip's first footfall


func _init(spec: Dictionary, steps: ClipSteps) -> void:
	arm_rad = deg_to_rad(Num.f(spec.get("arm_swing_deg", 0.0)))
	bob = Num.f(spec.get("head_bob", 0.0))
	_steps = steps
	var feet := steps.clips.pose_at("walk", steps.land).feet
	_left_leads = feet[0].z < feet[1].z  # the landing foot is the one ahead (forward is -z)


func tick(dt: float, walking: bool, walk_frame: float) -> void:
	_weight = move_toward(_weight, 1.0 if walking else 0.0, dt / EASE_S)
	if walking:
		_phase = (walk_frame - _steps.land) / _steps.step_frames


## An arm's held directions (heading frame, x outward, -z forward) swung about the shoulder: forward
## while the foot on the other side is ahead.
func swung(held: Array[Vector3], left: bool) -> Array[Vector3]:
	if arm_rad <= 0.0 or _weight <= 0.0:
		return held
	var left_ahead := cos(PI * _phase) * (1.0 if _left_leads else -1.0)
	var turn := Basis(Vector3.RIGHT, arm_rad * _weight * (-left_ahead if left else left_ahead))
	var out: Array[Vector3] = []
	for d: Vector3 in held:
		out.append(turn * d)
	return out


## Dips the neck so the snout drops head_bob of the hip height just after each footfall.
func nod(rig: KaijuRig, hip: float) -> void:
	if bob <= 0.0 or _weight <= 0.0 or not rig.has_bone("head0") or not rig.has_bone("head1"):
		return
	var root := rig.bone("head0").global_position
	var reach := (rig.tail_world("head1") - root).length()
	dip = bob * hip * _weight * (0.5 + 0.5 * cos(TAU * (_phase - BOB_LAG)))
	var b := rig.bone("head0").global_transform.basis.orthonormalized()
	var right := rig.global_transform.basis.x.normalized()
	rig.set_world_basis("head0", Basis(right, -dip / maxf(reach, 0.001)) * b)
