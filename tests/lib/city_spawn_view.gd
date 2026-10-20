extends RefCounted
## The playtest note (director 2026-10-19: "smaller buildings south of the spawn position dont
## seem destructible?"): the city suite's spawn-view check, called from its D-062 loop for each
## stage and map_seed. Within the game camera's reach of where the kaiju rises (its ground
## distance behind the kaiju, Rampage.camera_offset().z, plus a margin, scaled by body size like
## the camera), no skyline stand-in stands, and every building there is a real one a stomp
## breaks, and there is at least one (lead check 2026-10-19: his first steps out of the water
## hit something; CityRiver's quay sheds). Distances run from the nearer of the rise point (in
## the river, D-083) and the bank point it wades to, where the run starts and the camera
## settles.

const MARGIN := 4.0  # past the camera's ground point: the bottom of the screen
const DT := 1.0 / 30.0
## D-091: big buildings take longer to chew down, so the check is time, not one stomp. The
## buildings within NEAR metres of the rise point must all be down within DOWN_BY seconds of the
## kaiju walking in at them (young kaiju, body contact and stomps). Measured worst case over
## stage 1 and the Behemoth, three map seeds (2026-10-20): 8.0 s; DOWN_BY is that plus a margin.
const NEAR := 12.0
const DOWN_BY := 10.0
const WALK_LIMIT := 1000.0  # stops a walk that never finishes


static func check(
	tier: int, map_seed: int, sim: RampageSim, skyline: CitySkyline, check_fn: Callable
) -> void:
	var spawn: Vector2 = CityGen.map(sim.city).get("river_spawn", sim.kaiju_pos)
	var bank: Vector2 = CityGen.map(sim.city).get("river_bank", spawn)
	var land := sim.clamp_to_arena(bank)
	var reach := (Rampage.camera_offset().z + MARGIN) * sim.body_scale()
	var stand_ins := 0
	for box: Dictionary in skyline._near:
		var at: Vector3 = box["at"]
		var size: Vector3 = box["size"]
		var foot := Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z)
		if _gap(foot, spawn, land) < reach:
			stand_ins += 1
	var near := _near_buildings(sim, spawn, land)
	var species := "reptilian"
	sim.body.use_species(species)
	sim.emerge.start(sim)  # the run's start, as the game plays it: up out of the river
	var landed := false
	var guard := 0
	while not landed and guard < 3000:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			landed = landed or str(event["type"]) == "kaiju_emerged"
		guard += 1
	var walked := 0.0
	while walked < WALK_LIMIT and _standing(sim, near) > 0:
		var goal := _nearest(sim, near)
		var to := goal - sim.kaiju_pos
		sim.step(DT, to.normalized() if to.length() > 0.2 else Vector2.ZERO, false)
		walked += DT
	var left := _standing(sim, near)
	(
		check_fn
		. call(
			stand_ins == 0 and not near.is_empty() and left == 0 and walked <= DOWN_BY,
			(
				(
					"stage %d, map_seed %d: within %.0f m of the rise point %s or %s, %d stand-ins;"
					+ " the %d buildings within %.0f m of it: %d standing after %.1f s of a kaiju walking"
					+ " in (they must be down within %.0f s)"
				)
				% [
					tier,
					map_seed,
					reach,
					spawn,
					land,
					stand_ins,
					near.size(),
					NEAR,
					left,
					walked,
					DOWN_BY
				]
			)
		)
	)


## The buildings within NEAR metres of the rise point or the bank point it wades to.
static func _near_buildings(
	sim: RampageSim, spawn: Vector2, land: Vector2
) -> Array[RampageSim.Building]:
	var out: Array[RampageSim.Building] = []
	for b: RampageSim.Building in sim.buildings:
		var foot := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		if _gap(foot, spawn, land) < NEAR:
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
