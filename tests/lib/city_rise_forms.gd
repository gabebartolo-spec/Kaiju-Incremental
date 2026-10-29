extends RefCounted
## The rise bar (tests/lib/city_spawn_view.gd, D-384: his first beachfront hotel is down within
## DOWN_BY seconds of him standing up out of the sea) for each body the game really
## plays: the young croc in the stage 1 city, the Behemoth in the stage 2 city and the Colossus in
## the stage 3 city (a run's stats.size picks both, CityGrowth.tuning_for_stats), on every map seed.
## The Behemoth and the Colossus make heavy stepped U-turns (D-187, D-192 "A: short steps"), so a
## bot that walks at the nearest standing chunk loses time turning. The bar is the director's
## (D-131: 10 s stays; D-192: "what the hell, no?" to 12 s) and is not changed: SpawnView's
## DOWN_BY and its bot are used as they are. A body in another stage's city (a Behemoth in
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
			var down := Num.i(got["hotels"]) > 0 and Num.f(got["seconds"]) <= SpawnView.DOWN_BY
			check_fn.call(
				right_body and down,
				(
					(
						"%s (size %d, stepping %s), map_seed %d: first of %d beachfront hotels"
						+ " down %.1f s after he stands (within %.0f s)"
					)
					% [
						str(form["name"]),
						Num.i(got["size"]),
						str(stepping),
						map_seed,
						Num.i(got["hotels"]),
						Num.f(got["seconds"]),
						SpawnView.DOWN_BY
					]
				)
			)


## Rises and walks one body in its own stage's city, as SpawnView.check does: {size (the sim's),
## stepping (the body walks by planted feet), hotels, seconds (SpawnView.first_hotel)}.
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
	sim.body.use_species("reptilian")
	var got := SpawnView.first_hotel(sim)
	var out := {
		"size": sim.size_tier(),
		"stepping": sim.body.stepping(),
		"hotels": got["hotels"],
		"seconds": got["seconds"],
	}
	sim.dispose()
	return out
