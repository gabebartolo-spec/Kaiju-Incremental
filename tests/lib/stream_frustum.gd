extends RefCounted
## What the stream view test (stream_view.gd) sees through the camera's frustum: the stand-in
## boxes of the buildings and of the landmarks that are not meshed. Presentation only.

## Boxes farther than this never count.
const LOOK_M := 260.0

## The nearest box inside the frustum within 10 degrees of the view axis (last _nearest_box).
var ahead := 0.0
## Landmarks that were boxes on the last landmark_pops call, in view or not.
var unbuilt := 0

var _sim: RampageSim
var _stream: BuildingStream
var _camera: Camera3D
var _marks: Array[int]
var _inward := 0.0  # 1 when the frustum's planes face outward, -1 inward (found on first use)


func _init(sim: RampageSim, stream: BuildingStream, camera: Camera3D, marks: Array[int]) -> void:
	_sim = sim
	_stream = stream
	_camera = camera
	_marks = marks


## How many landmarks stand as a stand-in box whose bounding box meets the camera's frustum, at
## any distance: each one is a pop-in when it swaps for the building.
func landmark_pops() -> int:
	var planes := _camera.get_frustum()
	var pops := 0
	unbuilt = 0
	for n: int in _marks:
		if _stream.built(n) != null:
			continue
		unbuilt += 1
		var b := _sim.buildings[n]
		var box := AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, b.height, b.d))
		pops += 1 if _in_frustum(planes, box) else 0
	return pops


func landmark_chunks() -> int:
	var sum := 0
	for n: int in _marks:
		var b := _sim.buildings[n]
		sum += b.w * b.d * b.height
	return sum


## The distance from the camera to the nearest building still standing as a box whose
## bounding box meets the camera's frustum (LOOK_M when none within reach).
func nearest_box() -> float:
	var planes := _camera.get_frustum()
	var eye := _camera.global_position
	if _inward == 0.0:  # which way the planes face: a point ahead of the camera is inside
		var ahead := eye - _camera.global_transform.basis.z * 10.0
		_inward = 1.0 if (planes[2] as Plane).distance_to(ahead) < 0.0 else -1.0
	var best := LOOK_M
	var fwd := (
		Vector2(-_camera.global_transform.basis.z.x, -_camera.global_transform.basis.z.z)
		. normalized()
	)
	ahead = LOOK_M
	for n: int in _sim.buildings.size():
		if _stream.built(n) != null:
			continue
		var b := _sim.buildings[n]
		var box := AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, b.height, b.d))
		var near := Vector3(
			clampf(eye.x, box.position.x, box.end.x),
			clampf(eye.y, 0.0, b.height),
			clampf(eye.z, box.position.z, box.end.z)
		)
		var d := eye.distance_to(near)
		if d >= ahead and d >= best:
			continue
		if not _in_frustum(planes, box):
			continue
		var rel := Vector2(b.x - eye.x, b.z - eye.z)
		if absf(rel.angle_to(fwd)) < deg_to_rad(10.0):
			ahead = minf(ahead, d)
		if d < best:
			best = d
	return best


## Whether the box is not wholly outside one of the frustum's planes.
func _in_frustum(planes: Array[Plane], box: AABB) -> bool:
	for plane: Plane in planes:
		var out := true
		for i: int in 8:
			if plane.distance_to(box.get_endpoint(i)) * _inward <= 0.0:
				out = false
				break
		if out:
			return false
	return true
