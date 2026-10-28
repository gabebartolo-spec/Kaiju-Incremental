extends RefCounted
## The rise-point bar (tests/lib/city_spawn_view.gd: the buildings within NEAR metres of where the
## kaiju rises are all down within DOWN_BY seconds of it walking in) for each body the game really
## plays: the young croc in the stage 1 city, the Behemoth in the stage 2 city and the Colossus in
## the stage 3 city (a run's stats.size picks both, CityGrowth.tuning_for_stats), on every map seed.
## The Behemoth and the Colossus make heavy stepped U-turns (D-187, D-192 "A: short steps"), so a
## bot that walks at the nearest standing chunk loses time turning. The bar is the director's
## (D-131: 10 s stays; D-192: "what the hell, no?" to 12 s) and is not changed: SpawnView's
## DOWN_BY, NEAR and its bot are used as they are. A body in another stage's city (a Behemoth in
## the stage 1 city) is not a state the game plays.

const SpawnView := preload("res://tests/lib/city_spawn_view.gd")
## The bodies: name, the upgrade-tree levels that make it (the evolutions, D-135) and its stage.
const FORMS: Array[Dictionary] = [
	{"name": "young", "levels": {}, "tier": 1},
	{"name": "Behemoth", "levels": {"evolve1": 1}, "tier": 2},
	{"name": "Colossus", "levels": {"evolve1": 1, "evolve2": 1}, "tier": 3},
]


## One check per body and map seed (check_fn(ok: bool, message: String) is the suite's `check`).
static func check(map_seeds: Array[int], check_fn: Callable) -> void:
	for form: Dictionary in FORMS:
		for map_seed: int in map_seeds:
			var got := measure(form, map_seed)
			var stepping: bool = got["stepping"]
			var right_body := (
				Num.i(got["size"]) == Num.i(form["tier"]) and (Num.i(form["tier"]) == 1 or stepping)
			)
			var down := Num.i(got["near"]) > 0 and Num.i(got["left"]) == 0
			(
				check_fn
				. call(
					right_body and down and Num.f(got["walked"]) <= SpawnView.DOWN_BY,
					(
						(
							"%s (size %d, stepping %s), map_seed %d: of the %d buildings within %.0f m"
							+ " of the rise point %d stand after %.1f s of walking in (down within %.0f s)"
						)
						% [
							str(form["name"]),
							Num.i(got["size"]),
							str(stepping),
							map_seed,
							Num.i(got["near"]),
							SpawnView.NEAR,
							Num.i(got["left"]),
							Num.f(got["walked"]),
							SpawnView.DOWN_BY
						]
					)
				)
			)


## Rises and walks one body in its own stage's city, as SpawnView.check does: {size (the sim's),
## stepping (the body walks by planted feet), near (buildings), left (standing at the end), walked
## (seconds)}.
static func measure(form: Dictionary, map_seed: int) -> Dictionary:
	var tier := Num.i(form["tier"])
	var base: Dictionary = Content.tuning().duplicate(true)
	var city_cfg: Dictionary = base["city"]
	city_cfg["map_seed"] = map_seed
	var levels: Dictionary = form["levels"]
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades(), levels, "reptilian")
	)
	var sim := RampageSim.new(
		stats,
		CityGrowth.tuning_for(base, tier),
		CityGrowth.layout(base, tier, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	var spawn: Vector2 = CityGen.map(sim.city).get("river_spawn", sim.kaiju_pos)
	var bank: Vector2 = CityGen.map(sim.city).get("river_bank", spawn)
	var near := SpawnView._near_buildings(sim, spawn, sim.clamp_to_arena(bank))
	sim.body.use_species("reptilian")
	sim.emerge.start(sim)
	var landed := false
	var guard := 0
	while not landed and guard < 3000:
		for event: Dictionary in sim.step(SpawnView.DT, Vector2.ZERO, false):
			landed = landed or str(event["type"]) == "kaiju_emerged"
		guard += 1
	var walked := 0.0
	while walked < SpawnView.WALK_LIMIT and SpawnView._standing(sim, near) > 0:
		var goal := SpawnView._nearest(sim, near)
		var to := goal - sim.kaiju_pos
		sim.step(SpawnView.DT, to.normalized() if to.length() > 0.2 else Vector2.ZERO, false)
		walked += SpawnView.DT
	var out := {
		"size": sim.size_tier(),
		"stepping": sim.body.stepping(),
		"near": near.size(),
		"left": SpawnView._standing(sim, near),
		"walked": walked,
	}
	sim.dispose()
	return out
