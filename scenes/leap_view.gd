class_name LeapView
extends RefCounted
## What the player sees and hears of the croc's leap (Dash, the dash button): dust and a whoosh at
## take-off, and at the contact the stomp's ring look (one look per effect family), its cracks,
## the street crushed under the ring, the landing sound and a camera kick. The body rides the
## sim's root path (Dash.height); its pose is a hook (KaijuModel.leap) the Cascadeur clip fills
## (K2): until then the rig holds its standing pose through the leap's phases. Presentation only;
## the sim decided where, when and what broke.

var _rampage: Rampage
var _city: CityView


func bind(rampage: Rampage, city: CityView) -> void:
	_rampage = rampage
	_city = city


## Any sim event: it acts on "leap_off" and "leap_land" (the crouch's "leap" is the roar's).
func on_event(event: Dictionary) -> void:
	var r := _rampage
	var bs := r.sim.body_scale()
	match str(event["type"]):
		"leap_off":
			var from: Vector2 = event["at"]
			_city.fx.dust(Vector3(from.x, 0.3, from.y), bs * 2.0)
			r.sfx.play("leap_whoosh")
		"leap_land":
			var at2: Vector2 = event["at"]
			var at := Vector3(at2.x, 0.0, at2.y)
			var radius := Num.f(event["radius"])
			_city.fx.shockwave(at, radius * 1.3 * Fx.STOMP_RING, false, true)
			var base: Dictionary = r.species["stats"]  # as heavy as the blow is to a stomp
			var heavy := r.ability_fx.power(Num.f(event["damage"]), Num.f(base["stomp_damage"]))
			r.ability_fx.stomp_cracks(at, radius, heavy)
			_city.crush(at, radius)
			r.sfx.play("leap_land")
			r.add_trauma(r.shake.source("leap_land"), at)


## One frame: the pose hook gets the phase under way and how far through it the leap is.
func update(kaiju: KaijuModel) -> void:
	var dash := _rampage.sim.body.dash
	if dash.on():
		kaiju.leap(dash.phase(), dash.phase_t())
