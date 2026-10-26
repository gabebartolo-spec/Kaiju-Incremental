extends RefCounted
## The city rings (district half-extents) of the young city before D-135 widened the cities: the
## sim fixtures (sim_suite.gd) were tuned on these plans, so they pin them, not the shipped one.

const HALVES: Array[int] = [42, 70, 125, 210]
const COASTS: Array[int] = [-112, -140, -195, -280]
const LOT_GROW: Array[int] = [0, 1, 2, 3]


## `base` (a copy of the tuning) with the pre-D-135 rings: four districts, the first two stages.
static func apply(base: Dictionary) -> void:
	var city: Dictionary = base["city"]
	city["half"] = HALVES[0]
	city["coast_z"] = COASTS[0]
	city["districts"] = HALVES.duplicate()
	city["district_lot_grow"] = LOT_GROW.duplicate()
	var stages: Array = base["growth"]["stages"]
	for k: int in 2:
		var over: Dictionary = stages[k]["city"]
		over["half"] = HALVES[k]
		over["coast_z"] = COASTS[k]
