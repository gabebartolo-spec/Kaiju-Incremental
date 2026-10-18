extends SceneTree
## D-075 numbers on CI (no local Godot): per stage and map_seed, how many green lots the
## playable city has, their share of its blocks, its buildings, and the furthest building from a
## park, plaza or green lot (the same measures as the city suite's green-lot checks), with green
## lots and without (city.green_lot_every emptied), so their cost in buildings shows.
##   tools/capture/ci_capture.sh green_lots_probe.gd

const GreenLots := preload("res://tests/lib/city_green_lots.gd")
const SEEDS: Array[int] = [7301, 1234, 98765]


func _initialize() -> void:
	for green: bool in [false, true]:
		for tier: int in [1, 2]:
			for map_seed: int in SEEDS:
				_probe(green, tier, map_seed)
	quit()


func _probe(green: bool, tier: int, map_seed: int) -> void:
	var base: Dictionary = Content.tuning().duplicate(true)
	var city: Dictionary = base["city"]
	city["map_seed"] = map_seed
	if not green:
		city["green_lot_every"] = []
	var stats := UpgradeTree.run_stats(
		Content.section("kaiju"),
		Content.species_def("reptilian"),
		UpgradeTree.new(Content.upgrades())
	)
	var sim := RampageSim.new(
		stats,
		CityGrowth.tuning_for(base, tier),
		CityGrowth.layout(base, tier, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	var lots := 0
	var half := CityGen.half_extent(sim.city)
	for block: Dictionary in CityGen.map(sim.city)["blocks"]:
		var rect: Rect2 = block["rect"]
		var c := rect.get_center()
		if block.has("green") and maxf(absf(c.x), absf(c.y)) <= half:
			lots += 1
	print(
		(
			(
				"green lots %s: stage %d, map_seed %d: %d lots, %.1f%% of the blocks; %d buildings;"
				+ " furthest building %.0f m from a park"
			)
			% [
				"on " if green else "off",
				tier,
				map_seed,
				lots,
				GreenLots._lot_share(sim.city) * 100.0,
				sim.buildings.size(),
				GreenLots._furthest(sim)
			]
		)
	)
