class_name FireSpread
extends RefCounted
## Fire that spreads building to building on its own, once City Ablaze is owned (stat
## fire_spread; D-126, R 26.2-26.3). Each building has a heat meter: a burning building heats its
## neighbours by the gap between them, the wind (Fire Front: fixed per run, D-115) and how well the
## neighbour burns (tuning fire.flammability by style). A building whose heat reaches 1 glows first
## (event fire_glow, glow_seconds, seeded) so the kaiju can still smash it as a firebreak, then
## burns (fire_burning) and burns out to rubble (fire_burnt): every chunk left breaks at once, so no
## burning shell is ever left (#111), and it pays burn_pay of a smash, times a conflagration
## multiplier that climbs with each burn-out and decays, and far_pay far from the kaiju.
## Neighbours come from a grid of footprints built once; each tick touches only the buildings
## that are heating, glowing or burning. Part of SpeciesPowers; pure and seeded (its own stream).

enum State { INTACT, HEATING, GLOWING, BURNING, BURNT }

var sim: RampageSim
var cfg: Dictionary
## Per building: its State, heat (0..1) and the seconds left glowing or burning.
var state := PackedByteArray()
var heat := PackedFloat32Array()
var timer := PackedFloat32Array()
## The payout multiplier from burn-outs in a row (1 = none lately).
var conflagration := 1.0
var burnt_out := 0
## The run's wind, a unit vector on the ground plane (only Fire Front reads it).
var wind := Vector2.RIGHT
var _rng: RandomNumberGenerator
var _reach := 0.0
var _grid := {}  # Vector2i cell -> PackedInt32Array of building indices whose footprint it holds
var _cell := 1.0
var _near := {}  # building -> [PackedInt32Array neighbours, PackedFloat32Array heat a second]
var _active := {}  # building -> true while HEATING, GLOWING or BURNING (insertion order)


## p_cfg: tuning powers.fire.
func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng
	var n := sim.buildings.size()
	state.resize(n)
	heat.resize(n)
	timer.resize(n)
	wind = Vector2.RIGHT.rotated(_rng.randf() * TAU)
	_reach = Num.f(cfg["reach"]) + Num.f(cfg["ember_reach"]) * sim.stat("fire_embers")
	_cell = Num.f(cfg["grid"])
	for i: int in n:
		var r := _rect(i)
		for x: int in range(floori(r.position.x / _cell), floori(r.end.x / _cell) + 1):
			for z: int in range(floori(r.position.y / _cell), floori(r.end.y / _cell) + 1):
				var key := Vector2i(x, z)
				var list: PackedInt32Array = _grid.get(key, PackedInt32Array())
				list.append(i)
				_grid[key] = list


## Whether fire spreads this run (City Ablaze owned).
func on() -> bool:
	return sim.stat("fire_spread") > 0.0


## Building i catches fire now (a burning coat reached it, or a blast): it burns, and heats its
## neighbours, until it burns out. Nothing happens without City Ablaze or once it has burnt.
func ignite(i: int) -> void:
	if not on() or state[i] >= State.BURNING or not _can_burn(i):
		return
	_burn(i)


## An explosive site went off at `at` (Firestorm, D-126): every building within `radius` catches.
func blast(at: Vector2, radius: float) -> void:
	if sim.stat("firestorm") <= 0.0:
		return
	var r := radius * (1.0 + Num.f(cfg["firestorm_grow"]) * (sim.stat("firestorm") - 1.0))
	for i: int in _around(Rect2(at - Vector2.ONE * r, Vector2.ONE * r * 2.0), 0.0):
		if _gap(_rect(i), Rect2(at, Vector2.ZERO)) <= r:
			ignite(i)


func step(dt: float) -> void:
	conflagration = maxf(1.0, conflagration - Num.f(cfg["conflag_decay"]) * dt)
	if _active.is_empty() or not on():
		return
	var warmed := {}
	var keys := _active.keys()
	for i: int in keys:
		if state[i] == State.BURNING:
			_heat_neighbours(i, dt, warmed)
	for i: int in keys:
		if sim.buildings[i].frame.alive_count == 0:  # smashed first: nothing left to burn
			_drop(i, State.BURNT)
			continue
		match state[i]:
			State.HEATING:
				_heating(i, dt, warmed.has(i))
			State.GLOWING:
				timer[i] -= dt
				if timer[i] <= 0.0:
					_burn(i)
			State.BURNING:
				timer[i] -= dt
				if timer[i] <= 0.0:
					_burn_out(i)


func _heat_neighbours(i: int, dt: float, warmed: Dictionary) -> void:
	var near: Array = _near.get(i, [])
	if near.is_empty():
		near = _neighbours(i)
		_near[i] = near
	var who: PackedInt32Array = near[0]
	var rate: PackedFloat32Array = near[1]
	for k: int in who.size():
		var j := who[k]
		if state[j] > State.HEATING:
			continue
		if state[j] == State.INTACT:
			state[j] = State.HEATING
			_active[j] = true
		heat[j] += rate[k] * dt
		warmed[j] = true


func _heating(i: int, dt: float, warmed: bool) -> void:
	if not warmed:
		heat[i] -= Num.f(cfg["cool_rate"]) * dt
		if heat[i] <= 0.0:
			heat[i] = 0.0
			_drop(i, State.INTACT)
		return
	if heat[i] < 1.0:
		return
	var glow: Array = cfg["glow_seconds"]
	state[i] = State.GLOWING
	timer[i] = _rng.randf_range(Num.f(glow[0]), Num.f(glow[1]))
	sim.events.append({"type": "fire_glow", "building": i, "seconds": timer[i]})


func _burn(i: int) -> void:
	var b := sim.buildings[i]
	state[i] = State.BURNING
	heat[i] = 1.0
	timer[i] = Num.f(cfg["burn_seconds"]) + Num.f(cfg["burn_per_floor"]) * b.height
	_active[i] = true
	sim.events.append({"type": "fire_burning", "building": i, "seconds": timer[i]})


## Every chunk left breaks at once (rubble, never a burning shell), paying burn_pay of a smash
## times the conflagration, and far_pay of that when the kaiju is far away.
func _burn_out(i: int) -> void:
	var b := sim.buildings[i]
	var cells: Array[Vector3i] = []
	for y: int in b.height:
		for x: int in b.w:
			for z: int in b.d:
				cells.append(Vector3i(x, y, z))
	var amounts := PackedFloat32Array()
	amounts.resize(cells.size())
	amounts.fill(Num.f(cfg["burn_out_damage"]))
	var share := Num.f(cfg["burn_pay"]) * conflagration
	if Vector2(b.x, b.z).distance_to(sim.kaiju_pos) > Num.f(cfg["far_radius"]):
		share *= Num.f(cfg["far_pay"])
	var before := sim.rubble
	sim.damage_cells(i, cells, amounts)
	var paid := (sim.rubble - before) * share
	sim.rubble = before + paid
	burnt_out += 1
	conflagration = minf(Num.f(cfg["conflag_max"]), conflagration + Num.f(cfg["conflag_step"]))
	_drop(i, State.BURNT)
	sim.events.append({"type": "fire_burnt", "building": i, "paid": paid})


func _drop(i: int, to: State) -> void:
	state[i] = to
	_active.erase(i)


func _can_burn(i: int) -> bool:
	var b := sim.buildings[i]
	return b.frame.alive_count > 0 and (b.landmark == "" or cfg["spread_landmarks"] == true)


## The buildings within reach of i and the heat a second each takes from it burning: gap
## closeness x Five-Alarm x Fire Front downwind x the neighbour's flammability.
func _neighbours(i: int) -> Array:
	var who := PackedInt32Array()
	var rate := PackedFloat32Array()
	var from := _rect(i)
	var base := Num.f(cfg["heat_rate"]) * (1.0 + sim.stat("fire_rate"))
	var flammable: Array = cfg["flammability"]
	for j: int in _around(from, _reach):
		if j == i or not _can_burn(j):
			continue
		var gap := _gap(from, _rect(j))
		if gap > _reach:
			continue
		var b := sim.buildings[j]
		var to := (Vector2(b.x, b.z) - from.get_center()).normalized()
		var downwind := 1.0 + sim.stat("fire_wind") * maxf(0.0, to.dot(wind))
		var burns := Num.f(flammable[posmod(b.style, flammable.size())])
		who.append(j)
		rate.append(base * (1.0 - gap / maxf(_reach, 0.001)) * downwind * burns)
	return [who, rate]


## Every building whose footprint shares a grid cell with `area` grown by `margin`, once each,
## lowest index first (the same order every run).
func _around(area: Rect2, margin: float) -> PackedInt32Array:
	var r := area.grow(margin)
	var seen := {}
	for x: int in range(floori(r.position.x / _cell), floori(r.end.x / _cell) + 1):
		for z: int in range(floori(r.position.y / _cell), floori(r.end.y / _cell) + 1):
			for j: int in _grid.get(Vector2i(x, z), PackedInt32Array()):
				seen[j] = true
	var out := PackedInt32Array(seen.keys())
	out.sort()
	return out


func _rect(i: int) -> Rect2:
	var b := sim.buildings[i]
	return Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)


## The ground gap between two footprints (0 when they touch or overlap).
static func _gap(a: Rect2, b: Rect2) -> float:
	var dx := maxf(0.0, maxf(a.position.x - b.end.x, b.position.x - a.end.x))
	var dz := maxf(0.0, maxf(a.position.y - b.end.y, b.position.y - a.end.y))
	return Vector2(dx, dz).length()
