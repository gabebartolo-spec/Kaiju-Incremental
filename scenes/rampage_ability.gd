class_name RampageAbility
extends RefCounted
## What the player sees of the signature attack (Rampage hands it each `ability` event): the
## breath, the leap's take-off, flight and landing, the lash; and the croc's leap on the dash button
## (LeapView) and his slam into a building (SlamView). Presentation only; the sim decided it.

const LEAP_SECONDS := 0.4  # s, take-off to landing
const LEAP_ARC := 6.0  # units the body rises over the leap

## The croc's leap on the dash button (Dash): its take-off, landing ring and pose hook.
var leap := LeapView.new()
## The croc's slam at full momentum (Momentum.slam): the bang, the kick, the building's shudder.
var slam := SlamView.new()
var _rampage: Rampage
var _city: CityView
var _kaiju: KaijuModel
var _reach := 0.0
var _power := 1.0
var _time := 0.0
var _from := Vector3.ZERO


func bind(rampage: Rampage, city: CityView, kaiju: KaijuModel) -> void:
	_rampage = rampage
	_city = city
	_kaiju = kaiju
	leap.bind(rampage, city)
	slam.bind(rampage, city)


## Any sim event the leap or the slam draws.
func on_event(event: Dictionary) -> void:
	leap.on_event(event)
	slam.on_event(event)


## Whether the kaiju is in the air of a leap.
func leaping() -> bool:
	return _time > 0.0


## The attack lands in the view: `strength` is the ability_damage upgrade's power (1 = none).
func play(event: Dictionary, kaiju_at: Vector3, strength: float) -> void:
	var r := _rampage
	var sim := r.sim
	var fx := r.ability_fx
	var reach := Num.f(event["reach"])
	r.add_trauma(r.shake.source("ability"))
	_city.crush(_world(sim.kaiju_pos), reach * (0.5 if str(event["kind"]) == "cone" else 1.0))
	match str(event["kind"]):
		"cone":
			var facing := _world(sim.facing)
			var chest := kaiju_at + (Vector3(0, 6.0, 0) + facing) * sim.body_scale()
			var mouth := BreathBeam.mouth_of(_kaiju, chest)  # the jaw, where the model has one
			var from: Vector2 = event["from"]  # the sim's cone (BreathCone) starts at the snout
			var snout := _world(from)
			var span := snout + facing * reach + Vector3(0, 0.5, 0) - mouth  # to full reach
			fx.cone_origin = snout
			fx.breath(mouth, span, fx.cone_half_angle, strength)
			_city.crush_cone(BreathCone.of(sim))  # trees and cars burn flat along it
			r.sfx.play("breath")
		"leap":
			var from: Vector2 = event["from"]
			_from = _world(from)
			_time = 0.0001
			_reach = reach
			_power = strength
			fx.leap_takeoff(_from)
			r.sfx.play("leap_whoosh")
		_:
			fx.lash(kaiju_at, reach, strength)
			r.sfx.play("lash")


## One frame of the drawn kaiju (moved here from Rampage._update_kaiju): where it stands (a glide's
## lift, the croc's leap arc), its heading, the legs on the sim's step clock; `moving` 0..1 how
## hard it walks. Returns where it is drawn.
func place(delta: float, moving: float, at: Vector3) -> Vector3:
	var sim := _rampage.sim
	var target := _world(sim.kaiju_pos)
	var lift := Rampage.GLIDE_LIFT * sim.body_scale() if sim.airborne else 0.0
	target.y = sim.stand_y + (sim.body.dash.height() if sim.body.dash.on() else lift)
	var drawn := step(delta, target, at)
	_kaiju.position = drawn
	_kaiju.rotation.y = atan2(-sim.body.heading.x, -sim.body.heading.y)  # sim angle to yaw: flipped
	var run := sim.powers.run
	_kaiju.follow_steps(sim.body.step_clock(), sim.body.step_ratio, run.blend(), run.slams)
	_kaiju.animate(delta, moving, -sim.body.turn_left)
	return drawn


## One frame: where the kaiju is drawn, flying a leap's arc toward `target` or easing along.
func step(delta: float, target: Vector3, at: Vector3) -> Vector3:
	var r := _rampage
	var sim := r.sim
	leap.update(_kaiju)
	if _time <= 0.0:
		return at.lerp(target, 1.0 if sim.body.dash.on() else minf(1.0, delta * 12.0))
	_time += delta
	var t := clampf(_time / LEAP_SECONDS, 0.0, 1.0)
	var now := _from.lerp(target, t) + Vector3(0, sin(t * PI) * LEAP_ARC, 0)
	r.ability_fx.leap_trail(now + Vector3(0, 3.0 * sim.body_scale(), 0), t < 1.0)
	if t < 1.0:
		return now
	_time = 0.0
	r.ability_fx.leap_land(target, _reach, _power)
	r.sfx.play("leap_land")
	r.add_trauma(r.shake.source("leap_land"))
	return target


func _world(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)
