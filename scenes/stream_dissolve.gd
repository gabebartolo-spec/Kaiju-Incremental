class_name StreamDissolve
extends StreamStandIns
## The stream swap without the pop (director 2026-10-28: "pop-in textures on the building
## facades"; the lead's call): a streamed building's mesh and its facade box cross over
## city.stand_in_fade_s with a complementary dither (building share p, box 1 - p), both ways:
## the mesh dithers in as it arrives (box out), and dithers out as the kaiju walks away (box
## in), so the two window patterns cross instead of flipping. Only the stream swap: a building
## the rampage touches, or one that regrows, swaps at once (D-326). Presentation only; the
## clock is the frame delta, never a wall clock.

var _seconds: float
var _age: Dictionary = {}  # building index -> seconds into its crossing
var _view: Dictionary = {}  # building index -> the BuildingView crossing
var _going: Dictionary = {}  # building index -> true while its mesh dithers out


func _init(buildings: Array[RampageSim.Building], city: Dictionary) -> void:
	super(buildings)
	_seconds = Num.f(city.get("stand_in_fade_s", 0.0))


## Building n's mesh arrived: it dithers in over its box when `soft`, else the box goes now.
func dissolve(n: int, view: BuildingView, soft: bool) -> void:
	_end(n)
	if not soft or _seconds <= 0.0 or _buildings[n].is_rail():
		hide(n)
		return
	_age[n] = 0.0
	_view[n] = view
	_going[n] = false
	_cross(n, 0.0)


## Building n's mesh is dropped: it dithers out over its box when `soft` (the kaiju walked
## away), else it goes now (the building regrew).
func leave(n: int, view: BuildingView, soft: bool) -> void:
	var seen := _seconds - float(_age.get(n, 0.0)) if _age.has(n) else 0.0
	_end(n)
	if not soft or _seconds <= 0.0 or _buildings[n].is_rail():
		_drop(view)
		show(n)
		return
	_age[n] = seen
	_view[n] = view
	_going[n] = true
	_cross(n, seen)


## Advance every crossing by `delta` seconds; a finished one lands.
func step(delta: float) -> void:
	for n: int in _age.keys():
		var age: float = _age[n] + delta
		if age >= _seconds:
			_land(n)
		else:
			_age[n] = age
			_cross(n, age)


## The rampage touched building n: a crossing in flight lands now (D-326).
func touch(n: int) -> void:
	if _age.has(n):
		_land(n)


## Building n is a box again: the box comes back whole.
func show(n: int) -> void:
	_age.erase(n)
	fade(n, 1.0)
	super.show(n)


## Building n's crossing is `age` seconds in: the mesh draws p of itself, the box the rest.
func _cross(n: int, age: float) -> void:
	var p := clampf(age / _seconds, 0.0, 1.0)
	p = 1.0 - p if _going[n] else p
	var view: BuildingView = _view[n]
	view.set_dissolve(p)
	fade(n, 1.0 - p)


## Building n's crossing is over: a mesh that came in stands whole and the box goes; one that
## went out is freed and the box is whole.
func _land(n: int) -> void:
	var going: bool = _going[n]
	_end(n)
	if going:
		show(n)
	else:
		hide(n)


## Forget building n's crossing, if any (a mesh that was going out is freed).
func _end(n: int) -> void:
	if not _age.has(n):
		return
	var view: BuildingView = _view[n]
	if _going[n]:
		_drop(view)
	else:
		view.set_dissolve(1.0)
	_age.erase(n)
	_view.erase(n)
	_going.erase(n)


func _drop(view: BuildingView) -> void:
	if view.get_parent() != null:
		view.get_parent().remove_child(view)
	BuildingView.forget(view)
	view.free()
