class_name AirWing
extends RefCounted
## Military helicopters (D-037): once the kaiju has done enough damage they arrive, circle it
## and strafe it. A kaiju reaches them only when it stands tall enough (a grown body or a
## climbed roof) or with an attack that reaches the air (fire, ink, tentacles); a cephalopod
## can pluck one out of the sky. They keep to the far side of the kaiju from the game camera
## (`camera_bearing`, clear of `clear_arc` either side of it) and cruise `clear_margin` beyond
## its body, so a helicopter never hangs between the player and the kaiju. Part of RampageSim.
## Pure and seeded.


class Heli:
	var id: int
	var angle: float
	var turn := 1.0  # which way it sweeps along its arc
	var radius: float  # its circle: sets its speed and how deep it dives
	var cruise: float  # how far out it flies between dives (clear of the kaiju's body)
	var pos: Vector2
	var hp: float
	var cooldown: float
	var coat_t := 0.0
	var coat_dps := 0.0


var sim: RampageSim
var cfg: Dictionary
var helis: Array[Heli] = []
var destroyed := 0
var _rng: RandomNumberGenerator
var _spawn_timer := 0.0
var _next_id := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng


func altitude() -> float:
	return Num.f(cfg["altitude"])


## How many may be up at once: more the more of the city has fallen.
func cap() -> int:
	var after := Num.i(cfg["after_chunks"])
	if sim.chunks_destroyed < after:
		return 0
	var extra := (sim.chunks_destroyed - after) / maxi(1, Num.i(cfg["max_per_chunks"]))
	return mini(Num.i(cfg["max"]), 1 + extra)


func step(dt: float) -> void:
	# The call-in clock only runs while the sky is short of helicopters: a kill is replaced
	# after `interval`, never on the next step.
	if helis.size() < cap():
		_spawn_timer -= dt
		if _spawn_timer <= 0.0:
			_spawn_timer = Num.f(cfg["interval"])
			spawn()
	var coated := false
	for heli: Heli in helis:
		heli.angle += heli.turn * Num.f(cfg["orbit_speed"]) / maxf(1.0, heli.radius) * dt
		_keep_clear(heli)
		heli.pos = orbit_pos(heli)
		if heli.coat_t > 0.0:
			heli.coat_t -= dt
			heli.hp -= heli.coat_dps * dt
			coated = true
		heli.cooldown -= dt
		if heli.cooldown <= 0.0:
			heli.cooldown = Num.f(cfg["fire_interval"])
			var army := sim.army
			var hurt := Num.f(cfg["damage"]) - sim.stat("armor")
			sim.hp -= maxf(Num.f(army["min_damage"]), hurt)
			sim.events.append({"type": "heli_fired", "heli": heli.id})
	if coated:
		clear_dead()


## A new helicopter joins the circle at a seeded angle and distance.
func spawn() -> Heli:
	var heli := Heli.new()
	heli.id = _next_id
	_next_id += 1
	var arc := deg_to_rad(Num.f(cfg["clear_arc"]))
	heli.angle = _bearing() + arc + _rng.randf() * (TAU - 2.0 * arc)
	var jitter := Num.f(cfg["orbit_jitter"])
	var circle := Num.f(cfg["orbit_radius"]) * _rng.randf_range(1.0 - jitter, 1.0 + jitter)
	var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	heli.radius = circle * sim.body_scale()
	heli.cruise = maxf(heli.radius, body + Num.f(cfg["clear_margin"]))
	heli.pos = orbit_pos(heli)
	heli.hp = Num.f(cfg["hp"])
	heli.cooldown = Num.f(cfg["fire_interval"]) * Num.f(cfg["first_burst_delay"])
	helis.append(heli)
	sim.events.append({"type": "heli_spawned", "heli": heli.id})
	return heli


## Sweeping its arc, it dives in on a strafing run at each side of the kaiju (down to dive x
## its circle) and swings back out behind it: the moment a tall enough kaiju can swat it.
func orbit_pos(heli: Heli) -> Vector2:
	var dive := Num.f(cfg["dive"])
	var side := heli.angle - _bearing()
	var low := heli.radius * dive
	var r := low + (heli.cruise - low) * (0.5 + 0.5 * cos(2.0 * side))
	return sim.kaiju_pos + Vector2.from_angle(heli.angle) * r


## The direction from the kaiju toward the game camera, on the ground plane.
func _bearing() -> float:
	return deg_to_rad(Num.f(cfg["camera_bearing"]))


## Turns a helicopter back at either end of its arc, so it never crosses the camera's side.
func _keep_clear(heli: Heli) -> void:
	var arc := deg_to_rad(Num.f(cfg["clear_arc"]))
	var side := wrapf(heli.angle - _bearing(), 0.0, TAU)
	if side < arc:
		heli.angle = _bearing() + arc
		heli.turn = 1.0
	elif side > TAU - arc:
		heli.angle = _bearing() + TAU - arc
		heli.turn = -1.0


## An attack's force reaches helicopters only when reaches_air (else they fly too high).
func hit(force: Callable, damage: float, reaches_air: bool) -> void:
	if not reaches_air or helis.is_empty():
		return
	for heli: Heli in helis:
		var k: float = force.call(heli.pos, Num.f(cfg["heli_radius"]))
		heli.hp -= damage * k
		if k > 0.0 and not sim.hit_coat.is_empty():
			heli.coat_t = Num.f(sim.hit_coat["seconds"])
			heli.coat_dps = Num.f(sim.hit_coat["dps"]) * Num.f(sim.powers_cfg["ink_unit_mult"])
	clear_dead()


func clear_dead() -> void:
	var alive: Array[Heli] = []
	for heli: Heli in helis:
		if heli.hp > 0.0:
			alive.append(heli)
			continue
		destroyed += 1
		sim.rubble += Num.f(cfg["rubble"]) * sim.stat("rubble_mult")
		sim.events.append(
			{"type": "heli_destroyed", "heli": heli.id, "x": heli.pos.x, "z": heli.pos.y}
		)
	helis = alive
