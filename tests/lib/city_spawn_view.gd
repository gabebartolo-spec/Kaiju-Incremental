extends RefCounted
## The playtest note (director 2026-10-19: "smaller buildings south of the spawn position dont
## seem destructible?"): the city suite's spawn-view check, called from its D-062 loop for each
## stage and map_seed. Within the game camera's reach of where the kaiju rises (its ground
## distance behind the kaiju, Rampage.CAMERA_OFFSET.z, plus a margin, scaled by body size like
## the camera), no skyline stand-in stands, and every building there is a real one a stomp
## breaks, and there is at least one (lead check 2026-10-19: his first steps out of the water
## hit something; CityRiver's quay sheds). Distances run from the nearer of the rise point (in
## the river, D-083) and the bank point it wades to, where the run starts and the camera
## settles.

const MARGIN := 4.0  # past the camera's ground point: the bottom of the screen


static func check(
	tier: int, map_seed: int, sim: RampageSim, skyline: CitySkyline, check_fn: Callable
) -> void:
	var spawn: Vector2 = CityGen.map(sim.city).get("river_spawn", sim.kaiju_pos)
	var bank: Vector2 = CityGen.map(sim.city).get("river_bank", spawn)
	var land := sim.clamp_to_arena(bank)
	var reach := (Rampage.CAMERA_OFFSET.z + MARGIN) * sim.body_scale()
	var stand_ins := 0
	for box: Dictionary in skyline._near:
		var at: Vector3 = box["at"]
		var size: Vector3 = box["size"]
		var foot := Rect2(at.x - size.x * 0.5, at.z - size.z * 0.5, size.x, size.z)
		if _gap(foot, spawn, land) < reach:
			stand_ins += 1
	var near := 0
	var unbroken := 0
	for b: RampageSim.Building in sim.buildings:
		var foot := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
		if _gap(foot, spawn, land) >= reach:
			continue
		near += 1
		var alive := b.frame.alive_count
		sim.kaiju_pos = sim.clamp_to_arena(Vector2(b.x, b.z))
		sim._stomp()
		if b.frame.alive_count >= alive:
			unbroken += 1
	(
		check_fn
		. call(
			stand_ins == 0 and near > 0 and unbroken == 0,
			(
				(
					"stage %d, map_seed %d: within %.0f m of the rise point %s or %s, %d stand-ins and %d"
					+ " buildings, %d of them unbroken by a stomp"
				)
				% [tier, map_seed, reach, spawn, land, stand_ins, near, unbroken]
			)
		)
	)


static func _gap(foot: Rect2, a: Vector2, b: Vector2) -> float:
	return minf(
		a.clamp(foot.position, foot.end).distance_to(a),
		b.clamp(foot.position, foot.end).distance_to(b)
	)
