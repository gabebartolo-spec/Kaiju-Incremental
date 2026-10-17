class_name BuildingFade
extends RefCounted
## A building between the camera and the kaiju's body fades to a screen door, as vehicles do
## (D-025's rule, VehicleFade), so a grown kaiju among towers its own height is always seen.
## Each frame, the sight lines from the camera to points over the kaiju's body (up its height
## and forward along its facing, where the torso and head are) are tested against every built
## building's box; one that cuts a line eases down to vehicles.fade_opacity, the rest ease
## back. The camera never moves for it. Presentation only.

## Heights up the kaiju's body (shares of its height) and steps forward along its facing (in
## body radii) that must stay in sight.
const HEIGHTS := [0.3, 0.6, 0.9]
const AHEAD := [0.0, 1.0, 2.0]

var _cfg: Dictionary
var _buildings: Array[RampageSim.Building]
var _views: Callable
var _faded := {}  # building index -> current opacity (only those below 1)


## views: building index -> its BuildingView, or null while it is not built yet.
func _init(buildings: Array[RampageSim.Building], views: Callable) -> void:
	_cfg = Content.section("vehicles")
	_buildings = buildings
	_views = views


## The points over a kaiju standing at `feet`, `height` tall, facing `ahead` (one body radius
## long, ground plane) that must stay in sight.
static func targets(feet: Vector3, height: float, ahead: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	for share: float in HEIGHTS:
		for steps: float in AHEAD:
			out.append(feet + Vector3(0, height * share, 0) + ahead * steps)
	return out


func update(eye: Vector3, sight: PackedVector3Array, delta: float) -> void:
	var step := delta / Num.f(_cfg["fade_seconds"])
	var low := Num.f(_cfg["fade_opacity"])
	var lo := Vector2(eye.x, eye.z)
	var hi := lo
	for p: Vector3 in sight:
		lo = Vector2(minf(lo.x, p.x), minf(lo.y, p.z))
		hi = Vector2(maxf(hi.x, p.x), maxf(hi.y, p.z))
	var hit := {}
	for n: int in _buildings.size():
		var b := _buildings[n]
		# Cheap reject: the sight lines stay inside the eye-to-kaiju rectangle on the ground.
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		if blocks(eye, sight, b):
			hit[n] = true
	for n: int in hit:
		if not _faded.has(n):
			_faded[n] = 1.0
	for n: int in _faded.keys():
		var now: float = _faded[n]
		var next := move_toward(now, low if hit.has(n) else 1.0, step)
		var view: BuildingView = _views.call(n)
		if view != null and next != now:
			view.set_opacity(next)
		if next >= 1.0:
			_faded.erase(n)
		else:
			_faded[n] = next


## Whether building b stands in a sight line from the eye to any of the kaiju's points.
static func blocks(eye: Vector3, sight: PackedVector3Array, b: RampageSim.Building) -> bool:
	var box := AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, b.height, b.d))
	if box.has_point(eye):
		return false  # the camera inside a tower: nothing sensible to fade
	for target: Vector3 in sight:
		if box.has_point(target):
			continue  # that point of the body is inside the building (wading through it)
		if box.intersects_segment(eye, target) != null:
			return true
	return false
