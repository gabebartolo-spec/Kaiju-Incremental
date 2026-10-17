class_name Army
extends RefCounted
## The tanks: they arrive faster the more the city falls, drive in by road to firing positions
## (Convoy, D-066) and shell the kaiju (or the nearest young of a brood, if one is closer) when
## they have a clear line of fire. Coated tanks burn. Part of RampageSim; the tanks themselves
## live in sim.tanks. Draws from the army's own seeded stream.

var sim: RampageSim
var cfg: Dictionary
var _rng: RandomNumberGenerator
var _spawn_timer: float
var _next_id := 0
## Road movement and firing positions (D-066).
var convoy: Convoy
var _column := -1
var _column_left := 0
var _column_entry := -1


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = sim.army
	_rng = rng
	_spawn_timer = Num.f(cfg["start_interval"])
	var convoy_cfg: Dictionary = cfg["convoy"]
	convoy = Convoy.new(sim, convoy_cfg)


func step(dt: float) -> void:
	_spawn_timer -= dt
	if _spawn_timer <= 0.0 and _spawn():
		_spawn_timer = maxf(
			Num.f(cfg["min_interval"]),
			Num.f(cfg["start_interval"]) - Num.f(cfg["escalation_per_chunk"]) * sim.chunks_destroyed
		)
	var reach := Num.f(cfg["range"]) + sim.stomp_radius()
	var coated := false
	convoy.step(dt)
	for tank: RampageSim.Tank in sim.tanks:
		if tank.coat_t > 0.0:
			tank.coat_t -= dt
			tank.hp -= tank.coat_dps * dt
			coated = true
		var dist := tank.pos.distance_to(sim.kaiju_pos)
		tank.cooldown -= dt
		if tank.cooldown > 0.0:
			continue
		# A young of the brood nearer than the kaiju draws the fire instead.
		var young := sim.brood.nearest_young(tank.pos, minf(dist, reach + 1.0))
		if young != null and convoy.clear_line(tank.pos, young.pos):
			tank.cooldown = Num.f(cfg["fire_interval"])
			young.hp -= Num.f(cfg["tank_damage"]) * Num.f(cfg["young_damage_mult"])
			sim.events.append({"type": "tank_fired", "tank": tank.id, "at": young.pos})
		elif dist <= reach + 1.0 and convoy.clear_line(tank.pos, sim.kaiju_pos):
			tank.cooldown = Num.f(cfg["fire_interval"])
			var hurt := Num.f(cfg["tank_damage"]) - sim.stat("armor")
			sim.hp -= maxf(Num.f(cfg["min_damage"]), hurt)
			sim.events.append({"type": "tank_fired", "tank": tank.id})
	if coated:
		clear_dead()


## A tank joins the current column at its road entry, or starts a new column on a seeded
## bearing (D-039: in a city grown past spawn_radius, round the kaiju). False when that way in
## is jammed too: it tries again next step.
func _spawn() -> bool:
	var at := Vector2(INF, INF)
	if _column_left > 0:
		at = convoy.enter(_next_id, _column, _column_entry)
	if at.x == INF:  # a new column, or the way in is still taken: the next column sets off
		_column += 1
		_column_left = Num.i(convoy.cfg["column"])
		_column_entry = convoy.pick_entry(_rng.randf() * TAU)
		at = convoy.enter(_next_id, _column, _column_entry)
	if at.x == INF:
		return false
	_column_left -= 1
	var tank := RampageSim.Tank.new()
	tank.id = _next_id
	_next_id += 1
	tank.pos = at
	var threat := 1.0 + Num.f(cfg["threat_per_chunk"]) * sim.chunks_destroyed
	tank.hp = Num.f(cfg["tank_hp"]) * threat
	tank.cooldown = Num.f(cfg["fire_interval"])
	sim.tanks.append(tank)
	sim.events.append({"type": "tank_spawned", "tank": tank.id})
	return true


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
