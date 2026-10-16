class_name CityGen
extends RefCounted
## Seeded city layout: a grid of lots, towers taller toward downtown. Each building is a stack
## of floors; its tier (from height) decides how tough its structure is.


static func generate(rng: RandomNumberGenerator, cfg: Dictionary) -> Array[Dictionary]:
	var grid: int = Num.i(cfg["grid"])
	var spacing: float = Num.f(cfg["spacing"])
	var min_h: int = Num.i(cfg["min_height"])
	var max_h: int = Num.i(cfg["max_height"])
	var half := (grid - 1) * spacing * 0.5
	var centre := (grid - 1) * 0.5
	var out: Array[Dictionary] = []
	for gx: int in grid:
		for gz: int in grid:
			if rng.randf() < Num.f(cfg["empty_chance"]):
				continue
			var from_centre := clampf(
				Vector2(gx - centre, gz - centre).length() / (grid * 0.5), 0.0, 1.0
			)
			var cap := Num.i(lerpf(Num.f(max_h), Num.f(min_h + 3), from_centre))
			var height := rng.randi_range(min_h, maxi(min_h, cap))
			(
				out
				. append(
					{
						"x": gx * spacing - half,
						"z": gz * spacing - half,
						"w": rng.randi_range(2, Num.i(cfg["max_footprint"])),
						"d": rng.randi_range(2, Num.i(cfg["max_footprint"])),
						"h": height,
						"tier": tier_for_height(height, cfg),
						"style": rng.randi_range(0, 3),
					}
				)
			)
	return out


static func tier_for_height(height: int, cfg: Dictionary) -> int:
	var step: float = Num.f(cfg["tier_height"])
	return clampi(1 + Num.i(floor(Num.f(height - 1) / step)), 1, 4)


static func half_extent(cfg: Dictionary) -> float:
	return (Num.i(cfg["grid"]) - 1) * Num.f(cfg["spacing"]) * 0.5
