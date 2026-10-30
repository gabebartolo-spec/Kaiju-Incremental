class_name TaskforceMechs
extends RefCounted
## The Taskforce's walking mechs (D-143, D-145, D-152), adult city only: knee-high machines, a few
## at a time, walk the tanks' roads (RoadGraph) toward the kaiju and stop at `standoff`. From
## there each fires laser-bomb volleys: electric-blue target rings appear round the kaiju and the
## bombs land `warn` seconds later, hurting him if he still stands in a ring and breaking the city
## under it. Any blow of his that reaches a mech kills it (one stomp, claw swipe or the Thunder
## Beam), and so does a toppled tower falling on it; a dead mech blows up, breaking the buildings
## round it, and pays biomass. Part of Taskforce; pure and seeded. Events: mech_spawned,
## mech_volley (rings), mech_bomb, mech_died.


class Mech:
	var id: int
	var pos := Vector2.ZERO
	var node := -1  # the road node it walks to
	var prev := -1  # the node it came from (it does not turn back unless it must)
	var facing := Vector2.RIGHT
	var volley_cd := 0.0
	var walking := true


var sim: RampageSim
var cfg: Dictionary
var mechs: Array[Mech] = []
## Bombs on their way down: [seconds left, where (x, z)].
var bombs: Array[Array] = []
var kills := 0
var _rng: RandomNumberGenerator
var _timer: float
var _next_id := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng
	_timer = Num.f(cfg["first_delay"])


## How many may walk at once in this city (none before the adult city).
func cap() -> int:
	var by_tier: Array = cfg["max_by_tier"]
	return Num.i(by_tier[clampi(sim.size_tier() - 1, 0, by_tier.size() - 1)])


## `open`: the Taskforce has joined this rampage (Taskforce.step's gate); `escalation` shortens
## the wait between mechs the more of the city has fallen.
func step(dt: float, open: bool) -> void:
	if open and cap() > 0:
		_timer -= dt
		if _timer <= 0.0 and mechs.size() < cap():
			_timer = maxf(
				Num.f(cfg["min_interval"]),
				Num.f(cfg["start_interval"]) - Num.f(cfg["escalation_per_chunk"]) * sim.escalation()
			)
			spawn()
	_land_bombs(dt)
	for mech: Mech in mechs:
		mech.volley_cd = maxf(0.0, mech.volley_cd - dt)
		var dist := mech.pos.distance_to(sim.kaiju_pos)
		mech.facing = (sim.kaiju_pos - mech.pos).normalized() if dist > 0.01 else mech.facing
		mech.walking = dist > Num.f(cfg["standoff"])
		if mech.walking:
			_walk(mech, dt)
		if mech.volley_cd <= 0.0 and dist <= Num.f(cfg["range"]):
			mech.volley_cd = Num.f(cfg["volley_cooldown"])
			_volley(mech)


## A mech walks in at a road entry on a seeded bearing (none when no entry is free of the kaiju).
func spawn() -> Mech:
	var graph := sim.army_units.convoy.graph
	var bearing := _rng.randf() * TAU
	var n := graph.pick_entry(
		bearing, sim.kaiju_pos, Num.f(sim.army["spawn_radius"]), Num.f(cfg["standoff"])
	)
	if n < 0:
		return null
	return place(graph.nodes[n], n)


## A mech standing at `at`, walking to road node `node` (spawn, and the tests' way to place one).
func place(at: Vector2, node: int) -> Mech:
	var mech := Mech.new()
	mech.id = _next_id
	_next_id += 1
	mech.pos = at
	mech.node = node
	mech.volley_cd = Num.f(cfg["volley_cooldown"]) * Num.f(cfg["first_charge"])
	mechs.append(mech)
	sim.events.append({"type": "mech_spawned", "mech": mech.id, "x": at.x, "z": at.y})
	return mech


## An area blow (RampageSim.hit_area's force over ground points) kills every mech it reaches.
func hit(force: Callable, damage: float) -> void:
	if damage <= 0.0:
		return
	var down: Array[Mech] = []
	for mech: Mech in mechs:
		if Num.f(force.call(mech.pos, Num.f(cfg["radius"]))) > 0.0:
			down.append(mech)
	for mech: Mech in down:
		_kill(mech, "smashed")


## A toppled tower lands on the strip `in_strip` (Callable(p, r) -> bool): every mech under it dies.
func crush(in_strip: Callable) -> void:
	var down: Array[Mech] = []
	for mech: Mech in mechs:
		if in_strip.call(mech.pos, Num.f(cfg["radius"])):
			down.append(mech)
	for mech: Mech in down:
		_kill(mech, "crushed")


## What a kill pays: `rubble_share` of a tank's biomass in this city.
func kill_pay() -> float:
	return Num.f(sim.army["tank_rubble"]) * Num.f(cfg["rubble_share"]) * sim.stat("rubble_mult")


## Along its road to its node; at the node, on to the linked node nearest the kaiju (never back
## the way it came unless that is the only road open).
func _walk(mech: Mech, dt: float) -> void:
	var graph := sim.army_units.convoy.graph
	if mech.node < 0:
		return
	var goal := graph.nodes[mech.node]
	var step := Num.f(cfg["speed"]) * dt
	if mech.pos.distance_to(goal) > step:
		mech.pos += (goal - mech.pos).normalized() * step
		return
	mech.pos = goal
	var best := -1
	var best_d := INF
	for e: int in graph.links[mech.node]:
		if graph.blocked[e] != 0:
			continue
		var far := graph.edge_b[e] if graph.edge_a[e] == mech.node else graph.edge_a[e]
		var d := graph.nodes[far].distance_to(sim.kaiju_pos) + (INF if far == mech.prev else 0.0)
		if d < best_d or best < 0:
			best_d = d
			best = far
	mech.prev = mech.node
	mech.node = best


## Rings round the kaiju: one on his feet, the rest a seeded `spread` round him.
func _volley(mech: Mech) -> void:
	var rings: Array[Vector2] = [sim.kaiju_pos]
	for _n: int in Num.i(cfg["bombs"]) - 1:
		var off := Vector2.from_angle(_rng.randf() * TAU) * _rng.randf() * Num.f(cfg["spread"])
		rings.append(sim.kaiju_pos + off)
	for at: Vector2 in rings:
		bombs.append([Num.f(cfg["warn"]), at])
	sim.events.append(
		{
			"type": "mech_volley",
			"mech": mech.id,
			"rings": rings,
			"radius": cfg["bomb_radius"],
			"warn": cfg["warn"]
		}
	)


func _land_bombs(dt: float) -> void:
	var falling: Array[Array] = []
	for bomb: Array in bombs:
		bomb[0] = Num.f(bomb[0]) - dt
		if Num.f(bomb[0]) > 0.0:
			falling.append(bomb)
			continue
		var at: Vector2 = bomb[1]
		var hit := sim.kaiju_pos.distance_to(at) <= Num.f(cfg["bomb_radius"])
		var damage := sim.max_hp * Num.f(cfg["bomb_share"]) if hit else 0.0
		sim.hp -= damage
		sim.events.append({"type": "mech_bomb", "x": at.x, "z": at.y, "hit": hit, "damage": damage})
		_blast(at, Num.f(cfg["bomb_radius"]), Num.f(cfg["bomb_damage"]), Num.i(cfg["bomb_floors"]))
	bombs = falling


## Breaks the city round `at` (buildings only: a blast never chains through other units).
func _blast(at: Vector2, radius: float, damage: float, floors: int) -> void:
	StrayShell.hit_buildings(
		sim,
		func(p: Vector2, r: float) -> float:
			return RampageSim.falloff(p.distance_to(at) - r, radius),
		damage,
		Vector2i(0, floors)
	)


func _kill(mech: Mech, kind: String) -> void:
	if not mechs.has(mech):  # a blast's topple already took it
		return
	mechs.erase(mech)
	kills += 1
	sim.rubble += kill_pay()
	sim.events.append(
		{"type": "mech_died", "mech": mech.id, "kind": kind, "x": mech.pos.x, "z": mech.pos.y}
	)
	_blast(
		mech.pos, Num.f(cfg["death_radius"]), Num.f(cfg["death_damage"]), Num.i(cfg["death_floors"])
	)
