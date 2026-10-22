class_name FireSpread
extends RefCounted
## Fire that spreads building to building on its own, once City Ablaze is owned (stat
## fire_spread; D-126, R 26.2-26.3). Each building has a heat meter: a burning building heats its
## neighbours by the gap between them, the wind (Fire Front: fixed per run, D-115) and how well the
## neighbour burns (tuning fire.flammability by style). A building whose heat reaches 1 glows first
## (event fire_glow, glow_seconds, seeded) so the kaiju can still smash it as a firebreak, then
## burns (fire_burning) and burns out (fire_burnt): its ground floors give way and the rest
## collapses and topples like a smashed building (D-129), so no burning shell is ever left (#111).
## What it drops pays burn_pay of a smash, times a conflagration multiplier that climbs with each
## burn-out and decays, and far_pay far from the kaiju. Fires start from the beam's burning coat,
## the breath (scorch) and stray army shells (shelled) once City Ablaze is owned (D-129).
## Neighbours come from a grid of footprints built once; the heat pass runs every spread_tick s
## and touches only the buildings that are heating, glowing or burning. Heat is a plain meter:
## anything that later takes heat away (a fire crew, comment #50) lowers heat[i], and a heating
## building back at 0 is intact again. Part of SpeciesPowers; pure and seeded (its own stream).

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
var _since := 0.0  # seconds since the last heat pass
var _pass := 0  # heat passes so far; _warm[j] == _pass when a fire warmed j this pass
var _warm := PackedInt32Array()
## Buildings giving way: building -> [ground cells still standing, downwind first; cells a tick].
var _crumbling := {}


## p_cfg: tuning powers.fire.
func _init(p_sim: RampageSim, p_cfg: Dictionary, rng: RandomNumberGenerator) -> void:
	sim = p_sim
	cfg = p_cfg
	_rng = rng
	var n := sim.buildings.size()
	state.resize(n)
	heat.resize(n)
	timer.resize(n)
	_warm.resize(n)
	_warm.fill(-1)
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


## The breath swept `area` (D-129): each building `force` (position, own radius -> 0..1) reaches
## catches with chance breath_ignite.
func scorch(area: Rect2, force: Callable) -> void:
	if not on():
		return
	var chance := Num.f(cfg["breath_ignite"])
	for i: int in _around(area, 0.0):
		var b := sim.buildings[i]
		var near: float = force.call(Vector2(b.x, b.z), Vector2(b.w, b.d).length() * 0.5)
		if near > 0.0 and _rng.randf() < chance:
			ignite(i)


## A stray army shell landed at `at` (D-129): a building within shell_reach catches with chance
## shell_ignite. The clumsy army (claude/clumsy-army, StrayShell.land) calls this once it merges.
func shelled(at: Vector2) -> void:
	if not on():
		return
	var reach := Num.f(cfg["shell_reach"])
	var spot := Rect2(at, Vector2.ZERO)
	for i: int in _around(spot, reach):
		if _gap(_rect(i), spot) <= reach and _rng.randf() < Num.f(cfg["shell_ignite"]):
			ignite(i)


## An explosive site went off at `at` (Firestorm, D-126): every building within `radius` catches.
## Nothing calls it until explosive sites merge (claude/city-explosives): Firestorm is a stub.
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
	_since += dt
	var spread := _since >= Num.f(cfg["spread_tick"]) - dt * 0.5  # a whole number of ticks
	var keys := _active.keys()
	for i: int in keys:
		if sim.buildings[i].frame.alive_count == 0:  # smashed first: nothing left to burn
			_drop(i, State.BURNT)
	if spread:
		_heat_pass(keys)
	for i: int in keys:
		_tick(i, dt)
	if spread:
		_since = 0.0


## Every burning building heats its neighbours for the seconds since the last pass; then each
## heating one glows or cools.
func _heat_pass(keys: Array) -> void:
	_pass += 1
	for i: int in keys:
		if state[i] == State.BURNING:
			_heat_neighbours(i, _since)
	for i: int in keys:
		if state[i] == State.HEATING:
			_heating(i, _since)


## A glowing building's glow and a burning one's fire count down by dt.
func _tick(i: int, dt: float) -> void:
	if state[i] != State.GLOWING and state[i] != State.BURNING:
		return
	if _crumbling.has(i):
		_crumble(i)
		return
	timer[i] -= dt
	if timer[i] > 0.0:
		return
	if state[i] == State.GLOWING:
		_burn(i)
	else:
		_burn_out(i, dt)


## Burning building i heats every neighbour still intact or heating; neighbours already past
## heating (they never come back) leave its list for good, so a long fire gets cheaper.
func _heat_neighbours(i: int, dt: float) -> void:
	var near: Array = _near.get(i, [])
	if near.is_empty():
		near = _neighbours(i)
		_near[i] = near
	var who: PackedInt32Array = near[0]
	var rate: PackedFloat32Array = near[1]
	var gone := 0
	for k: int in who.size():
		var j := who[k]
		if state[j] > State.HEATING:
			gone += 1
			continue
		if state[j] == State.INTACT:
			state[j] = State.HEATING
			_active[j] = true
		heat[j] += rate[k] * dt
		_warm[j] = _pass
	if gone > 0:
		_near[i] = _still_heatable(who, rate)


func _still_heatable(who: PackedInt32Array, rate: PackedFloat32Array) -> Array:
	var keep := PackedInt32Array()
	var keep_rate := PackedFloat32Array()
	for k: int in who.size():
		if state[who[k]] <= State.HEATING:
			keep.append(who[k])
			keep_rate.append(rate[k])
	return [keep, keep_rate]


func _heating(i: int, dt: float) -> void:
	if _warm[i] != _pass:
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


## It burns out: its ground floors (burn_out_floors) give way over burn_out_seconds, the downwind
## side first, so the rest drops and topples toward it like a smashed building whose base was
## eaten (D-129); no burning shell is left (#111). Everything it drops pays burn_pay of a smash
## times the conflagration, and far_pay of that when the kaiju is far away.
func _burn_out(i: int, dt: float) -> void:
	var b := sim.buildings[i]
	var share := Num.f(cfg["burn_pay"]) * conflagration
	var far := Vector2(b.x, b.z).distance_to(sim.kaiju_pos) > Num.f(cfg["far_radius"])
	if far:
		share *= Num.f(cfg["far_pay"])
	b.pay_share = share
	var cells := ground_cells(i)
	var ticks := maxi(1, roundi(Num.f(cfg["burn_out_seconds"]) / dt))
	_crumbling[i] = [cells, ceili(cells.size() / float(ticks))]
	burnt_out += 1
	conflagration = minf(Num.f(cfg["conflag_max"]), conflagration + Num.f(cfg["conflag_step"]))
	sim.events.append({"type": "fire_burnt", "building": i, "share": share, "far": far})
	_crumble(i)


## The cells of building i's burn_out_floors lowest floors in the order they give way: the
## downwind side first (then by floor, x and z, the same every run).
func ground_cells(i: int) -> Array[Vector3i]:
	var b := sim.buildings[i]
	var cells: Array[Vector3i] = []
	for y: int in mini(Num.i(cfg["burn_out_floors"]), b.height):
		for x: int in b.w:
			for z: int in b.d:
				cells.append(Vector3i(x, y, z))
	var mid := Vector2(b.w, b.d) * 0.5
	var key := func(c: Vector3i) -> float:
		return (Vector2(c.x, c.z) + Vector2.ONE * 0.5 - mid).dot(wind)
	cells.sort_custom(
		func(p: Vector3i, q: Vector3i) -> bool:
			var kp: float = key.call(p)
			var kq: float = key.call(q)
			if kp != kq:
				return kp > kq
			return Vector3i(p.y, p.x, p.z) < Vector3i(q.y, q.x, q.z)
	)
	return cells


## The next cells of a building giving way break; once none stand it is burnt out.
func _crumble(i: int) -> void:
	var entry: Array = _crumbling[i]
	var cells: Array[Vector3i] = entry[0]
	var batch: Array[Vector3i] = []
	while not cells.is_empty() and batch.size() < Num.i(entry[1]):
		batch.append(cells.pop_front())
	var amounts := PackedFloat32Array()
	amounts.resize(batch.size())
	amounts.fill(Num.f(cfg["burn_out_damage"]))
	sim.damage_cells(i, batch, amounts)
	if cells.is_empty() or sim.buildings[i].frame.alive_count == 0:
		_drop(i, State.BURNT)


func _drop(i: int, to: State) -> void:
	state[i] = to
	_active.erase(i)
	_crumbling.erase(i)


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
