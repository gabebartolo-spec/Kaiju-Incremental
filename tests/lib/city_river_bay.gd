extends RefCounted
## The kaiju walks straight out of the river into the city (director 2026-10-21 #17: "when the
## kaiju emerges from the river he does a little side step that shouldnt be possible, have him
## emerging facing the city so he can walk straight in, perhaps make a small shoreline that he
## can embark upon, and the river where he emerges from can be slightly wider"): the run's start
## (Emergence) rises facing the city and never turns or slides sideways through the rise, the
## wade up the shore and its first second of walking ahead; the river's bay is wider than the
## channel, with a shore that climbs from its floor to the street, every street across it bridged,
## and nothing (building, prop, walker) standing in it.

const DT := 1.0 / 30.0
const WALK := 1.0  # seconds of walking ahead once out
const SLIDE := 0.02  # metres sideways, and radians of turn, that still count as none


static func check(
	tier: int, map_seed: int, sim: RampageSim, decor: CityDecor, check_fn: Callable
) -> void:
	var plan := CityGen.map(sim.city)
	if not plan.has("river"):
		return
	_check_walk_in(tier, map_seed, _fresh(tier, map_seed), check_fn)
	_check_bay(tier, map_seed, sim, plan, decor, check_fn)


static func _check_walk_in(tier: int, map_seed: int, sim: RampageSim, check_fn: Callable) -> void:
	sim.emerge.start(sim)
	var start := sim.kaiju_pos
	var ahead := sim.facing
	var side := 0.0
	var turn := 0.0
	var t := 0.0
	var out_at := -1.0
	while (
		t < Num.f(Content.tuning()["emerge"]["max_seconds"]) + WALK
		and (out_at < 0.0 or t < out_at + WALK)
	):
		sim.step(DT, Vector2.ZERO if sim.emerge.active else ahead, false)
		t += DT
		if out_at < 0.0 and not sim.emerge.active:
			out_at = t
		side = maxf(side, absf((sim.kaiju_pos - start).cross(ahead)))
		turn = maxf(turn, absf(sim.facing.angle_to(ahead)))
		turn = maxf(turn, absf(sim.body.heading.angle_to(ahead)))
	var into_city := ahead.dot(-start.normalized()) > 0.5
	check_fn.call(
		into_city and side <= SLIDE and turn <= SLIDE and out_at > 0.0,
		(
			(
				"stage %d, map_seed %d: the kaiju rises facing the city (%s from %s) and walks"
				+ " straight in: %.3f m sideways, %.3f rad of turn, out after %.1f s"
			)
			% [tier, map_seed, ahead, start, side, turn, out_at]
		)
	)


## A sim of its own for the walk (it steps, and its stomps break things).
static func _fresh(tier: int, map_seed: int) -> RampageSim:
	var base: Dictionary = Content.tuning().duplicate(true)
	base["city"]["map_seed"] = map_seed
	var sim := RampageSim.new(
		UpgradeTree.run_stats(
			Content.section("kaiju"),
			Content.species_def("reptilian"),
			UpgradeTree.new(Content.upgrades())
		),
		CityGrowth.tuning_for(base, tier),
		CityGrowth.layout(base, tier, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	sim.body.use_species("reptilian")
	return sim


static func _check_bay(
	tier: int,
	map_seed: int,
	sim: RampageSim,
	plan: Dictionary,
	decor: CityDecor,
	check_fn: Callable
) -> void:
	var channel := CityRiver.channels(plan, sim.city)[0]
	var bay := CityRiver.bay(plan, sim.city)
	var sand := CityRiver.shore(plan, sim.city)
	var wider := not bay.is_empty() and bay[0].end.y > channel.end.y
	var bed := -Num.f(sim.city["river_depth"])
	var top := CityRiver.floor_at(plan, sim.city, Vector2(sand.get_center().x, sand.position.y))
	var foot := CityRiver.floor_at(plan, sim.city, Vector2(sand.get_center().x, sand.end.y - 0.01))
	var sloped := is_zero_approx(top) and absf(foot - bed) < 0.05
	var crossing := 0
	var nodes: Array[Vector2] = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		var a := nodes[Num.i(street["from"])]
		var b := nodes[Num.i(street["to"])]
		if is_equal_approx(a.y, b.y) and a.y > sand.end.y:
			for basin: Rect2 in bay:
				var road := Rect2(minf(a.x, b.x), a.y - 0.01, absf(b.x - a.x), 0.02)
				if road.intersects(basin):
					crossing += 1
					break
	var decks := CityRiver.bay_bridges(plan, sim.city).size()
	var wet := 0
	for b: RampageSim.Building in sim.buildings:
		for basin: Rect2 in bay:
			if basin.intersects(Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)):
				wet += 1
	for g: Dictionary in decor._props._groups:
		var at: Vector3 = g["at"]
		for basin: Rect2 in bay:
			if basin.has_point(Vector2(at.x, at.z)):
				wet += 1
	check_fn.call(
		wider and sloped and decks >= crossing and wet == 0,
		(
			(
				"stage %d, map_seed %d: the bay is wider than the river (%s past %.1f), its shore"
				+ " slopes from the street (%.2f) to the floor (%.2f), %d of %d streets across it"
				+ " bridged, %d buildings or props in it"
			)
			% [
				tier,
				map_seed,
				bay[0].end.y if not bay.is_empty() else -1.0,
				channel.end.y,
				top,
				foot,
				decks,
				crossing,
				wet
			]
		)
	)


## No walker's pavement corner, nor the line between two linked corners, in the bay.
static func check_walkers(
	tier: int, map_seed: int, sim: RampageSim, street: StreetLife, check_fn: Callable
) -> void:
	var bay := CityRiver.bay(CityGen.map(sim.city), sim.city)
	var wet := 0
	for a: int in street._nodes.size():
		for b: int in street._links[a]:
			for k: int in 11:
				var p := street._nodes[a].lerp(street._nodes[b], k / 10.0)
				for basin: Rect2 in bay:
					if basin.has_point(p):
						wet += 1
	check_fn.call(
		not bay.is_empty() and wet == 0,
		"stage %d, map_seed %d: no one walks on the bay (%d points)" % [tier, map_seed, wet]
	)
