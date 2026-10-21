class_name CameraTuning
extends RefCounted
## The gameplay camera's numbers (data/tuning.json "camera"), for Rampage, tests and captures: the
## rest offset from the kaiju's focus, the vertical FOV, and the zoom curve that backs the camera
## off as the body grows (research 19.1: it was hard-coded in Rampage._place_camera).


static func offset() -> Vector3:
	var o: Array = Content.section("camera")["offset"]
	return Vector3(Num.f(o[0]), Num.f(o[1]), Num.f(o[2]))


static func fov() -> float:
	return Num.f(Content.section("camera")["fov"])


## The factor the rest offset is multiplied by for a body of `body_scale`.
static func zoom(body_scale: float) -> float:
	var cam: Dictionary = Content.section("camera")
	return Num.f(cam["zoom_base"]) + Num.f(cam["zoom_per_scale"]) * body_scale
