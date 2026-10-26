extends "res://tests/lib/powers_base.gd"
## Shared scene-building for the leader's helicopter suite (run_vip_tests): a rampage with one
## pad and the kaiju beside it, the leader called in, stepped and run with fixed input.

const PAD := Vector3i(3, 3, 5)
const KAIJU_AT := Vector2(-4.0, 0.0)


## A rampage with one pad (a 5-floor block) and the kaiju beside it, the leader called in now:
## stepped once, so it is on the pad.
func _flying(species_id := "reptilian", levels := {}, seed_index := 0) -> RampageSim:
	var species := Content.species_def(species_id)
	var sim := RampageSim.new(
		_stats(species_id, levels), Content.tuning(), _layout(), Seeds.make("army", seed_index)
	)
	var ability: Dictionary = species["ability"]
	sim.ability_type = str(ability["type"])
	sim.kaiju_pos = KAIJU_AT
	sim.facing = EAST
	sim.vip._spawn_at = 0.0
	sim.step(DT, Vector2.ZERO, false)
	return sim


func _events_of(sim: RampageSim, kind: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for event: Dictionary in sim.events:
		if str(event["type"]) == kind:
			out.append(event)
	return out


## Steps until the leader is no longer flying (or `seconds` pass); returns the seconds it flew.
func _until_over(sim: RampageSim, seconds: float) -> float:
	var flown := 0.0
	while sim.vip.flying() and flown < seconds:
		sim.step(DT, Vector2.ZERO, false)
		flown += DT
	return flown


func _sim_seeded(n: int) -> RampageSim:
	var sim := RampageSim.new(
		_stats("reptilian", {}), Content.tuning(), _layout(), Seeds.make("army", n)
	)
	sim.kaiju_pos = KAIJU_AT
	return sim


func _stats(species_id: String, levels: Dictionary) -> Dictionary:
	var tree := UpgradeTree.new(Content.upgrades(), levels, species_id)
	return UpgradeTree.run_stats(Content.section("kaiju"), Content.species_def(species_id), tree)


func _layout() -> Array[Dictionary]:
	return [_b(10.0, 0.0, PAD), _b(38.0, 38.0, Vector3i(2, 2, 2))]


func _spawn_times() -> Array[float]:
	var out: Array[float] = []
	for n: int in 5:
		var sim := _sim_seeded(n)
		out.append(_first_spawn(sim))
	return out


func _first_spawn(sim: RampageSim) -> float:
	for i: int in 30 * 120:
		for event: Dictionary in sim.step(DT, Vector2.ZERO, false):
			if str(event["type"]) == "vip_spawned":
				return sim.elapsed
	return -1.0
