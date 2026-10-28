class_name SlamView
extends RefCounted
## What the player sees and hears of the croc's slam (Momentum.slam, D-337: "collide with a bang
## into bigger ones"): the bang, a camera kick sized by the slam's strength, and the building he
## hit shuddering along the blow, easing out (slam_fx). Presentation only; the sim decided the
## slam, its dent and the stop.

var _rampage: Rampage
var _city: CityView
var _cfg: Dictionary
var _tweens: Dictionary = {}  # building index -> its shudder now
var _rest: Dictionary = {}  # building index -> where its view stands still


func bind(rampage: Rampage, city: CityView) -> void:
	_rampage = rampage
	_city = city
	_cfg = Content.section("slam_fx")


## Any sim event: it acts on "slam".
func on_event(event: Dictionary) -> void:
	if str(event["type"]) != "slam":
		return
	var r := _rampage
	var at: Vector3 = event["at"]
	var strength := Num.f(event["strength"])
	r.sfx.play(str(_cfg["sound"]))
	r.add_trauma(r.shake.source("slam") * strength, at)
	_shudder(Num.i(event["building"]), at, strength)


## The building swings along the blow (contact to its middle) and back, each swing smaller.
func _shudder(index: int, at: Vector3, strength: float) -> void:
	var view := _city.building(index)
	var b := _rampage.sim.buildings[index]
	var along := Vector3(b.x - at.x, 0.0, b.z - at.z).normalized()
	if not _rest.has(index):
		_rest[index] = view.position
	var rest: Vector3 = _rest[index]
	var old: Tween = _tweens.get(index, null)
	if old != null:
		old.kill()
	var amp := Num.f(_cfg["shudder"]) * strength
	var half := 0.5 / Num.f(_cfg["shudder_hz"])
	var swings := maxi(1, ceili(Num.f(_cfg["shudder_s"]) / half))
	var tween := view.create_tween()
	for n: int in swings:
		var side := 1.0 if n % 2 == 0 else -1.0
		var k := 1.0 - float(n) / swings
		tween.tween_property(view, "position", rest + along * amp * k * side, half)
	tween.tween_property(view, "position", rest, half)
	_tweens[index] = tween
