class_name CityGrowth
extends RefCounted
## The city grows with each evolution (D-039). data/tuning.json "growth.stages" holds one stage
## per size tier (young, Behemoth, Colossus, Apex Titan); each stage overrides keys of the
## tuning sections it names: the city's playable half-extent, its coast and height cap, and
## harder defences (more and tougher tanks, helicopters from the Behemoth on). The street plan
## itself spans every district at every stage (CityGen.districts), so an evolution opens new
## districts round the one the kaiju already knows. Pure: tuning in, tuning out.


## The tuning a rampage at this size tier runs on: a deep copy of `tuning` with the stage's
## overrides applied. Tiers past the last stage use the last stage.
static func tuning_for(tuning: Dictionary, tier: int) -> Dictionary:
	var out: Dictionary = tuning.duplicate(true)
	var stages := _stages(tuning)
	if stages.is_empty():
		return out
	var stage: Dictionary = stages[clampi(tier - 1, 0, stages.size() - 1)]
	for section: String in stage:
		var into: Dictionary = out[section]
		var over: Dictionary = stage[section]
		for key: String in over:
			into[key] = _copy(over[key])
	return out


## The game's tuning for a rampage with these run stats (their size tier picks the stage).
static func for_stats(stats: Dictionary) -> Dictionary:
	return tuning_for(Content.tuning(), Num.i(stats.get("size", 1)))


## The playable city of a size tier, seeded from `rng` (CityGen.generate on the stage's city).
static func layout(tuning: Dictionary, tier: int, rng: RandomNumberGenerator) -> Array[Dictionary]:
	var cfg: Dictionary = tuning_for(tuning, tier)["city"]
	return CityGen.generate(rng, cfg)


static func stage_count(tuning: Dictionary) -> int:
	return _stages(tuning).size()


static func _stages(tuning: Dictionary) -> Array:
	var growth: Dictionary = tuning.get("growth", {})
	var stages: Array = growth.get("stages", [])
	return stages


static func _copy(value: Variant) -> Variant:
	if value is Array:
		var arr: Array = value
		return arr.duplicate(true)
	if value is Dictionary:
		var dict: Dictionary = value
		return dict.duplicate(true)
	return value
