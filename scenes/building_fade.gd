class_name BuildingFade
extends RefCounted
## The one building that fades to a screen door: a wall that fills the frame at the camera. Every
## other building, standing, toppling or broken, draws fully solid and may hide the kaiju (director
## 2026-10-27, D-326: "its ok to obscure the kaiju, its not ok to block the camera ... NEVER FADE
## OUT THE DESTRUCTION"; "Only a wall that fills the frame at the camera is handled"; D-283's pass
## bar: "no wall fills the frame"). Vehicles never fade (D-290). Until the camera bubble (#238)
## does it, this is the stopgap for "not ok to block the camera".
## Each frame, the sight lines from the camera to points over the kaiju's body (up its height
## and forward along its facing, where the torso and head are; they run to the body's whole width,
## camera.fade_width body radii each side) are tested against every built building's box. A
## building a line cuts is nearer the camera than the kaiju by construction (the line reaches the
## kaiju past it, or the camera is inside it); of those only one whose standing box covers
## camera.fade_frame_share or more of the screen (FrameShare) eases down to camera.fade_opacity,
## the rest, and any that stop filling the frame, ease back, both over camera.fade_seconds on a
## smoothstep (no pop at either end). A building with a section in the air (a topple or a drop)
## is held solid for the fall: it snaps to opacity 1 when the fall starts. The camera never moves
## for it. Presentation only.
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
var _min_share: float
var _buildings: Array[RampageSim.Building]
var _views: Callable
var _faded := {}  # building index -> fade progress, 0 solid .. 1 faded (only those above 0)
var _started := false
var _grid := {}  # Vector2i cell -> PackedInt32Array of the buildings whose footprint meets it


## views: building index -> its BuildingView, or null while it is not built yet. min_share: the
## share of the screen a building must cover to fade (tuning camera.fade_frame_share when negative;
## tests pass 0 to fade every building a sight line crosses).
func _init(buildings: Array[RampageSim.Building], views: Callable, min_share := -1.0) -> void:
	_cfg = Content.section("camera")
	_min_share = Num.f(_cfg["fade_frame_share"]) if min_share < 0.0 else min_share
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
## With the `eye`, each point also gets one each side of it, across the line of sight, at the
## body's half width, so a tower over the flank on screen fades too.
static func sight_of(sim: RampageSim, eye := Vector3.INF) -> PackedVector3Array:
	var feet := Vector3(sim.kaiju_pos.x, sim.stand_y, sim.kaiju_pos.y)
	var reach := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var ahead := Vector3(sim.facing.x, 0, sim.facing.y) * reach
	var surface := -Num.f(sim.city.get("river_depth", 0.0))
	var out := targets(feet, sim.reach_height(), ahead, surface)
	if eye == Vector3.INF:
		return out
	var half := reach * Num.f(Content.section("camera")["fade_width"])
	var across := Vector3(feet.z - eye.z, 0.0, eye.x - feet.x).normalized() * half
	for n: int in out.size():
		out.append(out[n] + across)
		out.append(out[n] - across)
	return out


## The screen-door opacity at fade progress `p` (0 solid .. 1 fully faded), on a smoothstep.
static func eased(p: float) -> float:
	var cfg := Content.section("camera")
	return lerpf(1.0, Num.f(cfg["fade_opacity"]), smoothstep(0.0, 1.0, p))


## `frame`: the camera now; `solid`: the buildings (index -> true) with a section in the air, held
## solid whatever the camera sees.
func update(frame: FrameShare, sight: PackedVector3Array, delta: float, solid := {}) -> void:
	var step := delta / Num.f(_cfg["fade_seconds"])
	var hit := {}
	var first := not _started  # the run's first frame: what blocks starts faded, no pop-in
	_started = true
	for n: int in solid:
		if _faded.has(n):  # a fall began on a faded building: it snaps solid
			_faded.erase(n)
			_show(n, 1.0)
	for n: int in blocking(frame.eye(), sight):
		if not solid.has(n) and fills(frame, _buildings[n]):
			hit[n] = true
	for n: int in hit:
		if not _faded.has(n):
			_faded[n] = 1.0 if first else 0.0
	for n: int in _faded.keys():
		var now: float = _faded[n]
		var next := move_toward(now, 1.0 if hit.has(n) else 0.0, step)
		_show(n, eased(next))  # every frame while it fades: a view streamed in late gets it too
		if next <= 0.0:
			_faded.erase(n)
		else:
			_faded[n] = next


## The buildings with a section in the air (index -> true) among CityView's falls: held solid.
static func held(falls: Dictionary) -> Dictionary:
	var out := {}
	for f: Dictionary in falls.values():
		out[Num.i(f["building"])] = true
	return out


func _show(n: int, value: float) -> void:
	var view: BuildingView = _views.call(n)
	if view != null:
		view.set_opacity(value)


## Whether building b covers enough of the screen to fade: the frame-filling wall (D-326).
func fills(frame: FrameShare, b: RampageSim.Building) -> bool:
	return _min_share <= 0.0 or frame.share_of(_box(b, standing_top(b))) >= _min_share


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
			var cell: PackedInt32Array = _grid.get(Vector2i(cx, cz), PackedInt32Array())
			found.append_array(cell)
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
	return eased(Num.f(_faded[n])) if _faded.has(n) else 1.0


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


## The building's box `top` floors tall.
static func _box(b: RampageSim.Building, top: int) -> AABB:
	return AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, top, b.d))


static func _cuts(
	eye: Vector3, sight: PackedVector3Array, b: RampageSim.Building, top: int
) -> bool:
	var box := _box(b, top)
	if box.has_point(eye):
		return true
	for target: Vector3 in sight:
		if box.has_point(target):
			continue  # that point of the body is inside the building (wading through it)
		if box.intersects_segment(eye, target) != null:
			return true
	return false
