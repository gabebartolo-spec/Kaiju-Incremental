class_name Dash
extends RefCounted
## The charge (playtest note 4): on the dash button the kaiju bursts forward along its facing,
## a few body lengths in a fraction of a second, its body (BodyContact) smashing every chunk in
## the path and knocking down the tanks and roof squads in the way; then a cooldown. Numbers in
## data/tuning.json "dash". Only a kaiju with a body volume dashes. Part of RampageSim; pure.

## The step() button flag for the dash, beside RampageSim.HELD and ULTIMATE.
const BUTTON := 4

var sim: RampageSim
var body: BodyContact
var cfg: Dictionary
## Seconds until the next dash; seconds left of the one under way.
var ready_in := 0.0
var left := 0.0
var dir := Vector2.ZERO
var dashes := 0
var _speed := 0.0
var _hit: Dictionary = {}  # tank ids this dash already struck


## contact: tuning "contact"; the dash reads its "dash" sub-object (none: no dash).
func _init(p_body: BodyContact, contact: Dictionary) -> void:
	body = p_body
	sim = body.sim
	cfg = contact.get("dash", {})


func on() -> bool:
	return left > 0.0


func available() -> bool:
	return body.active() and not cfg.is_empty()


## Starts a dash when pressed and ready, then carries the body along it. Before the sweep.
func step(dt: float, pressed: bool) -> void:
	ready_in = maxf(0.0, ready_in - dt)
	if pressed and ready_in <= 0.0 and left <= 0.0 and available() and not sim.airborne:
		left = Num.f(cfg["seconds"])
		ready_in = Num.f(cfg["cooldown"])
		dir = sim.facing
		_speed = Num.f(cfg["lengths"]) * body.length() / left
		_hit = {}
		dashes += 1
		sim.events.append({"type": "dash", "from": sim.kaiju_pos, "dir": dir, "seconds": left})
	if left <= 0.0:
		return
	var from := sim.kaiju_pos
	sim.kaiju_pos = sim.clamp_to_arena(from + dir * _speed * minf(dt, left))
	sim.facing = dir
	left -= dt
	_strike(from, sim.kaiju_pos)


## Tanks and roof squads the body passes over this step are knocked down.
func _strike(from: Vector2, to: Vector2) -> void:
	var starts := PackedVector2Array()
	var ends := PackedVector2Array()
	var reaches := PackedFloat32Array()
	for d: Array in body.discs():
		var ahead: Vector2 = dir * Num.f(d[0]) * sim.body_scale()
		starts.append(from + ahead)
		ends.append(to + ahead)
		reaches.append(Num.f(d[1]) * sim.body_scale())
	var force := func(p: Vector2, r: float) -> float:
		for n: int in starts.size():
			var near := Geometry2D.get_closest_point_to_segment(p, starts[n], ends[n])
			if near.distance_to(p) <= reaches[n] + r:
				return 1.0
		return 0.0
	for tank: RampageSim.Tank in sim.tanks:
		if not _hit.has(tank.id) and Num.f(force.call(tank.pos, RampageSim.TANK_RADIUS)) > 0.0:
			_hit[tank.id] = true
			tank.hp -= Num.f(cfg["tank_damage"])
	sim.army_units.splash(force, 0, ceili(sim.reach_top()))  # also clears the dead tanks
