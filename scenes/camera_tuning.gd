class_name CameraTuning
extends RefCounted
## The gameplay camera's numbers (data/tuning.json "camera"), for Rampage, tests and captures: the
## rest offset from the kaiju's focus, the vertical FOV, and the zoom curve that backs the camera
## off as the body grows (research 19.1: it was hard-coded in Rampage._place_camera).


static func offset() -> Vector3:
	var o: Array = Content.section("camera")["offset"]
	return Vector3(Num.f(o[0]), Num.f(o[1]), Num.f(o[2]))


## `v` (an offset from the kaiju) swung round the kaiju by `turn` radians on the ground plane, the
## way CameraYaw counts it: the rest offset at his back (D-330).
static func turned(v: Vector3, turn: float) -> Vector3:
	var flat := Vector2(v.x, v.z).rotated(turn)
	return Vector3(flat.x, v.y, flat.y)


static func fov() -> float:
	return Num.f(Content.section("camera")["fov"])


## How far ahead of a body of `body_scale` the camera leads while it moves (units; camera A,
## D-121: 3 at the hatchling, 7.5 at the adult).
static func lead(body_scale: float) -> float:
	var cam: Dictionary = Content.section("camera")
	return Num.f(cam["lead_base"]) + Num.f(cam["lead_per_scale"]) * body_scale


## The factor the rest offset is multiplied by for a body of `body_scale`.
static func zoom(body_scale: float) -> float:
	var cam: Dictionary = Content.section("camera")
	return Num.f(cam["zoom_base"]) + Num.f(cam["zoom_per_scale"]) * body_scale
