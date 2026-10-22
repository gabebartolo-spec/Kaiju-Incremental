class_name StreamRank
extends RefCounted
## What the building stream (BuildingStream) ranks a building by: how far it is from the camera
## and the kaiju, and whether the camera can see it. A building ranks by its distance from the
## camera, or from the kaiju plus city.stream_view.kaiju_extra_m, whichever is less; what the
## camera cannot see ranks farther: the wedge the frustum covers ranks as it is (zone 0), the
## margin band beside it (city.stream_view.margin_deg wide, wider than the camera can swing, so a
## swing meets meshed buildings) side_m farther (zone 1), anything else outside_m farther (zone
## 2). A ring of ring_m round the camera is zone 0 whichever way the camera looks. Without a
## camera (before the rampage's own exists) every building is zone 0 and ranks by its distance
## from the kaiju. Presentation only.

## false: no camera, every building ranks by its distance from the kaiju.
var on := false
## The camera's ground position and heading at the last set_view (the stream compares them to
## decide when to replan).
var at := Vector2.ZERO
var dir := Vector2.ZERO
## Metres added to the rank of a building outside the margin band too.
var outside := 0.0

var _cx := PackedFloat32Array()  # per building: its centre (x, z) and its footprint's radius
var _cz := PackedFloat32Array()
var _cr := PackedFloat32Array()
var _keep := 0.0
var _ring := 0.0
var _side := 0.0
var _kaiju_extra := 0.0
var _core_cos := 0.0  # the frustum's own wedge, and that plus the margin band
var _core_sin := 0.0
var _band_cos := 0.0
var _band_sin := 0.0


func _init(buildings: Array[RampageSim.Building]) -> void:
	_cx.resize(buildings.size())
	_cz.resize(buildings.size())
	_cr.resize(buildings.size())
	for n: int in buildings.size():
		var b := buildings[n]
		_cx[n] = b.x
		_cz[n] = b.z
		_cr[n] = 0.5 * sqrt(float(b.w * b.w + b.d * b.d))


## Reorders `queue` (building indices) so its landmarks stream before every other building, then
## the red-barrel sites (their models are not the stand-in box either), each group keeping its
## nearest-first order.
static func landmarks_first(buildings: Array[RampageSim.Building], queue: Array[int]) -> void:
	var marks: Array[int] = []
	var hazards: Array[int] = []
	var others: Array[int] = []
	for n: int in queue:
		var b := buildings[n]
		if b.landmark != "":
			marks.append(n)
		else:
			(hazards if b.hazard != "" else others).append(n)
	queue.assign(marks + hazards + others)


## The camera the stream ranks by, as [ground position, heading, half-angle of the wedge it sees
## in radians: the frustum's own half-angle on the ground plane], or [] without a viewport, a
## camera, a camera looking straight up or down, or a `city` without stream_view.
static func look(viewport: Viewport, city: Dictionary) -> Array:
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera == null or not city.has("stream_view"):
		return []
	var ahead := -camera.global_transform.basis.z
	var flat := Vector2(ahead.x, ahead.z)
	if flat.length() < 0.2:
		return []
	var size := viewport.get_visible_rect().size
	var aspect := maxf(size.x / maxf(size.y, 1.0), 16.0 / 9.0)
	# A camera pitched down by p sees a ground wedge tan(half_h) / cos(p) wide.
	var tilt := absf(asin(clampf(ahead.y, -1.0, 1.0)))
	var half_h := atan(tan(deg_to_rad(camera.fov) * 0.5) * aspect / cos(tilt))
	return [Vector2(camera.global_position.x, camera.global_position.z), flat.normalized(), half_h]


## Takes the camera: [ground position, heading, half-angle of the wedge in radians] (see
## BuildingStream._look), or [] for none; `city` holds stream_view.
func set_view(look: Array, city: Dictionary) -> void:
	on = not look.is_empty()
	if not on:
		return
	var cfg: Dictionary = city["stream_view"]
	at = look[0]
	dir = look[1]
	_ring = Num.f(cfg["ring_m"])
	_side = Num.f(cfg["side_m"])
	outside = Num.f(cfg["outside_m"])
	_keep = Num.f(cfg["landmark_keep_m"])
	_kaiju_extra = Num.f(cfg["kaiju_extra_m"])
	var half: float = look[2]
	var band := minf(PI, half + deg_to_rad(Num.f(cfg["margin_deg"])))
	_core_cos = cos(half)
	_core_sin = sin(half)
	_band_cos = cos(band)
	_band_sin = sin(band)


## Whether `look` (see look) differs from the view of the last set_view: the camera appeared or
## went, moved `move_m` metres, or turned `turn_deg` degrees.
func moved(look_now: Array, move_m: float, turn_deg: float) -> bool:
	if look_now.is_empty() == on:
		return true
	if look_now.is_empty():
		return false
	var there: Vector2 = look_now[0]
	var heading: Vector2 = look_now[1]
	return there.distance_to(at) >= move_m or rad_to_deg(heading.angle_to(dir)) >= turn_deg


## Where building n lies to the camera: 0 in the frustum's wedge or the ring, 1 in the margin
## band only, 2 outside both. A building is in a wedge of half-angle H when any of its
## footprint's circle is: the angle off the heading is at most H plus asin(radius / distance),
## compared by cosines (no trigonometry per building).
func zone(n: int) -> int:
	if not on:
		return 0
	var dx := _cx[n] - at.x
	var dz := _cz[n] - at.y
	return _zone_of(dx, dz, sqrt(dx * dx + dz * dz), _cr[n])


func _zone_of(dx: float, dz: float, far: float, reach: float) -> int:
	if far <= _ring + reach:
		return 0
	var along := (dx * dir.x + dz * dir.y) / far
	var s := reach / far
	var c := sqrt(1.0 - s * s)
	if along >= _core_cos * c - _core_sin * s:
		return 0
	return 1 if along >= _band_cos * c - _band_sin * s else 2


## Whether landmark n stays meshed: no camera, or the camera's wedge or margin band reaches it,
## or it stands within landmark_keep_m of the camera or the kaiju (a walk or a dash that turns
## the view meets it already built). Else it unloads like an ordinary building.
func keeps_landmark(n: int, kaiju: Vector2) -> bool:
	if not on or zone(n) < 2:
		return true
	var here := Vector2(_cx[n], _cz[n])
	return minf(here.distance_to(kaiju), here.distance_to(at)) - _cr[n] <= _keep


## Building n's rank, in metres: smaller streams first. The less of its distance from the camera
## and its distance from the kaiju plus kaiju_extra_m, plus side_m in zone 1, outside_m in zone
## 2. Past `limit` metres from the kaiju the plain distance is enough (the plan only needs to
## know it is not wanted). Without a view, the distance from the kaiju.
func rank(n: int, kaiju: Vector2, limit: float = INF) -> float:
	var base := kaiju.distance_to(Vector2(_cx[n], _cz[n]))
	if not on or base > limit:
		return base
	var dx := _cx[n] - at.x
	var dz := _cz[n] - at.y
	var far := sqrt(dx * dx + dz * dz)
	base = minf(base + _kaiju_extra, far)
	var area := _zone_of(dx, dz, far, _cr[n])
	return base + (0.0 if area == 0 else _side if area == 1 else outside)
