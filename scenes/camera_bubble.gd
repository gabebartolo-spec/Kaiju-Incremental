class_name CameraBubble
extends RefCounted
## The camera bubble (D-283, D-326; director 2026-10-27: "its the ones that the camera itself
## phases through"): buildings stay solid. A sphere of camera.bubble_radius round the CAMERA cuts
## away, with a hard edge, the standing buildings it reaches (at most camera.bubble_max, those
## covering the most of the view first: FrameShare; D-283's bar, "no wall fills the frame"), their
## shadows kept (building_baked.gdshader). Never cut: a building
## in the kaiju's destruction field (in_field: his longest reach plus the building's half-width),
## a damaged one (a chunk lost), and all that is not a standing building: falling, toppling and
## broken pieces, rubble, vehicles and the kaiju draw whole and may hide him ("its ok to obscure
## the kaiju, its not ok to block the camera", D-326; vehicles D-290). No screen door anywhere.
##
## The sphere's far edge stays the field's radius short of the kaiju on the ground: while the camera
## is nearer than bubble_radius plus that, the radius shrinks to fit. A building's cut opens from
## the camera outward over camera.bubble_seconds and closes back when the sphere leaves it (the
## run's first frame starts open); one the field reaches or the kaiju damages is whole at once. The
## core (director 2026-10-30: "sometimes a building still blocks the camera"): whatever standing
## building comes within camera.bubble_core of the camera is cut at once, damaged or in the field or
## not, before any other; the sphere never shrinks below the core. The shaders read the global
## `bubble_radius`, each building its own `bubble_cut`. Only the buildings whose footprint meets the
## square round the camera are tested (a grid of footprints, built once: the walls never move).
## Presentation only.

## Side of a grid cell of the footprint index (metres).
const CELL := 32.0

var _cfg: Dictionary = Content.section("camera")
var _buildings: Array[RampageSim.Building]
var _views: Callable
var _radius := -1.0  # -1 until the first frame: the cuts in the way then start open
var _open := {}  # building index -> its cut, 0 whole .. 1 the whole radius (only those above 0)
var _grid := {}  # Vector2i cell -> PackedInt32Array of the buildings whose footprint meets it


## views: building index -> its BuildingView, or null while it is not built yet.
func _init(buildings: Array[RampageSim.Building], views: Callable) -> void:
	_buildings = buildings
	_views = views
	_index()


## The kaiju's destruction field now: the longest reach of his attacks (stomp, signature, claw
## swipe, tail sweep), in metres from where he stands.
static func field(sim: RampageSim) -> float:
	var cfg := sim.powers_cfg
	var bs := sim.body_scale()
	var tail := (Num.f(cfg["tail_reach"]) + sim.stat("tail_reach")) * bs
	var swipe := Num.f(cfg["swipe_far"]) * bs
	return maxf(maxf(sim.stomp_radius(), sim.ability_reach()), maxf(tail, swipe))


## The sphere's radius for a camera at `eye` and a kaiju standing at `kaiju` with destruction
## `field`: camera.bubble_radius, less while its far edge would come within the field on the ground.
static func radius_for(eye: Vector3, kaiju: Vector3, p_field: float) -> float:
	var flat := Vector2(eye.x, eye.z).distance_to(Vector2(kaiju.x, kaiju.z))
	var cfg := Content.section("camera")
	var size := Num.f(cfg["bubble_radius"])
	return maxf(clampf(flat - p_field, 0.0, size), Num.f(cfg["bubble_core"]))


## Whether building b's footprint lies within the destruction `field` of a kaiju at `kaiju`: its
## centre within the field plus its half-width (never cut).
static func in_field(b: RampageSim.Building, kaiju: Vector3, p_field: float) -> bool:
	var at := Vector2(b.x, b.z).distance_to(Vector2(kaiju.x, kaiju.z))
	return at <= p_field + maxf(b.w, b.d) * 0.5


## Whether building b has lost a chunk (never cut once it has: the destruction stays in view).
static func damaged(b: RampageSim.Building) -> bool:
	return b.frame != null and b.frame.alive_count < b.start_chunks


## Building b's box, standing whole.
static func box(b: RampageSim.Building) -> AABB:
	return AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, b.height, b.d))


## How far building b's box is from `eye` (0 inside it).
static func reach(eye: Vector3, b: RampageSim.Building) -> float:
	var whole := box(b)
	return eye.distance_to(eye.clamp(whole.position, whole.end))


## Whether a point of a building cut `share` of the way is cut away by a bubble of `radius` round
## `eye` (the shaders' test).
static func hides(point: Vector3, eye: Vector3, radius: float, share := 1.0) -> bool:
	return point.distance_to(eye) < radius * share


## The radius now (tests read it).
func radius() -> float:
	return maxf(_radius, 0.0)


## Building n's cut now (0 = drawn whole; tests read it).
func cut(n: int) -> float:
	return Num.f(_open.get(n, 0.0))


## One frame: sizes the sphere for the camera drawing `frame` and the kaiju standing at `kaiju`
## with destruction `p_field`, picks the buildings it reaches and eases each one's cut.
func update(frame: FrameShare, kaiju: Vector3, p_field: float, delta: float) -> void:
	var first := _radius < 0.0
	_radius = radius_for(frame.eye(), kaiju, p_field)
	RenderingServer.global_shader_parameter_set("bubble_radius", _radius)
	var step := delta / Num.f(_cfg["bubble_seconds"])
	var on := {}
	for n: int in picked(frame, kaiju, p_field, _radius):
		on[n] = true
		if not _open.has(n):
			_open[n] = 1.0 if first else 0.0
	var core := Num.f(_cfg["bubble_core"])
	for n: int in _open.keys():
		var b := _buildings[n]
		var next := move_toward(Num.f(_open[n]), 1.0 if on.has(n) else 0.0, step)
		if reach(frame.eye(), b) < core:
			next = 1.0  # in the camera's core: always cut, at once
		elif damaged(b) or in_field(b, kaiju, p_field):
			next = 0.0  # the destruction is never cut, not even while a cut closes
		var view: BuildingView = _views.call(n)
		if view != null:  # every frame while it is cut: a view streamed in late gets it too
			view.set_near_camera(next > 0.0, next)
		if next <= 0.0:
			_open.erase(n)
		else:
			_open[n] = next


## The standing buildings a sphere of `p_radius` round the camera drawing `frame` reaches, at
## most camera.bubble_max of them: every standing one within the core first, then those covering
## the most of its view (the nearest first between equals); outside the core none in the field of a
## kaiju at `kaiju`, none damaged.
func picked(frame: FrameShare, kaiju: Vector3, p_field: float, p_radius: float) -> PackedInt32Array:
	var found: Array[Vector3] = []  # (minus the share of the view, distance from the eye, index)
	if p_radius <= 0.0:
		return PackedInt32Array()
	var eye := frame.eye()
	var core := Num.f(_cfg["bubble_core"])
	for n: int in _near(eye, p_radius):
		var b := _buildings[n]
		var gap := reach(eye, b)
		if gap < core and b.frame != null and b.frame.alive_count > 0:
			found.append(Vector3(-INF, gap, n))  # the core: before any share of the view
		elif gap < p_radius and not damaged(b) and not in_field(b, kaiju, p_field):
			found.append(Vector3(-frame.share_of(box(b)), gap, n))
	found.sort()
	var out := PackedInt32Array()
	for f: Vector3 in found.slice(0, Num.i(_cfg["bubble_max"])):
		out.append(int(f.z))
	return out


## The buildings whose footprint meets the square of half-side `half` round the eye on the
## ground, each once, in building order.
func _near(eye: Vector3, half: float) -> PackedInt32Array:
	var lo := Vector2(eye.x - half, eye.z - half)
	var hi := Vector2(eye.x + half, eye.z + half)
	var found := PackedInt32Array()
	var first := Vector2i((lo / CELL).floor())
	var last := Vector2i((hi / CELL).floor())
	for cx: int in range(first.x, last.x + 1):
		for cz: int in range(first.y, last.y + 1):
			var cell: PackedInt32Array = _grid.get(Vector2i(cx, cz), PackedInt32Array())
			found.append_array(cell)
	found.sort()
	var out := PackedInt32Array()
	var prev := -1
	for n: int in found:
		if n != prev:  # a footprint spanning several cells is listed in each
			out.append(n)
		prev = n
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
