extends RefCounted
## The playtest note (director 2026-10-19: "smaller buildings south of the spawn position dont
## seem destructible?"): the city suite's spawn-view check, called from its D-062 loop for each
## stage and map_seed. Within the game camera's reach of where the kaiju rises (its ground
## distance behind the kaiju, CameraTuning.offset().z, plus a margin, scaled by body size like
## the camera), no skyline stand-in stands. And the rise bar (D-384, director 2026-10-29: "Hotels
## hit in 10 s"): from the moment he stands up out of the sea, his first beachfront hotel
## (CityHarbour's "front" blocks, D-381) is down within DOWN_BY seconds, the walk across the
## sand counted. Distances run from the nearer of the rise point (in the sea, CityHarbour) and the
## bank point it wades to, where the run starts and the camera settles.

const MARGIN := 4.0  # past the camera's ground point: the bottom of the screen
const DT := 1.0 / 30.0
## D-091: big buildings take longer to chew down, so the bar is time, not one stomp (D-131: 10 s
## stays; D-384: counted to the first beachfront hotel down, from when he stands).
const DOWN_BY := 10.0
const WALK_LIMIT := 1000.0  # stops a walk that never finishes


static func check(
	tier: int, map_seed: int, sim: RampageSim, skyline: CitySkyline, check_fn: Callable
) -> void:
	var spawn: Vector2 = CityGen.map(sim.city).get("rise_spawn", sim.kaiju_pos)
	var bank: Vector2 = CityGen.map(sim.city).get("rise_bank", spawn)
	var land := sim.clamp_to_arena(bank)
	var reach := (CameraTuning.offset().z + MARGIN) * sim.body_scale()
	var stand_ins := 0
	for box: Dictionary in skyline._near:
		var at: Vector3 = box["at"]
		var size: Vector3 = box["size"]
		var foot := Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z)
		if _gap(foot, spawn, land) < reach:
			stand_ins += 1
	sim.body.use_species("reptilian")
	var got := first_hotel(sim)
	check_fn.call(
		stand_ins == 0 and Num.i(got["hotels"]) > 0 and Num.f(got["seconds"]) <= DOWN_BY,
		(
			(
				"stage %d, map_seed %d: within %.0f m of the rise point %s or %s, %d stand-ins;"
				+ " first of %d beachfront hotels down %.1f s after he stands (within %.0f s)"
			)
			% [
				tier,
				map_seed,
				reach,
				spawn,
				land,
				stand_ins,
				Num.i(got["hotels"]),
				Num.f(got["seconds"]),
				DOWN_BY
			]
		)
	)


## The run's start as the game plays it (up out of the sea), then a bot walking at the nearest
## standing chunk of a beachfront hotel until one is down: {hotels (in the arena), seconds (from
## when he stands; WALK_LIMIT if none falls)}.
static func first_hotel(sim: RampageSim) -> Dictionary:
	var hotels := front_hotels(sim)
	sim.emerge.start(sim)
	var landed := false
	var guard := 0
	while not landed and guard < 3000:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			landed = landed or str(event["type"]) == "kaiju_emerged"
		guard += 1
	var walked := 0.0
	while walked < WALK_LIMIT and not hotels.is_empty() and _standing(sim, hotels) == hotels.size():
		var goal := _nearest(sim, hotels)
		var to := goal - sim.kaiju_pos
		sim.step(DT, to.normalized() if to.length() > 0.2 else Vector2.ZERO, false)
		walked += DT
	return {"hotels": hotels.size(), "seconds": walked}


## The buildings on the beachfront's hotel blocks (CityHarbour, "front") the kaiju can reach.
static func front_hotels(sim: RampageSim) -> Array[RampageSim.Building]:
	var fronts: Array[Rect2] = []
	for block: Dictionary in CityGen.map(sim.city)["blocks"]:
		var rect: Rect2 = block["rect"]
		if block.get("front", false):
			fronts.append(rect)
	var out: Array[RampageSim.Building] = []
	for b: RampageSim.Building in sim.lot_buildings():
		var at := Vector2(b.x, b.z)
		if b.in_arena and fronts.any(func(r: Rect2) -> bool: return r.has_point(at)):
			out.append(b)
	return out


static func _standing(_sim: RampageSim, near: Array[RampageSim.Building]) -> int:
	var n := 0
	for b: RampageSim.Building in near:
		if b.frame.alive_count > 0:
			n += 1
	return n


## The standing chunk of the group nearest the kaiju (what a player walks at).
static func _nearest(sim: RampageSim, near: Array[RampageSim.Building]) -> Vector2:
	var best := sim.kaiju_pos
	var best_d := INF
	for b: RampageSim.Building in near:
		if b.frame.alive_count == 0:
			continue
		for x: int in b.w:
			for z: int in b.d:
				if b.frame.alive(Vector3i(x, 0, z)):
					var p := b.chunk_world(Vector3i(x, 0, z))
					var d := sim.kaiju_pos.distance_squared_to(Vector2(p.x, p.z))
					if d < best_d:
						best_d = d
						best = Vector2(p.x, p.z)
	return best


static func _gap(foot: Rect2, a: Vector2, b: Vector2) -> float:
	return minf(
		a.clamp(foot.position, foot.end).distance_to(a),
		b.clamp(foot.position, foot.end).distance_to(b)
	)
