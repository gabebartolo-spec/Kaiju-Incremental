extends RefCounted
## The atomic breath flattens the trees it burns (build 2 note 26: "atomic blast doesnt affect
## trees"): a park tree three quarters down the cone goes down; the cone never reaches past its
## own side by more than one cover circle's slack.

const DOWN := 0.75  # the tree stands this share of the breath's reach down its axis


static func check(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check: Callable
) -> void:
	var trees: Array[Vector2] = decor._park_trees
	if trees.is_empty():
		check.call(false, "stage %d, map_seed %d: a park tree to breathe on" % [tier, map_seed])
		return
	var before := {}
	for group: Dictionary in decor._props._groups:
		if group.get("crushed", false):
			before[group["at"]] = true  # the tail check felled these
	var tree := trees[-1]
	var reach := sim.ability_reach()
	var half := deg_to_rad(Num.f(sim.city["cone_half_angle_deg"]))
	var dir := Vector2(0, -1)
	var origin := tree - dir * reach * DOWN
	var cone := {"origin": origin, "dir": dir, "reach": reach, "half_angle": half}
	for c: Vector3 in BreathCone.cover(cone):
		decor.crush(Vector3(c.x, 0.0, c.y), c.z)
	var down := false
	var stray := 0
	var slack := reach / 12.0
	for group: Dictionary in decor._props._groups:
		if not group.get("crushed", false) or before.has(group["at"]):
			continue
		var base: Vector3 = group["at"]
		var rel := Vector2(base.x, base.z) - origin
		down = down or Vector2(base.x, base.z).distance_to(tree) < 0.01
		var along := rel.dot(dir)
		var side := absf(rel.cross(dir))
		if along < -slack or along > reach + slack or side > along * tan(half) + 2.0 * slack:
			stray += 1
	(
		check
		. call(
			down and stray == 0,
			(
				(
					"stage %d, map_seed %d: a breath %.0f m long flattens the park tree %.0f m down it (%s),"
					% [tier, map_seed, reach, reach * DOWN, "down" if down else "STANDING"]
				)
				+ " and nothing outside its cone (%d strays)" % stray
			)
		)
	)
	var spots := BreathCone.cover(cone)
	var covered := 0
	var samples := 0
	for step: int in range(1, 61):
		for k: int in range(-20, 21):
			var at := origin + dir.rotated(half * k / 20.0) * (reach * step / 60.0)
			samples += 1
			for c: Vector3 in spots:
				if Vector2(at.x - c.x, at.y - c.y).length() <= c.z:
					covered += 1
					break
	var share := float(covered) / samples
	check.call(
		share >= 0.99,
		(
			"stage %d, map_seed %d: the breath's ground cover takes in the cone (%.1f%%)"
			% [tier, map_seed, share * 100.0]
		)
	)
