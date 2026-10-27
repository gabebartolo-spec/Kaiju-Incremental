class_name StreamDissolve
extends StreamStandIns
## The stream swap without the pop (director 2026-10-28: "pop-in textures on the building
## facades"; the lead's call): when a streamed building's mesh arrives its facade box does not
## vanish that frame, it dissolves out over city.stand_in_fade_s (a dither on the box), so the two
## window patterns cross instead of flipping. Only the stream swap: a building the rampage touches
## (carved, broken, falling) loses its box at once (D-326). Presentation only; the clock is the
## frame delta, never a wall clock.

var _seconds: float
var _age: Dictionary = {}  # building index -> seconds since its mesh arrived


func _init(buildings: Array[RampageSim.Building], city: Dictionary) -> void:
	super(buildings)
	_seconds = Num.f(city.get("stand_in_fade_s", 0.0))


## Building n's mesh arrived: its box dissolves out when `soft`, else goes now.
func dissolve(n: int, soft: bool) -> void:
	if not soft or _seconds <= 0.0 or _buildings[n].is_rail():
		hide(n)
		return
	_age[n] = 0.0
	fade(n, 1.0)


## Advance every dissolving box by `delta` seconds; a finished one is hidden.
func step(delta: float) -> void:
	for n: int in _age.keys():
		var age: float = _age[n] + delta
		if age >= _seconds:
			_age.erase(n)
			hide(n)
		else:
			_age[n] = age
			fade(n, 1.0 - age / _seconds)


## The rampage touched building n: a box still dissolving goes now (D-326).
func touch(n: int) -> void:
	if _age.erase(n):
		hide(n)


## Building n is a box again (its mesh was freed): the box comes back whole.
func show(n: int) -> void:
	_age.erase(n)
	fade(n, 1.0)
	super.show(n)
