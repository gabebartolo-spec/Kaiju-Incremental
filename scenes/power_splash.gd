class_name PowerSplash
extends RefCounted
## The powers that only mark the city (split out of PowersView to keep files small): a glide's
## dust and landing, the brood's eggs, hatching, bites and deaths, a throw's landing, the ink
## ring. Presentation only.


## Plays `event` on `city` if it is one of these (bs: the kaiju's body scale); false otherwise.
static func play(city: CityView, event: Dictionary, kaiju_at: Vector3, bs: float) -> bool:
	match str(event["type"]):
		"glide_start":
			city.fx.dust(kaiju_at + Vector3(0, 0.3, 0), bs * 1.5)
		"glide_land":
			city.fx.shockwave(kaiju_at, Num.f(event["reach"]) * 1.2)
			city.crush(kaiju_at, Num.f(event["reach"]))
		"eggs_laid":
			var eggs: Array = event["at"]
			for at: Vector2 in eggs:
				city.fx.puff(_ground(at, 0.3))
		"brood_hatched":
			city.fx.puff(_ground(event["at"], 0.4))
		"brood_bite":
			var at: Vector2 = event["at"]
			city.crush(_ground(at), 1.6)  # the young eat the people and police where they bite
			city.fx.puff(_ground(at, 0.5))
		"brood_died":
			city.debris(_ground(event["at"], 0.6), PowersView.YOUNG, Vector3.UP)
		"throw_land":
			var at := _ground(event["at"])
			var radius := Num.f(event["radius"])
			city.flash(at + Vector3(0, 1.0, 0), Color("ff8a3a"), 9.0, 0.5)
			city.fx.shockwave(at, radius * 1.3)
			city.fx.dust(at + Vector3(0, 0.4, 0), radius * 0.6)
			city.fire(at, 0.6)
			city.crush(at, radius)
		"ink":
			city.ring(kaiju_at, Num.f(event["reach"]), PowersView.INK, 0.8)
		_:
			return false
	return true


## Ground point (a sim Vector2, typed or straight from an event) at height y.
static func _ground(value: Variant, y: float = 0.0) -> Vector3:
	var p: Vector2 = value
	return Vector3(p.x, y, p.y)
