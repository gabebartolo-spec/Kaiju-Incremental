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


## The biggest kaiju that can emerge at this stage (size tier = stage, as Main starts a run;
## the most growth it can own there, EmergeReach: director 2026-10-21, "Fit the biggest
## possible") rises in open water and bursts up through the bay's decks ("burst through"):
## through the rise no part of its body's discs is over solid ground (outside
## CityRiver.water), and once risen no deck left standing (CityRiver.decks_after) lies under
## any disc, and the sim said so.
static func check_burst(tier: int, map_seed: int, check_fn: Callable) -> void:
	var grown := EmergeReach.max_growth(Content.upgrades(), "reptilian", tier)
	var sim := _fresh(tier, map_seed, tier, grown)
	sim.emerge.start(sim)
	var plan := CityGen.map(sim.city)
	var water := CityRiver.water(plan, sim.city)
	var said := false
	var t := 0.0
	var dry := 0
	while sim.emerge.active and sim.emerge.risen() < 1.0:
		sim.step(DT, Vector2.ZERO, false)
		t += DT
		for e: Dictionary in sim.events:
			said = said or str(e["type"]) == "deck_burst"
		dry = maxi(dry, _on_ground(sim, water))
	(
		check_fn
		. call(
			dry == 0,
			(
				(
					"stage %d, map_seed %d: the size-%d kaiju at growth %d (%.1f m) rises in open water:"
					+ " %d points of its body over solid ground"
				)
				% [tier, map_seed, sim.size_tier(), grown, sim.body.length(), dry]
			)
		)
	)
	var left := CityRiver.decks_after(plan, sim.city, sim.emerge.burst)
	left.append_array(CityRiver.decks_after_ns(plan, sim.city, sim.emerge.burst_ns))
	var s := sim.body_scale()
	var under := 0
	for d: Array in sim.body.discs():
		var c := sim.kaiju_pos + sim.facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		for deck: Rect2 in left:
			var near := Vector2(
				clampf(c.x, deck.position.x, deck.end.x), clampf(c.y, deck.position.y, deck.end.y)
			)
			if near.distance_to(c) < r:
				under += 1
	check_fn.call(
		under == 0 and (said or sim.emerge.burst.is_empty() and sim.emerge.burst_ns.is_empty()),
		(
			(
				"stage %d, map_seed %d: the size-%d kaiju (%.1f m) bursts up through the bay's"
				+ " %d decks: %d holes, %d body discs over a deck left after %.1f s, event %s"
			)
			% [
				tier,
				map_seed,
				sim.size_tier(),
				sim.body.length(),
				(
					CityRiver.bay_bridges(plan, sim.city).size()
					+ CityRiver.bay_bridges_ns(plan, sim.city).size()
				),
				sim.emerge.burst.size() + sim.emerge.burst_ns.size(),
				under,
				t,
				said
			]
		)
	)


## How many sample points of the body's discs (centre, and eight round the rim) lie outside
## the water.
static func _on_ground(sim: RampageSim, water: Array[Rect2]) -> int:
	var s := sim.body_scale()
	var out := 0
	for d: Array in sim.body.discs():
		var c := sim.kaiju_pos + sim.facing * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		for k: int in 9:
			var p := c if k == 8 else c + Vector2.from_angle(k * PI / 4.0) * r
			if not water.any(func(w: Rect2) -> bool: return w.has_point(p)):
				out += 1
	return out


## A sim of its own for the walk (it steps, and its stomps break things); size: the kaiju's
## size tier (0: the run stats' own, the young kaiju), growth its upgrade levels owned.
static func _fresh(tier: int, map_seed: int, size: int = 0, growth: int = 0) -> RampageSim:
	var base: Dictionary = Content.tuning().duplicate(true)
	base["city"]["map_seed"] = map_seed
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	if size > 0:
		stats["size"] = size
		stats["growth"] = float(growth)
	var sim := RampageSim.new(
		stats,
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
	var walk: Pavements = street._pavements
	for a: int in walk.nodes.size():
		for b: int in walk.links[a]:
			for k: int in 11:
				var p := walk.nodes[a].lerp(walk.nodes[b], k / 10.0)
				for basin: Rect2 in bay:
					if basin.has_point(p):
						wet += 1
	check_fn.call(
		not bay.is_empty() and wet == 0,
		"stage %d, map_seed %d: no one walks on the bay (%d points)" % [tier, map_seed, wet]
	)
