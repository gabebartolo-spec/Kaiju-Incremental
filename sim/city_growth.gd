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
		if section == "per_level":
			continue
		var into: Dictionary = out[section]
		var over: Dictionary = stage[section]
		for key: String in over:
			into[key] = _copy(over[key])
	return out


## The game's tuning for a rampage with these run stats: their size tier picks the stage, and
## the levels bought inside that stage ("stage_growth") harden the army and air on top.
static func for_stats(stats: Dictionary) -> Dictionary:
	return tuning_for_stats(Content.tuning(), stats)


static func tuning_for_stats(tuning: Dictionary, stats: Dictionary) -> Dictionary:
	var tier := Num.i(stats.get("size", 1))
	var out := tuning_for(tuning, tier)
	return hardened(out, tuning, tier, Num.f(stats.get("stage_growth", 0.0)))


## The army learns (finding 1 of the active-incremental research, 2026-10-18): inside a stage,
## every upgrade level the kaiju buys scales the keys named in "growth.per_level" (or the
## stage's own "per_level") by (1 + fraction * levels), so defeat stays possible after the
## first evolution instead of the clock ending every run. Pure: stage tuning in, tuning out.
static func hardened(
	stage_tuning: Dictionary, tuning: Dictionary, tier: int, stage_growth: float
) -> Dictionary:
	var out: Dictionary = stage_tuning.duplicate(true)
	var per_level := per_level_for(tuning, tier)
	for section: String in per_level:
		if not out.has(section):
			continue
		var into: Dictionary = out[section]
		var fractions: Dictionary = per_level[section]
		for key: String in fractions:
			var mult := maxf(0.1, 1.0 + Num.f(fractions[key]) * stage_growth)
			into[key] = Num.f(into[key]) * mult
	return out


## The per-level fractions a tier escalates by: the stage's own "per_level" when it has one,
## else "growth.per_level", else nothing.
static func per_level_for(tuning: Dictionary, tier: int) -> Dictionary:
	var growth: Dictionary = tuning.get("growth", {})
	var stages := _stages(tuning)
	if not stages.is_empty():
		var stage: Dictionary = stages[clampi(tier - 1, 0, stages.size() - 1)]
		if stage.has("per_level"):
			return stage["per_level"]
	return growth.get("per_level", {})


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
