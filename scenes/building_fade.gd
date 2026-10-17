class_name BuildingFade
extends RefCounted
## A building between the camera and the kaiju's body fades to a screen door, as vehicles do
## (D-025's rule, VehicleFade), so a grown kaiju among towers its own height is always seen.
## Each frame, the sight lines from the camera to three points up the kaiju's body are tested
## against every built building's box; one that cuts a line eases down to vehicles.fade_opacity,
## the rest ease back. The camera never moves for it. Presentation only.

## Heights up the kaiju's body, as shares of its height, that must stay in sight.
const SIGHT := [0.3, 0.6, 0.9]

var _cfg: Dictionary
var _buildings: Array[RampageSim.Building]
var _views: Callable
var _faded := {}  # building index -> current opacity (only those below 1)


## views: building index -> its BuildingView, or null while it is not built yet.
func _init(buildings: Array[RampageSim.Building], views: Callable) -> void:
	_cfg = Content.section("vehicles")
	_buildings = buildings
	_views = views


## feet: the kaiju's feet (world); height: how tall it stands.
func update(eye: Vector3, feet: Vector3, height: float, delta: float) -> void:
	var step := delta / Num.f(_cfg["fade_seconds"])
	var low := Num.f(_cfg["fade_opacity"])
	var lo := Vector2(minf(eye.x, feet.x), minf(eye.z, feet.z))
	var hi := Vector2(maxf(eye.x, feet.x), maxf(eye.z, feet.z))
	var hit := {}
	for n: int in _buildings.size():
		var b := _buildings[n]
		# Cheap reject: the sight lines stay inside the eye-to-kaiju rectangle on the ground.
		if b.x + b.w * 0.5 < lo.x or b.x - b.w * 0.5 > hi.x:
			continue
		if b.z + b.d * 0.5 < lo.y or b.z - b.d * 0.5 > hi.y:
			continue
		if blocks(eye, feet, height, b):
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


## Whether building b stands in a sight line from the eye to the kaiju's body.
static func blocks(eye: Vector3, feet: Vector3, height: float, b: RampageSim.Building) -> bool:
	var box := AABB(Vector3(b.x - b.w * 0.5, 0.0, b.z - b.d * 0.5), Vector3(b.w, b.height, b.d))
	if box.has_point(eye):
		return false  # the camera inside a tower: nothing sensible to fade
	for share: float in SIGHT:
		var target := feet + Vector3(0, height * share, 0)
		if box.has_point(target):
			continue  # that point of the body is inside the building (wading through it)
		if box.intersects_segment(eye, target) != null:
			return true
	return false
