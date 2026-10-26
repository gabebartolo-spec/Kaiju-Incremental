class_name CitySeed
extends RefCounted
## Which city a run plays in: the one place the game turns a save's seed and a run index into the
## city's config (its street plan's map_seed) and the stream its buildings draw from. The city
## audits (tools/audit/seed_audit.gd) measure the game through this, so a change here is what
## makes runs differ (D-263 "Different per save": each save slot's own seed plus the run index).
## Today every run of a stage builds the same city (D-261): city.map_seed as tuned and building
## stream index 0, whatever the save or run. Pure.

const STREAM := "city"


## The stage's tuning for this run (CityGrowth.tuning_for), its city config the run's own.
static func tuning(base: Dictionary, tier: int, _save_seed: int, _run_index: int) -> Dictionary:
	return CityGrowth.tuning_for(base, tier)


## The stream the run's buildings draw from (CityGen.generate).
static func stream(_save_seed: int, _run_index: int) -> RandomNumberGenerator:
	return Seeds.make(STREAM, 0)


## The run's buildings: CityGen.generate on the run's city config and stream.
static func layout(
	base: Dictionary, tier: int, save_seed: int, run_index: int
) -> Array[Dictionary]:
	var cfg: Dictionary = tuning(base, tier, save_seed, run_index)["city"]
	return CityGen.generate(stream(save_seed, run_index), cfg)
