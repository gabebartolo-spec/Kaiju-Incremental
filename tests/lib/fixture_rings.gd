extends RefCounted
## The city rings (district half-extents) the fixture seeds of city_diag_fill.gd and
## junction_island.gd were chosen on, before D-135 widened the cities: those two rules are shown
## to be needed on exact plans where a bare cell appears (a street, an avenue and the diagonal
## meet, or the diagonal cuts a block to a sliver), and in the widened plans (50/80/150) no
## seed out of about 500 scanned (2026-10-23) leaves such a cell, only riverside ones, which
## RiverQuay fills. The fixtures therefore pin their own plan, not the shipped one.

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
