class_name Growth
extends RefCounted
## How big a kaiju is for a set of run stats. It starts young, dwarfed by the city; every
## upgrade level grows it a little ("growth" = levels owned), every evolution a lot. Pure, so
## the evolution reveal can compare the body before and after a purchase without a rampage.


## The run stats a rampage plays on at its size tier: the stage's tuning "move.speed_mult" scales
## the kaiju's speed (D-074: the young stage walks as a heavy toddler, not a sprinting cub).
static func stage_stats(stats: Dictionary, tuning: Dictionary) -> Dictionary:
	var out := stats.duplicate()
	var move: Dictionary = tuning.get("move", {})
	out["speed"] = Num.f(stats.get("speed", 0.0)) * Num.f(move.get("speed_mult", 1.0))
	return out


static func body_scale(stats: Dictionary, city: Dictionary) -> float:
	var size := Num.f(stats.get("size", 1.0))
	var tier := 1.0 + Num.f(city["size_scale_per_tier"]) * (size - 1.0)
	var growth := 1.0 + Num.f(city["growth_per_level"]) * Num.f(stats.get("growth", 0.0))
	return Num.f(city["young_scale"]) * tier * growth
