class_name IntroFade
extends RefCounted
## What the run intro fades so nothing in the foreground hides the rise (director comment #27:
## "Nothing in the foreground hides the rise"): the sand shore and the bridges ease down to
## intro "ground_opacity" while the kaiju emerges and back to solid after, at the speed
## BuildingFade fades a building (vehicles "fade_seconds"). Starts faded: no pop-in. Presentation
## only; the tests replay it (fade_spawn) so what is faded does not count as hiding.

var _low: float
var _speed: float
var _now: float


func _init(rising: bool) -> void:
	_low = Num.f(Content.section("intro")["ground_opacity"])
	_speed = 1.0 / Num.f(Content.section("vehicles")["fade_seconds"])
	_now = _low if rising else 1.0


## The opacity after `delta` seconds, the kaiju still emerging (`rising`) or not.
func step(delta: float, rising: bool) -> float:
	_now = move_toward(_now, _low if rising else 1.0, delta * _speed)
	return _now


func opacity() -> float:
	return _now
