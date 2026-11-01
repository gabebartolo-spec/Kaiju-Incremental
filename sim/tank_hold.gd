class_name TankHold
extends RefCounted
## What a flung tank does to a building it meets (director 2026-11-01: "when a tank hits a building
## it needs to carve it, it would be really cool if a tank could even wedge into and get stuck in
## the bigger buildings or if they land ontop of a building they could crush it"; picked "Tank-sized
## hole", "Too big to punch through", "Punch through floors"). A tank flying into a wall bores a
## hull-sized tunnel (bore_half to each side, wall_floors high), bore_min deep at any speed and
## bore_per_speed deeper per unit of ground speed up to bore_max. Out the far side it flies on at
## bore_keep of its speed; else it sticks nose-in at the tunnel's end, wedged. A tank coming down
## on a roof caves in roof_per_speed floors per unit of fall speed (roof_min..roof_max) under its
## hull and ends inside. A wreck left above the street is a husk (TankFlight.husks): it stays
## where it came to rest and falls when the floor under it breaks; a wedged one also stays at
## street level while the floors over it stand. Numbers are army.flight.hold in data/tuning.json.

var sim: RampageSim
var cfg: Dictionary
## Wrecks resting above the street or wedged in a building (Army.clear_dead hands them over).
var husks: Array[RampageSim.Tank] = []
## Tunnels bored, tanks wedged, tanks out a building's far side, roofs caved in (fixtures).
var bored := 0
var wedged := 0
var through := 0
var punched := 0
var _wedged: Dictionary  # tank id -> true


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg


## The top of the highest standing floor at `pos` at or below height `y` (0: the street).
func floor_under(pos: Vector2, y: float) -> float:
	for i: int in sim.grid.around(pos, 0.0):
		var b := sim.buildings[i]
		var lx := floori(pos.x - (b.x - b.w * 0.5))
		var lz := floori(pos.y - (b.z - b.d * 0.5))
		if lx >= 0 and lz >= 0 and lx < b.w and lz < b.d:
			return float(maxi(0, b.frame.top_below(lx, lz, floori(y) - b.base) + 1 + b.base))
	return 0.0


## Is there a standing chunk at `pos`, height `y`?
func solid(pos: Vector2, y: float) -> bool:
	if y < 0.0:
		return true
	for i: int in sim.grid.around(pos, 0.0):
		var b := sim.buildings[i]
		var c := Vector3i(
			floori(pos.x - (b.x - b.w * 0.5)), floori(y) - b.base, floori(pos.y - (b.z - b.d * 0.5))
		)
		if c.x >= 0 and c.z >= 0 and c.x < b.w and c.z < b.d:
			return c.y >= 0 and b.frame.alive(c)
	return false


## A wall met at `at`, height `y`, at ground velocity `flat`: bores the tunnel. True if the tank
## came out the far side (put at the exit, it flies on at bore_keep); false if it is wedged at the
## tunnel's end.
func bore(tank: RampageSim.Tank, at: Vector2, y: float, flat: Vector2) -> bool:
	var way := flat.normalized()
	var depth := clampf(
		Num.f(cfg["bore_min"]) + flat.length() * Num.f(cfg["bore_per_speed"]),
		Num.f(cfg["bore_min"]),
		Num.f(cfg["bore_max"])
	)
	var floor_at := maxi(0, floori(y))
	var half := Num.f(cfg["bore_half"])
	_break(
		at + way * depth * 0.5,
		func(p: Vector2) -> bool:
			var d := p - at
			return d.dot(way) >= -0.5 and d.dot(way) <= depth and absf(d.cross(way)) <= half,
		depth * 0.5 + half + 1.0,
		Vector2i(floor_at, floor_at + Num.i(sim.flight.cfg["wall_floors"]))
	)
	bored += 1
	var exit := at + way * (depth + 0.5)
	if not solid(exit, y + Num.f(sim.flight.cfg["clearance"])):
		through += 1
		tank.pos = exit  # out the far side, as a wedged tank is put at its tunnel's end
		var keep := flat * Num.f(cfg["bore_keep"])
		tank.vel = Vector3(keep.x, tank.vel.y, keep.y)
		return true
	tank.pos = at + way * maxf(0.5, depth - Num.f(cfg["hull_half_length"]))
	tank.height = floor_under(tank.pos, y + Num.f(sim.flight.cfg["clearance"]))
	tank.vel = Vector3.ZERO
	tank.spin = Vector3.ZERO
	tank.flying = false
	tank.wrecked = true
	_wedged[tank.id] = true
	wedged += 1
	sim.events.append(
		{"type": "tank_wedged", "tank": tank.id, "at": tank.pos, "height": tank.height}
	)
	return false


## A tank come down on a roof at `fall` speed: caves its floors in under the hull; it ends on
## whatever floor still stands below them.
func punch(tank: RampageSim.Tank, fall: float) -> void:
	var top := floori(tank.height)
	if top <= 0:
		return
	var floors := clampi(
		ceili(fall * Num.f(cfg["roof_per_speed"])), Num.i(cfg["roof_min"]), Num.i(cfg["roof_max"])
	)
	var at := tank.pos
	var half := Num.f(cfg["bore_half"])
	_break(
		at,
		func(p: Vector2) -> bool: return absf(p.x - at.x) <= half and absf(p.y - at.y) <= half,
		half + 1.0,
		Vector2i(maxi(0, top - floors), top)
	)
	punched += 1
	tank.height = floor_under(at, tank.height)
	sim.events.append(
		{"type": "tank_punched", "tank": tank.id, "at": at, "height": tank.height, "floors": floors}
	)


## Is the wreck `tank` kept as a husk rather than cleared where it lies?
func holds(tank: RampageSim.Tank) -> bool:
	return tank.height > 0.0 or _wedged.has(tank.id)


## Husks whose floor broke fall to the next one; one back on the street, and no longer under a
## standing building if it was wedged, is gone (tank_husk_down).
func step(dt: float) -> void:
	if husks.is_empty():
		return
	var g := Num.f(sim.flight.cfg["gravity"])
	var clear := Num.f(sim.flight.cfg["clearance"])
	var kept: Array[RampageSim.Tank] = []
	for husk: RampageSim.Tank in husks:
		var below := floor_under(husk.pos, husk.height + clear)
		if below < husk.height:
			husk.vel.y -= g * dt
			husk.height = maxf(below, husk.height + husk.vel.y * dt)
			if husk.height <= below:
				husk.vel = Vector3.ZERO
		var roofed := (
			_wedged.has(husk.id)
			and solid(husk.pos, husk.height + Num.f(sim.flight.cfg["wall_floors"]) + 0.5)
		)
		if husk.height > 0.0 or roofed:
			kept.append(husk)
			continue
		_wedged.erase(husk.id)
		sim.events.append(
			{"type": "tank_husk_down", "tank": husk.id, "x": husk.pos.x, "z": husk.pos.y}
		)
	husks = kept


## Breaks every standing chunk on world floors `floors` (lo..hi-1) whose centre `inside` takes,
## among the buildings within `reach` of `centre`: bore_damage each, past any building's toughness.
func _break(centre: Vector2, inside: Callable, reach: float, floors: Vector2i) -> void:
	var amount := Num.f(cfg["bore_damage"])
	for i: int in sim.grid.around(centre, reach):
		var b := sim.buildings[i]
		if b.frame.alive_count == 0:
			continue
		var local := b.local_floors(floors)
		var cells: Array[Vector3i] = []
		for y: int in range(maxi(0, local.x), mini(local.y, b.height)):
			for x: int in b.w:
				for z: int in b.d:
					var c := Vector3i(x, y, z)
					if b.frame.alive(c):
						var p := b.chunk_world(c)
						if inside.call(Vector2(p.x, p.z)):
							cells.append(c)
		var amounts := PackedFloat32Array()
		amounts.resize(cells.size())
		amounts.fill(amount)
		sim.damage_cells(i, cells, amounts)
