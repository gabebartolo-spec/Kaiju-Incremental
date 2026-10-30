extends RefCounted
## The playtest note (director 2026-10-19: "smaller buildings south of the spawn position dont
## seem destructible?"): the city suite's spawn-view check, called from its D-062 loop for each
## stage and map_seed. Within the game camera's reach of where the kaiju rises (its ground
## distance behind the kaiju, CameraTuning.offset().z, plus a margin, scaled by body size like
## the camera), no skyline stand-in stands. Distances run from the nearer of the rise point (in the
## sea, CityHarbour) and the bank point it wades to, where the run starts and the camera settles.

const MARGIN := 4.0  # past the camera's ground point: the bottom of the screen


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
	check_fn.call(
		stand_ins == 0,
		(
			"stage %d, map_seed %d: within %.0f m of the rise point %s or %s, %d stand-ins"
			% [tier, map_seed, reach, spawn, land, stand_ins]
		)
	)


static func _gap(foot: Rect2, a: Vector2, b: Vector2) -> float:
	return minf(
		a.clamp(foot.position, foot.end).distance_to(a),
		b.clamp(foot.position, foot.end).distance_to(b)
	)
