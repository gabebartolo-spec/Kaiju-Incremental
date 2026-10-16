class_name RampageSim
extends RefCounted
## One rampage, as pure simulation: the kaiju, the city's buildings, the army. Presentation
## feeds input to step() and draws the events it returns; it never decides an outcome.
## Coordinates are the ground plane: Vector2(x, z).


class Building:
	var x: float
	var z: float
	var w: int
	var d: int
	var height: int
	var tier: int
	var style: int
	var layers: int
	var pool: float = 0.0
	var layer_hp: float


class Tank:
	var id: int
	var pos: Vector2
	var hp: float
	var cooldown: float


var stats: Dictionary
var army: Dictionary
var city: Dictionary
var ability_type := "ring"
var buildings: Array[Building] = []
var tanks: Array[Tank] = []
var kaiju_pos := Vector2.ZERO
var facing := Vector2(0, -1)
var hp: float
var max_hp: float
var time_left: float
var rubble: float = 0.0
var layers_destroyed := 0
var layers_total := 0
var tanks_destroyed := 0
var ability_ready_in := 0.0
var over := false
var end_reason := ""
var arena_half: float
var _rng: RandomNumberGenerator
var _spawn_timer: float
var _stomp_timer := 0.0
var _next_tank_id := 0
var _events: Array[Dictionary] = []


## Set ability_type ("cone", "leap" or "ring") before the first step.
func _init(
	p_stats: Dictionary, tuning: Dictionary, layout: Array[Dictionary], rng: RandomNumberGenerator
) -> void:
	stats = p_stats
	army = tuning["army"]
	city = tuning["city"]
	_rng = rng
	hp = stat("hp")
	max_hp = hp
	time_left = stat("run_seconds")
	_spawn_timer = Num.f(army["start_interval"])
	for entry: Dictionary in layout:
		var b := Building.new()
		b.x = Num.f(entry["x"])
		b.z = Num.f(entry["z"])
		b.w = Num.i(entry["w"])
		b.d = Num.i(entry["d"])
		b.height = Num.i(entry["h"])
		b.tier = Num.i(entry["tier"])
		b.style = Num.i(entry["style"])
		b.layers = b.height
		b.layer_hp = Num.f(city["layer_hp"]) * b.tier * (b.w * b.d) / 9.0
		buildings.append(b)
		layers_total += b.height
	var city_half := CityGen.half_extent(city)
	arena_half = city_half + Num.f(city["spacing"]) * 2.0
	kaiju_pos = Vector2(0.0, city_half + Num.f(city["spacing"]))


func stat(stat_name: String) -> float:
	return Num.f(stats.get(stat_name, 0.0))


func size_tier() -> int:
	return Num.i(stat("size"))


## How big the kaiju is drawn and how far its attacks reach, from its size tier.
func body_scale() -> float:
	return 1.0 + Num.f(city["size_scale_per_tier"]) * (stat("size") - 1.0)


func stomp_radius() -> float:
	return stat("stomp_radius") * body_scale()


func ability_reach() -> float:
	return stat("ability_range") * body_scale()


func destruction() -> float:
	return Num.f(layers_destroyed) / maxf(1.0, Num.f(layers_total))


func result() -> Dictionary:
	return {
		"rubble": Num.i(floor(rubble)),
		"destruction": destruction(),
		"tanks": tanks_destroyed,
		"reason": end_reason,
	}


## Advances the rampage by dt with the player's move vector and signature button.
## Returns the events of this step for presentation.
func step(dt: float, move: Vector2, signature_pressed: bool) -> Array[Dictionary]:
	_events = []
	if over:
		return _events
	time_left -= dt
	hp = minf(max_hp, hp + stat("regen") * dt)
	if move.length() > 0.05:
		var dir := move.limit_length(1.0)
		kaiju_pos = _clamp_to_arena(kaiju_pos + dir * stat("speed") * dt)
		facing = dir.normalized()
	_stomp_timer -= dt
	if _stomp_timer <= 0.0:
		_stomp_timer += maxf(0.1, stat("stomp_interval"))
		_stomp()
	ability_ready_in = maxf(0.0, ability_ready_in - dt)
	if signature_pressed and ability_ready_in <= 0.0:
		ability_ready_in = maxf(0.5, stat("ability_cooldown"))
		_signature()
	_step_army(dt)
	if layers_destroyed >= layers_total:
		_end("city_fallen")
	elif hp <= 0.0:
		_end("defeated")
	elif time_left <= 0.0:
		_end("time")
	return _events


func _end(reason: String) -> void:
	over = true
	end_reason = reason
	hp = maxf(0.0, hp)
	_events.append({"type": "run_over", "reason": reason})


func _clamp_to_arena(pos: Vector2) -> Vector2:
	return pos.clamp(Vector2(-arena_half, -arena_half), Vector2(arena_half, arena_half))


func _stomp() -> void:
	var radius := stomp_radius()
	var centre := kaiju_pos
	_events.append({"type": "stomp", "radius": radius})
	_hit_area(
		func(p: Vector2, r: float) -> bool: return p.distance_to(centre) <= radius + r,
		stat("stomp_damage")
	)


func _signature() -> void:
	var reach := ability_reach()
	var damage := stat("ability_damage")
	match ability_type:
		"cone":
			var half_angle := deg_to_rad(Num.f(city["cone_half_angle_deg"]))
			var origin := kaiju_pos
			var dir := facing
			_events.append({"type": "ability", "kind": "cone", "reach": reach})
			_hit_area(
				func(p: Vector2, r: float) -> bool:
					var to := p - origin
					if to.length() > reach + r:
						return false
					return to.length() <= r or absf(dir.angle_to(to)) <= half_angle,
				damage
			)
		"leap":
			var from := kaiju_pos
			kaiju_pos = _clamp_to_arena(
				kaiju_pos + facing * Num.f(city["leap_distance"]) * body_scale()
			)
			var land := kaiju_pos
			_events.append({"type": "ability", "kind": "leap", "reach": reach, "from": from})
			_hit_area(
				func(p: Vector2, r: float) -> bool: return p.distance_to(land) <= reach + r, damage
			)
		_:
			var centre := kaiju_pos
			_events.append({"type": "ability", "kind": "ring", "reach": reach})
			_hit_area(
				func(p: Vector2, r: float) -> bool: return p.distance_to(centre) <= reach + r,
				damage
			)


## Damages every standing building and tank for which hits(position, own radius) is true.
func _hit_area(hits: Callable, damage: float) -> void:
	for i: int in buildings.size():
		var b := buildings[i]
		var inside: bool = hits.call(Vector2(b.x, b.z), maxf(b.w, b.d) * 0.5)
		if b.layers > 0 and inside:
			damage_building(i, damage)
	for tank: Tank in tanks:
		var struck: bool = hits.call(tank.pos, 0.6)
		if struck:
			tank.hp -= damage
	_clear_dead_tanks()


## Applies damage to a building; a building above the kaiju's size tier barely feels it.
## Returns the voxel layers it lost.
func damage_building(index: int, amount: float) -> int:
	var b := buildings[index]
	if b.layers <= 0:
		return 0
	var mult := 1.0 if b.tier <= size_tier() else Num.f(city["under_tier_mult"])
	b.pool += amount * mult
	var removed := 0
	while b.pool >= b.layer_hp and b.layers > 0:
		b.pool -= b.layer_hp
		b.layers -= 1
		removed += 1
	if removed > 0:
		layers_destroyed += removed
		rubble += removed * b.tier * (b.w * b.d) / 9.0 * stat("rubble_mult")
		_events.append({"type": "layers_destroyed", "building": index, "count": removed})
	elif mult < 1.0:
		_events.append({"type": "too_tall", "building": index})
	return removed


func _step_army(dt: float) -> void:
	_spawn_timer -= dt
	if _spawn_timer <= 0.0:
		_spawn_tank()
		_spawn_timer = maxf(
			Num.f(army["min_interval"]),
			Num.f(army["start_interval"]) - Num.f(army["escalation_per_layer"]) * layers_destroyed
		)
	var reach := Num.f(army["range"]) + stomp_radius()
	for tank: Tank in tanks:
		var to := kaiju_pos - tank.pos
		var dist := to.length()
		if dist > reach:
			tank.pos += to / dist * Num.f(army["speed"]) * dt
		tank.cooldown -= dt
		if dist <= reach + 1.0 and tank.cooldown <= 0.0:
			tank.cooldown = Num.f(army["fire_interval"])
			hp -= maxf(Num.f(army["min_damage"]), Num.f(army["tank_damage"]) - stat("armor"))
			_events.append({"type": "tank_fired", "tank": tank.id})


func _spawn_tank() -> void:
	var tank := Tank.new()
	tank.id = _next_tank_id
	_next_tank_id += 1
	var angle := _rng.randf() * TAU
	tank.pos = _clamp_to_arena(Vector2(cos(angle), sin(angle)) * arena_half * 1.2)
	tank.hp = Num.f(army["tank_hp"]) * (1.0 + Num.f(army["threat_per_layer"]) * layers_destroyed)
	tank.cooldown = Num.f(army["fire_interval"])
	tanks.append(tank)
	_events.append({"type": "tank_spawned", "tank": tank.id})


func _clear_dead_tanks() -> void:
	var alive: Array[Tank] = []
	for tank: Tank in tanks:
		if tank.hp > 0.0:
			alive.append(tank)
		else:
			tanks_destroyed += 1
			rubble += Num.f(army["tank_rubble"]) * stat("rubble_mult")
			_events.append(
				{"type": "tank_destroyed", "tank": tank.id, "x": tank.pos.x, "z": tank.pos.y}
			)
	tanks = alive
