class_name CameraBubble
extends RefCounted
## The cut-away bubble round the camera (director 2026-10-26, replaces the screen-door fade of
## D-025 for buildings and vehicles): everything of a building or vehicle nearer the camera than
## the radius is not drawn, in every direction, with a hard edge. The kaiju is never in the
## bubble's shaders. The radius is camera.bubble_share of the camera-to-kaiju distance, so it
## scales with zoom and growth; it eases over camera.fade_seconds when that changes, so nothing
## pops in or out. The shaders read it as the global `bubble_radius` (voxel.gdshader,
## building_baked.gdshader). Presentation only.

var _cfg: Dictionary = Content.section("camera")
var _radius := -1.0  # -1 until the first frame: it starts at its size, no ease from nothing


## The radius for a camera `distance` from the kaiju.
static func target(distance: float) -> float:
	return distance * Num.f(Content.section("camera")["bubble_share"])


## Whether a point is cut away by a bubble of `radius` round `eye` (the shaders' test).
static func hides(point: Vector3, eye: Vector3, radius: float) -> bool:
	return point.distance_to(eye) < radius


## The radius now (tests read it).
func radius() -> float:
	return maxf(_radius, 0.0)


## Eases the radius toward the size for the camera at `eye` and the kaiju at `kaiju_at`, and
## hands it to the shaders.
func update(eye: Vector3, kaiju_at: Vector3, delta: float) -> void:
	var want := target(eye.distance_to(kaiju_at))
	if _radius < 0.0:
		_radius = want
	else:  # the whole radius in fade_seconds at most
		_radius = move_toward(_radius, want, delta / Num.f(_cfg["fade_seconds"]) * want)
	RenderingServer.global_shader_parameter_set("bubble_radius", _radius)
