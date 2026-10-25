extends "res://tests/lib/runner.gd"
## The seeded rampage set-up the two sim suites share (tests/run_sim_tests.gd and
## tests/run_sim_play_tests.gd): an upgrade tree, the seeded city, a RampageSim for a species
## and levels, and the scripted player. It defines no test, so it adds no function to either
## suite's count. The sim suite was split in two so the timing-balanced CI shards can place
## its halves apart (one suite alone was ~9 min of one shard).

const DT := 1.0 / 30.0
const MAX_STEPS := 30 * 400
const Rings := preload("res://tests/lib/fixture_rings.gd")


func _tree(levels: Dictionary = {}) -> UpgradeTree:
	return UpgradeTree.new(Content.upgrades(), levels)


## The sim fixtures play in the pre-D-135 young city (tests/lib/fixture_rings.gd), seed 0 unless a
## test asks for another (`city_seed`: the body chew checks run seeds 3, 8 and 22): the topple and
## swipe fixtures need a tall tier-2 office tower inside the arena and their finder (_nearest_of)
## falls back on the last building when none matches. The half-50 city has none at seeds 0-9, so
## the fixtures keep the plan they were made on.
func _fixture_tuning() -> Dictionary:
	var tuning: Dictionary = Content.tuning().duplicate(true)
	Rings.apply(tuning)
	return tuning


func _layout(city: Dictionary = {}, city_seed: int = 0) -> Array[Dictionary]:
	var cfg: Dictionary = city if not city.is_empty() else _fixture_tuning()["city"]
	return CityGen.generate(Seeds.make("city", city_seed), cfg)


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
	var tune := _fixture_tuning() if tuning.is_empty() else tuning
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
		if target.x < INF and not sim.body.stomp_reaches(target):
			move = (target - sim.kaiju_pos).normalized()
		sim.step(DT, move, sim.ability_ready_in <= 0.0, RampageSim.STOMP)
		steps += 1
	return sim.result()
