class_name CitySeed
extends RefCounted
## Which city a run plays in: the one place the game turns a save's seed and a run index into the
## city's config (its street plan's map_seed) and the stream its buildings draw from. The city
## audits (tools/audit/seed_audit.gd) measure the game through this, so a change here is what
## makes runs differ (D-263 "Different per save": each save slot's own seed plus the run index).
## The buildings change with both (the stream below); the street plan is still the stage's tuned
## city.map_seed (D-261's few tested plans per stage are their own row). The same save seed and run
## index always give the same city. Pure.

const STREAM := "city"


## The stage's tuning for this run (CityGrowth.tuning_for), its city config the run's own.
static func tuning(base: Dictionary, tier: int, _save_seed: int, _run_index: int) -> Dictionary:
	return CityGrowth.tuning_for(base, tier)


## The stream the run's buildings draw from (CityGen.generate): the run index's stream, salted
## by the save's seed, so two slots on the same run play different cities.
static func stream(save_seed: int, run_index: int) -> RandomNumberGenerator:
	return Seeds.derive(Seeds.make(STREAM, run_index), save_seed)


## The run's buildings: CityGen.generate on the run's city config and stream.
static func layout(
	base: Dictionary, tier: int, save_seed: int, run_index: int
) -> Array[Dictionary]:
	var cfg: Dictionary = tuning(base, tier, save_seed, run_index)["city"]
	return CityGen.generate(stream(save_seed, run_index), cfg)
