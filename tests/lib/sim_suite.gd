extends "res://tests/lib/runner.gd"
## The seeded rampage set-up the two sim suites share (tests/run_sim_tests.gd and
## tests/run_sim_play_tests.gd): an upgrade tree, the seeded city, a RampageSim for a species
## and levels, and the scripted player. It defines no test, so it adds no function to either
## suite's count. The sim suite was split in two so the timing-balanced CI shards can place
## its halves apart (one suite alone was ~9 min of one shard).

const DT := 1.0 / 30.0
const MAX_STEPS := 30 * 400


func _tree(levels: Dictionary = {}) -> UpgradeTree:
	return UpgradeTree.new(Content.upgrades(), levels)


func _layout(city: Dictionary = Content.section("city"), city_seed: int = 0) -> Array[Dictionary]:
	return CityGen.generate(Seeds.make("city", city_seed), city)


func _sim(
	species_id: String, levels: Dictionary, run_index: int = 0, tuning: Dictionary = {}
) -> RampageSim:
	return _sim_seeded(species_id, levels, tuning, Vector2i(0, run_index))


## _sim with both seeds: seeds.x picks the city (0: the suite's usual one), seeds.y seeds the army.
func _sim_seeded(
	species_id: String, levels: Dictionary, tuning: Dictionary, seeds: Vector2i
) -> RampageSim:
	var species := Content.species_def(species_id)
	var stats := UpgradeTree.run_stats(Content.section("kaiju"), species, _tree(levels))
	var ability: Dictionary = species["ability"]
	var tune := Content.tuning() if tuning.is_empty() else tuning
	var city: Dictionary = tune["city"]
	var layout := _layout(city, seeds.x)
	var sim := RampageSim.new(stats, tune, layout, Seeds.make("army", seeds.y))
	sim.ability_type = str(ability["type"])
	sim.body.use_species(species_id)
	return sim


## Scripted player: walk to the nearest standing building, use the signature when ready.
func _autoplay(sim: RampageSim, max_steps: int = MAX_STEPS) -> Dictionary:
	var steps := 0
	var target := Vector2(INF, INF)
	while not sim.over and steps < max_steps:
		if steps % 15 == 0:
			target = sim.nearest_standing(sim.kaiju_pos)
		var move := Vector2.ZERO
		if target.x < INF and sim.kaiju_pos.distance_to(target) > sim.stomp_radius() * 0.5:
			move = (target - sim.kaiju_pos).normalized()
		sim.step(DT, move, sim.ability_ready_in <= 0.0)
		steps += 1
	return sim.result()
