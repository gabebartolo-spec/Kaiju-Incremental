class_name AirWing
extends RefCounted
## Military helicopters (D-037): once the kaiju has done enough damage they arrive, circle it
## and strafe it. A kaiju reaches them only when it stands tall enough (a grown body or a
## climbed roof) or with an attack that reaches the air (fire, ink, tentacles); a cephalopod
## can pluck one out of the sky. Part of RampageSim. Pure and seeded.


class Heli:
	var id: int
	var angle: float
	var radius: float
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
	_spawn_timer -= dt
	if _spawn_timer <= 0.0 and helis.size() < cap():
		_spawn_timer = Num.f(cfg["interval"])
		spawn()
	var coated := false
	for heli: Heli in helis:
		heli.angle += Num.f(cfg["orbit_speed"]) / maxf(1.0, heli.radius) * dt
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
	heli.angle = _rng.randf() * TAU
	heli.radius = Num.f(cfg["orbit_radius"]) * _rng.randf_range(0.8, 1.2) * sim.body_scale()
	heli.pos = orbit_pos(heli)
	heli.hp = Num.f(cfg["hp"])
	heli.cooldown = Num.f(cfg["fire_interval"]) * 1.5
	helis.append(heli)
	sim.events.append({"type": "heli_spawned", "heli": heli.id})
	return heli


## Circling, it dives in twice a lap on a strafing run (down to dive x its circle) and
## swings back out: the moment a tall enough kaiju can swat it.
func orbit_pos(heli: Heli) -> Vector2:
	var dive := Num.f(cfg["dive"])
	var r := heli.radius * (dive + (1.0 - dive) * (0.5 + 0.5 * cos(2.0 * heli.angle)))
	return sim.kaiju_pos + Vector2.from_angle(heli.angle) * r


## An attack's force reaches helicopters only when reaches_air (else they fly too high).
func hit(force: Callable, damage: float, reaches_air: bool) -> void:
	if not reaches_air or helis.is_empty():
		return
	for heli: Heli in helis:
		var k: float = force.call(heli.pos, 0.8)
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
