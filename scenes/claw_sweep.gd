class_name ClawSweep
extends RefCounted
## The claw rake's slash for the camera (drawn by ClawTrail), fixed as the strike begins: from the
## cocked claw (its last visible spot), over the body across the snout line at the hit (an arm's
## reach ahead of the chest), out past the far flank. A quadratic curve in the rig's space through
## those three points, timed to the sim's hit; not sampled from the hand, which the body hides.
## "claw_fx" tuning: slash_rise, slash_ahead, slash_end_ahead, slash_drop, slash_far.

var tip_local := Vector3.ZERO  ## the claw now (rig space), kept by ClawRake each frame
var _rig: Node3D
var _cfg := Content.section("claw_fx")
var _path: Array[Vector3] = []  # start, control point, end (rig space)
var _hit := Vector3.ZERO  # where the curve crosses the snout line (rig space)


func _init(rig: Node3D) -> void:
	_rig = rig


func clear() -> void:
	_path = []


func is_set() -> bool:
	return _path.size() == 3


## Fixes the slash: `start` the cocked claw, from a shoulder at `shoulder` of an arm `reach` long,
## the raking arm on `side`.
func capture(start: Vector3, shoulder: Vector3, reach: float, side: float) -> void:
	var ahead := shoulder.z - Num.f(_cfg["slash_ahead"]) * reach
	_hit = Vector3(0.0, shoulder.y + Num.f(_cfg["slash_rise"]) * reach, ahead)
	var end := Vector3(
		-side * absf(start.x) * Num.f(_cfg["slash_far"]),
		start.y - Num.f(_cfg["slash_drop"]) * reach,
		shoulder.z - Num.f(_cfg["slash_end_ahead"]) * reach
	)
	_path = [start, _hit * 2.0 - (start + end) * 0.5, end]


## The curve's start, control point and end (world).
func path_world() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p: Vector3 in _path:
		out.append(_rig.global_transform * p)
	return out


## Where the curve crosses the snout line, and the claw now (world).
func hit_world() -> Vector3:
	return _rig.global_transform * _hit


func tip_world() -> Vector3:
	return _rig.global_transform * tip_local
