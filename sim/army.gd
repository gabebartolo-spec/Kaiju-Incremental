class_name Army
extends RefCounted
## The tanks: they arrive faster the more the city falls, roll in to range and shell the kaiju
## (or the nearest young of a brood, if one is closer). Coated tanks burn. Part of RampageSim;
## the tanks themselves live in sim.tanks. Draws from the army's own seeded stream.

var sim: RampageSim
var cfg: Dictionary
var _rng: RandomNumberGenerator
var _spawn_timer: float
var _next_id := 0


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = sim.army
	_rng = rng
	_spawn_timer = Num.f(cfg["start_interval"])


func step(dt: float) -> void:
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn()
		_spawn_timer = maxf(
			Num.f(cfg["min_interval"]),
			Num.f(cfg["start_interval"]) - Num.f(cfg["escalation_per_chunk"]) * sim.chunks_destroyed
		)
	var reach := Num.f(cfg["range"]) + sim.stomp_radius()
	var coated := false
	for tank: RampageSim.Tank in sim.tanks:
		if tank.coat_t > 0.0:
			tank.coat_t -= dt
			tank.hp -= tank.coat_dps * dt
			coated = true
		var to := sim.kaiju_pos - tank.pos
		var dist := to.length()
		if dist > reach:
			tank.pos += to / dist * Num.f(cfg["speed"]) * dt
		tank.cooldown -= dt
		if tank.cooldown > 0.0:
			continue
		# A young of the brood nearer than the kaiju draws the fire instead.
		var young := sim.brood.nearest_young(tank.pos, minf(dist, reach + 1.0))
		if young != null:
			tank.cooldown = Num.f(cfg["fire_interval"])
			young.hp -= Num.f(cfg["tank_damage"]) * Num.f(cfg["young_damage_mult"])
			sim.events.append({"type": "tank_fired", "tank": tank.id, "at": young.pos})
		elif dist <= reach + 1.0:
			tank.cooldown = Num.f(cfg["fire_interval"])
			var hurt := Num.f(cfg["tank_damage"]) - sim.stat("armor")
			sim.hp -= maxf(Num.f(cfg["min_damage"]), hurt)
			sim.events.append({"type": "tank_fired", "tank": tank.id})
	if coated:
		clear_dead()


func _spawn() -> void:
	var tank := RampageSim.Tank.new()
	tank.id = _next_id
	_next_id += 1
	# Tanks roll in from round the kaiju, not from the far edge of a grown city (D-039).
	var angle := _rng.randf() * TAU
	var at := sim.kaiju_pos + Vector2(cos(angle), sin(angle)) * Num.f(cfg["spawn_radius"])
	tank.pos = sim.clamp_to_arena(at)
	var threat := 1.0 + Num.f(cfg["threat_per_chunk"]) * sim.chunks_destroyed
	tank.hp = Num.f(cfg["tank_hp"]) * threat
	tank.cooldown = Num.f(cfg["fire_interval"])
	sim.tanks.append(tank)
	sim.events.append({"type": "tank_spawned", "tank": tank.id})


func clear_dead() -> void:
	var alive: Array[RampageSim.Tank] = []
	for tank: RampageSim.Tank in sim.tanks:
		if tank.hp > 0.0:
			alive.append(tank)
		else:
			sim.tanks_destroyed += 1
			sim.rubble += Num.f(cfg["tank_rubble"]) * sim.stat("rubble_mult")
			sim.events.append(
				{"type": "tank_destroyed", "tank": tank.id, "x": tank.pos.x, "z": tank.pos.y}
			)
	sim.tanks = alive
