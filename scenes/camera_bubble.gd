class_name CameraBubble
extends RefCounted
## The camera bubble (D-283, D-326): buildings stay solid. Only the standing buildings between
## the camera and the kaiju, at most camera.bubble_max of them (the nearest the camera first),
## are cut away inside a sphere round the camera, with a hard edge, their shadows kept
## (building_baked.gdshader). Nothing else is ever cut: a falling, toppling or broken piece, the
## rubble, every vehicle and the kaiju always draw whole, and may hide him ("its ok to obscure
## the kaiju, its not ok to block the camera", D-326; vehicles D-290). No screen door anywhere.
##
## A building is on the line when it stands in a sight line from the camera to the kaiju's body
## (sight_of: points up his height and ahead along his facing, at his body's width each side), or
## the camera is inside it; a carved stump below every line is not. The sphere's radius is
## camera.bubble_share of the camera-to-kaiju distance, so it scales with zoom and growth; it
## eases over camera.bubble_seconds as that changes, and each building's cut opens from the camera
## outward and closes back over the same time, so nothing pops (the run's first frame starts
## open). The shaders read the global `bubble_radius`, each building its own `bubble_cut`.
## Only the buildings whose footprint meets the rectangle the sight lines stay in are tested (a
## grid of footprints, built once: the walls never move). Presentation only.

## Heights up the kaiju's body (shares of its height: the feet, the pelvis, the torso, the head)
## and steps forward along its facing (in body radii) that are in the line (R 19.4).
const HEIGHTS: Array[float] = [0.03, 0.3, 0.6, 0.9]
const AHEAD: Array[float] = [0.0, 1.0, 2.0]
## Side of a grid cell of the footprint index (metres).
const CELL := 32.0

var _cfg: Dictionary = Content.section("camera")
var _buildings: Array[RampageSim.Building]
var _views: Callable
var _radius := -1.0  # -1 until the first frame: it starts at its size, no ease from nothing
var _open := {}  # building index -> its cut, 0 whole .. 1 the whole radius (only those above 0)
var _grid := {}  # Vector2i cell -> PackedInt32Array of the buildings whose footprint meets it


## views: building index -> its BuildingView, or null while it is not built yet.
func _init(buildings: Array[RampageSim.Building], views: Callable) -> void:
	_buildings = buildings
	_views = views
	_index()


## The radius for a camera `distance` from the kaiju.
static func target(distance: float) -> float:
	return distance * Num.f(Content.section("camera")["bubble_share"])


## Whether a point of a cut building is cut away by a bubble of `radius` round `eye` (the
## shaders' test, at a full cut).
static func hides(point: Vector3, eye: Vector3, radius: float) -> bool:
	return point.distance_to(eye) < radius


## The radius now (tests read it).
func radius() -> float:
	return maxf(_radius, 0.0)


## Building n's cut now (0 = drawn whole; tests read it).
func cut(n: int) -> float:
	return Num.f(_open.get(n, 0.0))


## One frame: eases the radius toward its size for the camera at `eye` and the kaiju's `focus`,
## picks the buildings on the line to the `sight` points and eases each one's cut.
func update(eye: Vector3, focus: Vector3, sight: PackedVector3Array, delta: float) -> void:
	var want := target(eye.distance_to(focus))
	var first := _radius < 0.0
	if first:
		_radius = want
	else:  # the whole radius in bubble_seconds at most
		_radius = move_toward(_radius, want, delta / Num.f(_cfg["bubble_seconds"]) * want)
	RenderingServer.global_shader_parameter_set("bubble_radius", _radius)
	var step := delta / Num.f(_cfg["bubble_seconds"])
	var on := {}
	for n: int in picked(eye, sight):
		on[n] = true
		if not _open.has(n):
			_open[n] = 1.0 if first else 0.0
	for n: int in _open.keys():
		var next := move_toward(Num.f(_open[n]), 1.0 if on.has(n) else 0.0, step)
		var view: BuildingView = _views.call(n)
		if view != null:  # every frame while it is cut: a view streamed in late gets it too
			view.set_near_camera(next > 0.0, next)
		if next <= 0.0:
			_open.erase(n)
		else:
			_open[n] = next


## The buildings on the line from the eye to the sight points (see blocks), the nearest the eye
## first, at most camera.bubble_max of them.
func picked(eye: Vector3, sight: PackedVector3Array) -> PackedInt32Array:
	var found: Array[Vector2] = []  # (distance from the eye, building index)
	for n: int in _near(eye, sight):
		var b := _buildings[n]
		if blocks(eye, sight, b):
			var box := _box(b, standing_top(b))
			found.append(Vector2(eye.distance_to(eye.clamp(box.position, box.end)), n))
	found.sort()
	var out := PackedInt32Array()
	for f: Vector2 in found.slice(0, Num.i(_cfg["bubble_max"])):
		out.append(int(f.y))
	return out


## The points over a kaiju standing at `feet`, `height` tall, facing `ahead` (one body radius
## long, ground plane). Under water (the rise from the river, comment #27) only the part above
## `surface` counts, so the heights spread over that part.
static func targets(
	feet: Vector3, height: float, ahead: Vector3, surface := -INF
) -> PackedVector3Array:
	var top := feet.y + height
	var base := clampf(surface, feet.y, top)
	var out := PackedVector3Array()
	for share: float in HEIGHTS:
		for steps: float in AHEAD:
			out.append(Vector3(feet.x, lerpf(base, top, share), feet.z) + ahead * steps)
	return out


## The sight points of the sim's kaiju now (CityView picks by them; the tests replay them).
## With the `eye`, each point also gets one each side of it, across the line of sight, at
## camera.bubble_width body radii, so a tower over his flank on screen is on the line too.
static func sight_of(sim: RampageSim, eye := Vector3.INF) -> PackedVector3Array:
	var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var reach := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var ahead := Vector3(sim.facing.x, 0, sim.facing.y) * reach
	var surface := -Num.f(sim.city.get("river_depth", 0.0))
	var out := targets(feet, sim.reach_height(), ahead, surface)
	if eye == Vector3.INF:
		return out
	var half := reach * Num.f(Content.section("camera")["bubble_width"])
	var across := Vector3(feet.z - eye.z, 0.0, eye.x - feet.x).normalized() * half
	for n: int in out.size():
		out.append(out[n] + across)
		out.append(out[n] - across)
	return out


## Whether building b stands in a sight line from the eye to any of the kaiju's points, or the
## eye is inside it (a tower the camera sits in, never a frame-filling wall). The box is the
## building as it stands now: a carved stump below every sight line is not on the line.
static func blocks(eye: Vector3, sight: PackedVector3Array, b: RampageSim.Building) -> bool:
	if not _cuts(eye, sight, b, b.height):
		return false  # the cheap test on the whole box first
	var top := standing_top(b)
	return top > 0 and _cuts(eye, sight, b, top)


## The building's standing height now (floors): one above its highest standing chunk, 0 when
## razed; its full height when it has no chunk frame.
static func standing_top(b: RampageSim.Building) -> int:
	if b.frame == null:
		return b.height
	var top := -1
	for z: int in b.frame.d:
		for x: int in b.frame.w:
			top = maxi(top, b.frame.top_below(x, z, b.frame.h))
	return top + 1


static func _box(b: RampageSim.Building, top: int) -> AABB:
	return AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, top, b.d))


static func _cuts(
	eye: Vector3, sight: PackedVector3Array, b: RampageSim.Building, top: int
) -> bool:
	var box := _box(b, top)
	if box.has_point(eye):
		return true
	for at: Vector3 in sight:
		if box.has_point(at):
			continue  # that point of the body is inside the building (wading through it)
		if box.intersects_segment(eye, at) != null:
			return true
	return false


## The buildings whose footprint meets the ground rectangle the sight lines stay inside (eye to
## kaiju's points), each once, in building order.
func _near(eye: Vector3, sight: PackedVector3Array) -> PackedInt32Array:
	var lo := Vector2(eye.x, eye.z)
	var hi := lo
	for p: Vector3 in sight:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var found := PackedInt32Array()
	var first := Vector2i((lo / CELL).floor())
	var last := Vector2i((hi / CELL).floor())
	for cx: int in range(first.x, last.x + 1):
		for cz: int in range(first.y, last.y + 1):
			found.append_array(_grid.get(Vector2i(cx, cz), PackedInt32Array()))
	found.sort()
	var out := PackedInt32Array()
	var prev := -1
	for n: int in found:
		if n == prev:
			continue  # a footprint spanning several cells is listed in each
		prev = n
		var b := _buildings[n]
		# Cheap reject: the sight lines stay inside the eye-to-kaiju rectangle on the ground.
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		out.append(n)
	return out


## Lists each building under every grid cell its footprint touches.
func _index() -> void:
	for n: int in _buildings.size():
		var b := _buildings[n]
		var first := Vector2i((Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5) / CELL).floor())
		var last := Vector2i((Vector2(b.x + b.w * 0.5, b.z + b.d * 0.5) / CELL).floor())
		for cx: int in range(first.x, last.x + 1):
			for cz: int in range(first.y, last.y + 1):
				var key := Vector2i(cx, cz)
				var cell: PackedInt32Array = _grid.get(key, PackedInt32Array())
				cell.append(n)
				_grid[key] = cell
