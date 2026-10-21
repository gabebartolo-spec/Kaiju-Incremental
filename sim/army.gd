class_name Army
extends RefCounted
## The tanks: they arrive faster the more the city falls, drive in by road to firing positions
## (Convoy, D-066) and shell the kaiju (or the nearest young of a brood, if one is closer) when
## they have a clear line of fire. Coated tanks burn. Part of RampageSim; the tanks themselves
## live in sim.tanks. Draws from the army's own seeded stream.
## Rooftop defenders (D-063): armed citizens hold some of the taller roofs from the start and
## fire rifles at the kaiju in range, a sting far below a tank shell, scaled by its size tier and
## by the same threat the tanks' armour grows with. A squad dies when the roof chunk under it
## goes (broken, dropped or toppled) or under any attack whose splash reaches its roof floor.


## Armed citizens holding a roof: they stand on chunk `cell` of building `building`.
class Squad:
	var id: int
	var building: int
	var cell: Vector3i
	var pos: Vector2
	var cooldown: float
	var dead := false


var sim: RampageSim
var cfg: Dictionary
var rooftop: Dictionary
var squads: Array[Squad] = []
## Rooftop volleys fired this run (D-076: how often the player is shot at).
var volleys := 0
var misses := 0  # tank shells that missed the kaiju and landed in the city
var rooftops_destroyed := 0
## Road movement and firing positions (D-066).
var convoy: Convoy
var _rng: RandomNumberGenerator
## Each squad's next shot comes a seeded, ragged while later (D-076: no unison).
var _ragged: RandomNumberGenerator
var _aim: RandomNumberGenerator  # which shells miss, and where they land (StrayShell)
var _spawn_timer: float
var _next_id := 0
var _column := -1
var _column_left := 0
var _column_entry := -1


func _init(p_sim: RampageSim, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = sim.army
	rooftop = cfg["rooftop"]
	_rng = rng
	_spawn_timer = Num.f(cfg["start_interval"])
	var convoy_cfg: Dictionary = cfg["convoy"]
	convoy = Convoy.new(sim, convoy_cfg)
	_place_squads(Seeds.derive(rng, 0x2007))
	_ragged = Seeds.derive(rng, 0x2008)
	_aim = Seeds.derive(rng, 0x2009)


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
			shoot(tank, dist, reach)
	if _step_squads(dt) or coated:
		clear_dead()


## One shell at the kaiju: a hit (StrayShell.chance) does the shot's damage over that chance; a
## miss lands in the city past the kaiju and breaks what it hits there.
func shoot(tank: RampageSim.Tank, dist: float, reach: float) -> void:
	var odds := StrayShell.chance(cfg, dist, reach)
	if _aim.randf() < odds:
		var hurt := Num.f(cfg["tank_damage"]) - sim.stat("armor")
		sim.hp -= maxf(Num.f(cfg["min_damage"]), hurt) / odds
		sim.events.append({"type": "tank_fired", "tank": tank.id})
		return
	misses += 1
	var at := StrayShell.landing(sim, tank.pos, _aim)
	sim.events.append({"type": "tank_fired", "tank": tank.id, "at": at, "miss": true})
	StrayShell.land(sim, at)


## Each squad whose roof still stands fires a volley every fire_interval while the kaiju is in
## range, measured from the edge of its stomp as the tanks' is (D-076: from its centre, a grown
## kaiju's own reach killed squads before they got a shot). True when a squad lost its roof
## (clear_dead removes it and pays its biomass).
func _step_squads(dt: float) -> bool:
	var lost := false
	var reach := Num.f(rooftop["range"]) + sim.stomp_radius()
	for squad: Squad in squads:
		if not sim.buildings[squad.building].frame.alive(squad.cell):
			squad.dead = true
			lost = true
			continue
		squad.cooldown -= dt
		if squad.cooldown > 0.0 or squad.pos.distance_to(sim.kaiju_pos) > reach:
			continue
		squad.cooldown = _next_shot()
		sim.hp -= volley()
		volleys += 1
		sim.events.append({"type": "rooftop_fired", "squad": squad.id})
	return lost


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
	if squads.any(func(squad: Squad) -> bool: return squad.dead):
		var holding: Array[Squad] = []
		for squad: Squad in squads:
			if not squad.dead:
				holding.append(squad)
				continue
			rooftops_destroyed += 1
			sim.rubble += _by_tier("rooftop_rubble") * sim.stat("rubble_mult")
			var at := sim.buildings[squad.building].chunk_world(squad.cell)
			sim.events.append(
				{
					"type": "rooftop_destroyed",
					"squad": squad.id,
					"x": at.x,
					"y": at.y + 0.5,
					"z": at.z
				}
			)
		squads = holding


## Seconds to a squad's next volley: fire_interval give or take interval_jitter of it, evenly
## (the mean stays fire_interval), so squads never fall into step: improvised, not drilled.
func _next_shot() -> float:
	var jitter := Num.f(rooftop["interval_jitter"]) * (_ragged.randf() * 2.0 - 1.0)
	return Num.f(rooftop["fire_interval"]) * (1.0 + jitter)


## How hard the army fights back: more the more of the city has fallen.
func threat_scale() -> float:
	return 1.0 + Num.f(cfg["threat_per_chunk"]) * sim.chunks_destroyed


## One squad's volley at the kaiju: the size tier's sting, grown by the threat.
func volley() -> float:
	return _by_tier("damage_by_tier") * threat_scale()


## A rooftop entry for the kaiju's size tier (tiers past the list use its last entry).
func _by_tier(key: String) -> float:
	var list: Array = rooftop[key]
	return Num.f(list[clampi(sim.size_tier() - 1, 0, list.size() - 1)])


## Squads take some of the roofs min_height floors and up, each with `chance`, visited in a
## seeded order so they spread over the whole city, up to the size tier's cap. A squad keeps
## off the corner where a roof's stair hut stands.
func _place_squads(rng: RandomNumberGenerator) -> void:
	var cap := roundi(_by_tier("max_by_tier"))
	var tall: Array[int] = []
	for i: int in sim.buildings.size():
		if sim.buildings[i].height >= Num.i(rooftop["min_height"]):
			tall.append(i)
	for n: int in range(tall.size() - 1, 0, -1):  # Fisher-Yates on the army's own stream
		var k := rng.randi_range(0, n)
		var swap := tall[n]
		tall[n] = tall[k]
		tall[k] = swap
	for i: int in tall:
		if squads.size() >= cap:
			break
		if rng.randf() >= Num.f(rooftop["chance"]):
			continue
		var b := sim.buildings[i]
		var cell := Vector3i(rng.randi_range(0, b.w - 1), b.height - 1, rng.randi_range(0, b.d - 1))
		if b.w >= 3 and b.d >= 3 and cell.x < 2 and cell.z < 2:
			cell = Vector3i(b.w - 1, cell.y, b.d - 1)
		var squad := Squad.new()
		squad.id = squads.size()
		squad.building = i
		squad.cell = cell
		var at := b.chunk_world(cell)
		squad.pos = Vector2(at.x, at.z)
		squad.cooldown = rng.randf() * Num.f(rooftop["fire_interval"])
		squads.append(squad)


## An attack on floors y_lo..y_hi-1 kills every squad whose roof floor it reaches and whose
## spot its force touches; then the dead tanks and squads are cleared and paid for.
func splash(force: Callable, y_lo: int, y_hi: int) -> void:
	for squad: Squad in squads:
		if squad.cell.y >= y_lo and squad.cell.y < y_hi:
			var k: float = force.call(squad.pos, Num.f(rooftop["radius"]))
			squad.dead = squad.dead or k > 0.0
	clear_dead()
