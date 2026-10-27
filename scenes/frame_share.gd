class_name FrameShare
extends RefCounted
## How much of the screen a box covers from the camera: the frame-filling test behind the building
## fade (D-326: only a wall that fills the frame at the camera is handled, every other building
## draws solid and may hide the kaiju; D-283's pass bar: "no wall fills the frame"). Presentation
## only: it reads the camera and a building's box and changes nothing.
##
## The box's eight corners go to camera space, an edge that crosses the near plane is cut there,
## what stays in front is projected onto the screen (-1..1 each way) and the share is the area of
## that outline's convex hull inside the screen, over the screen's area. The eye inside the box is
## a whole screen.

const SCREEN := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
const SCREEN_AREA := 4.0
## A corner a hair past the near plane projects far off the screen: kept within this many screens
## of the middle so the clipper's integer maths stays in range.
const REACH := 1000.0
## The three box edges leaving a corner (AABB.get_endpoint numbers its corners by these bits).
const BITS := [1, 2, 4]

var _eye: Vector3
var _to_camera: Transform3D
var _tan_v: float
var _aspect: float
var _near: float


## `camera`: where it is (world), `tan_v`: the tangent of half its vertical field of view,
## `aspect`: the viewport's width over its height, `near`: its near plane.
func _init(camera: Transform3D, tan_v: float, aspect: float, near := 0.05) -> void:
	_eye = camera.origin
	_to_camera = camera.affine_inverse()
	_tan_v = tan_v
	_aspect = aspect
	_near = near


## The frame of a live `camera` drawing a viewport of `size` pixels.
static func of(camera: Camera3D, size: Vector2) -> FrameShare:
	var aspect := size.x / maxf(size.y, 1.0)
	var half := tan(deg_to_rad(camera.fov * 0.5))
	if camera.keep_aspect == Camera3D.KEEP_WIDTH:  # the fov is the horizontal one
		half /= aspect
	return FrameShare.new(camera.global_transform, half, aspect, camera.near)


## The frame of a camera at `eye` looking at `at` (vertical fov in degrees), for tests.
static func looking(eye: Vector3, at: Vector3, fov: float, aspect: float) -> FrameShare:
	var basis := Basis.looking_at(at - eye, Vector3.UP)
	return FrameShare.new(Transform3D(basis, eye), tan(deg_to_rad(fov * 0.5)), aspect)


func eye() -> Vector3:
	return _eye


## The share (0..1) of the screen `box` (world space) covers.
func share_of(box: AABB) -> float:
	if box.has_point(_eye):
		return 1.0
	var corner: Array[Vector3] = []
	for i: int in 8:
		corner.append(_to_camera * box.get_endpoint(i))
	var seen := PackedVector2Array()
	for c: Vector3 in corner:
		if _in_front(c):
			seen.append(_project(c))
	for i: int in 8:
		for bit: int in BITS:
			if i & bit != 0:
				continue
			var a := corner[i]
			var b := corner[i | bit]
			if _in_front(a) != _in_front(b):  # cut at the near plane
				seen.append(_project(a.lerp(b, (-_near - a.z) / (b.z - a.z))))
	if seen.size() < 3:
		return 0.0
	var hull := Geometry2D.convex_hull(seen)
	if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
		hull.remove_at(hull.size() - 1)  # the hull comes back closed
	var area := 0.0
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(hull, PackedVector2Array(SCREEN)):
		area += _area(poly)
	return clampf(area / SCREEN_AREA, 0.0, 1.0)


func _in_front(c: Vector3) -> bool:
	return c.z <= -_near


func _project(c: Vector3) -> Vector2:
	var depth := -c.z * _tan_v
	var p := Vector2(c.x / (depth * _aspect), c.y / depth)
	return Vector2(clampf(p.x, -REACH, REACH), clampf(p.y, -REACH, REACH))


## The area of a simple polygon (shoelace).
static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i: int in poly.size():
		sum += poly[i].cross(poly[(i + 1) % poly.size()])
	return absf(sum) * 0.5
