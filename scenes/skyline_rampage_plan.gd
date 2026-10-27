class_name SkylineRampagePlan
extends RefCounted
## The far rampage's schedule (SkylineRampage), planned once from the beast's path and the run's
## seeded stream: which far towers fall and when (the beast's own blows first, then a few
## aftershocks beside its path) and where fires burn (every ruin, and a few towers left standing).
## Pure data: nothing is drawn here, and the stream is used first by this plan, then the lights.

const PLAN_S := 900.0  # tower falls are planned this far ahead (longer than any rampage)
const PLAN_STEP := 0.1
const MIN_TALL := 12.0  # lower boxes never fall on their own
const GROUND_Y := 0.8  # the far shore's concrete top (CitySkyline._far_shore)
const AFTERSHOCK := Vector2(2.0, 10.0)  # a nearby tower goes this long after the beast passes
const STANDING_START := Vector2(-60.0, 25.0)  # when the fires on standing towers caught
const FLAME_AT_FALL := 0.6  # share of a fall after which its ruins burn
const FLAME := Vector2(4.0, 8.0)  # a ruin's flame size, least and most

## Tower falls by time: index, crowns, at (s), dir (+-1 along x), smash (the beast's own blow).
var falls: Array[Dictionary] = []
var fires: Array[Dictionary] = []  # pos, size, start, strength
var _cfg: Dictionary
var _boxes: Array[Dictionary]
var _rng: RandomNumberGenerator
var _crowns: Dictionary = {}  # tower index -> its crown boxes' indices
var _path_z := 0.0
var _beast_x: Callable


## `cfg` is tuning "skyline_rampage"; `boxes` the far skyline's boxes (CitySkyline.far_boxes());
## `rng` the rampage's stream, which this plan and then the lights and smoke draw from in turn.
func _init(cfg: Dictionary, boxes: Array[Dictionary], rng: RandomNumberGenerator) -> void:
	_cfg = cfg
	_boxes = boxes
	_rng = rng


## Plans every fall and fire for a beast pacing z = `path_z`, its x at time t `beast_x.call(t)`.
func build(path_z: float, beast_x: Callable) -> void:
	_path_z = path_z
	_beast_x = beast_x
	_plan_falls()
	_plan_fires()


func _f(key: String) -> float:
	return Num.f(_cfg[key])


func _x(t: float) -> float:
	var x: float = _beast_x.call(t)
	return x


func _plan_falls() -> void:
	var corridor := _f("corridor")
	var reach := _f("reach")
	_index_crowns()
	var nearby: Array[int] = []
	for i: int in _boxes.size():
		var size: Vector3 = _boxes[i]["size"]
		var at: Vector3 = _boxes[i]["at"]
		if _boxes[i].has("crown_of") or size.y < MIN_TALL:
			continue
		var dz := absf(at.z - _path_z) - size.z * 0.5
		if dz < corridor:  # in the beast's way: its blow drops the tower
			var t := _reached(at.x, reach + size.x * 0.5)
			if t >= 0.0:
				falls.append(_fall(i, t, at.x - _x(t), true))
		elif dz < corridor * 3.0:
			nearby.append(i)
	_aftershocks(nearby, reach)
	falls.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["at"] < b["at"])
	_standing_fires(nearby)


## Fills `_crowns`: tower index -> the indices of its crown boxes.
func _index_crowns() -> void:
	for i: int in _boxes.size():
		if _boxes[i].has("crown_of"):
			var of := Num.i(_boxes[i]["crown_of"])
			var list: Array = _crowns.get(of, [])
			list.append(i)
			_crowns[of] = list


## A few towers beside its path fall late (aftershocks).
func _aftershocks(nearby: Array[int], reach: float) -> void:
	for _n: int in Num.i(_cfg["extra_falls"]):  # aftershocks: a few towers beside its path
		if nearby.is_empty():
			break
		var i: int = nearby.pop_at(_rng.randi_range(0, nearby.size() - 1))
		var at: Vector3 = _boxes[i]["at"]
		var t := _reached(at.x, reach * 2.0)
		if t >= 0.0:
			t += _rng.randf_range(AFTERSHOCK.x, AFTERSHOCK.y)
			falls.append(_fall(i, t, _rng.randf_range(-1.0, 1.0), false))


## A few of the towers still standing burn.
func _standing_fires(nearby: Array[int]) -> void:
	for _n: int in Num.i(_cfg["standing_fires"]):  # towers still standing, burning
		if nearby.is_empty():
			break
		var box: Dictionary = _boxes[nearby.pop_at(_rng.randi_range(0, nearby.size() - 1))]
		var size: Vector3 = box["size"]
		var at: Vector3 = box["at"]
		var pos := Vector3(
			at.x + _rng.randf_range(-0.3, 0.3) * size.x,
			at.y + size.y * _rng.randf_range(-0.15, 0.3),
			at.z + size.z * 0.5 + 0.6
		)
		var start := _rng.randf_range(STANDING_START.x, STANDING_START.y)
		var flame := _rng.randf_range(FLAME.x * 0.7, FLAME.y * 0.7)
		fires.append({"pos": pos, "size": flame, "start": start, "dust": false})


## The first time the beast comes within `within` of x, or -1 if it never does.
func _reached(x: float, within: float) -> float:
	var t := 0.0
	while t < PLAN_S:
		if absf(_x(t) - x) < within:
			return t
		t += PLAN_STEP
	return -1.0


func _fall(i: int, t: float, away: float, smash: bool) -> Dictionary:
	var crown_list: Array = _crowns.get(i, [])
	return {
		"index": i,
		"crowns": crown_list,
		"at": t,
		"dir": signf(away) if away != 0.0 else 1.0,
		"smash": smash,
		"drawn": -1.0
	}


## Every fall leaves a burning ruin and a cloud of dust.
func _plan_fires() -> void:
	for fall: Dictionary in falls:
		var box: Dictionary = _boxes[Num.i(fall["index"])]
		var size: Vector3 = box["size"]
		var at: Vector3 = box["at"]
		var start := Num.f(fall["at"]) + _f("fall_s") * FLAME_AT_FALL
		var pos := Vector3(at.x + _rng.randf_range(-0.2, 0.2) * size.x, GROUND_Y + 1.5, at.z)
		var w := clampf(size.x * 0.5, FLAME.x, FLAME.y)
		fires.append(
			{"pos": pos, "size": w, "start": start, "dust": true, "fall": Num.f(fall["at"])}
		)
