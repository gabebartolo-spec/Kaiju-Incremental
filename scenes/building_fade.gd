class_name BuildingFade
extends RefCounted
## A building between the camera and the kaiju's body fades to a screen door, as vehicles do
## (D-025's rule, VehicleFade), so a grown kaiju among towers its own height is always seen.
## Each frame, the sight lines from the camera to points over the kaiju's body (up its height
## and forward along its facing, where the torso and head are) are tested against every built
## building's box; one that cuts a line eases down to vehicles.fade_opacity, the rest ease
## back. The camera never moves for it. Presentation only.
##
## Only the buildings whose footprint meets the rectangle the sight lines stay in are tested
## (a grid of footprints, built once: the walls never move), in building order, so the set and
## the order are those of a scan over every building.

## Heights up the kaiju's body (shares of its height: the feet, the pelvis, the torso, the head)
## and steps forward along its facing (in body radii) that must stay in sight (R 19.4: the feet
## too, so the street round them reads).
const HEIGHTS := [0.03, 0.3, 0.6, 0.9]
const AHEAD := [0.0, 1.0, 2.0]
## Side of a grid cell of the footprint index (metres).
const CELL := 32.0

var _cfg: Dictionary
var _buildings: Array[RampageSim.Building]
var _views: Callable
var _faded := {}  # building index -> current opacity (only those below 1)
var _started := false
var _grid := {}  # Vector2i cell -> PackedInt32Array of the buildings whose footprint meets it


## views: building index -> its BuildingView, or null while it is not built yet.
func _init(buildings: Array[RampageSim.Building], views: Callable) -> void:
	_cfg = Content.section("vehicles")
	_buildings = buildings
	_views = views
	_index()


## The points over a kaiju standing at `feet`, `height` tall, facing `ahead` (one body radius
## long, ground plane) that must stay in sight. Under water (the rise from the river, comment
## #27) only the part above `surface` shows, so the heights spread over that part.
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


## The sight points of the sim's kaiju now (CityView fades by them; the tests replay them).
static func sight_of(sim: RampageSim) -> PackedVector3Array:
	var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var reach := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var ahead := Vector3(sim.facing.x, 0, sim.facing.y) * reach
	var surface := -Num.f(sim.city.get("river_depth", 0.0))
	return targets(feet, sim.reach_height(), ahead, surface)


func update(eye: Vector3, sight: PackedVector3Array, delta: float) -> void:
	var step := delta / Num.f(_cfg["fade_seconds"])
	var low := Num.f(_cfg["fade_opacity"])
	var hit := {}
	var first := not _started  # the run's first frame: what blocks starts faded, no pop-in
	_started = true
	for n: int in blocking(eye, sight):
		hit[n] = true
	for n: int in hit:
		if not _faded.has(n):
			_faded[n] = low if first else 1.0
	for n: int in _faded.keys():
		var now: float = _faded[n]
		var next := move_toward(now, low if hit.has(n) else 1.0, step)
		var view: BuildingView = _views.call(n)
		if view != null and (next != now or next < 1.0):  # a view streamed in late gets it too
			view.set_opacity(next)
		if next >= 1.0:
			_faded.erase(n)
		else:
			_faded[n] = next


## The buildings that stand in a sight line from the eye (see blocks), in building order.
func blocking(eye: Vector3, sight: PackedVector3Array) -> PackedInt32Array:
	var out := PackedInt32Array()
	for n: int in _near(eye, sight):
		if blocks(eye, sight, _buildings[n]):
			out.append(n)
	return out


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


## Building n's opacity now (1 = solid; tests read it).
func opacity(n: int) -> float:
	return _faded.get(n, 1.0)


## Whether building b stands in a sight line from the eye to any of the kaiju's points, or the
## eye is inside it (R 19.4: a tower the camera sits in fades too, never a black screen). The box
## is the building as it stands now: a carved stump below every sight line never fades.
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


static func _cuts(
	eye: Vector3, sight: PackedVector3Array, b: RampageSim.Building, top: int
) -> bool:
	var box := AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, top, b.d))
	if box.has_point(eye):
		return true
	for target: Vector3 in sight:
		if box.has_point(target):
			continue  # that point of the body is inside the building (wading through it)
		if box.intersects_segment(eye, target) != null:
			return true
	return false
