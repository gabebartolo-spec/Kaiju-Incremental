class_name Growth
extends RefCounted
## How big a kaiju is for a set of run stats. It starts young, dwarfed by the city; every
## upgrade level grows it a little ("growth" = levels owned), every evolution a lot. Pure, so
## the evolution reveal can compare the body before and after a purchase without a rampage.


static func body_scale(stats: Dictionary, city: Dictionary) -> float:
	var size := Num.f(stats.get("size", 1.0))
	var tier := 1.0 + Num.f(city["size_scale_per_tier"]) * (size - 1.0)
	var growth := 1.0 + Num.f(city["growth_per_level"]) * Num.f(stats.get("growth", 0.0))
	return Num.f(city["young_scale"]) * tier * growth
