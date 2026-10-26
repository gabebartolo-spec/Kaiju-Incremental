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
## The plan's other keys as they were before D-254 widened the play area 1.5x (cores, the
## diagonal and the skyline moved with it): pinned too, so the fixtures keep their plan.
const CORES: Array = [
	[14, -14, 30],
	[-24, 24, 20],
	[54, 48, 22],
	[-52, -50, 20],
	[72, -64, 30],
	[-68, 66, 28],
	[94, 86, 36],
	[-90, -88, 34],
	[6, 94, 30],
	[165, -150, 46],
	[-170, 145, 46],
	[175, 115, 40],
	[-150, -170, 42],
	[10, 180, 44],
	[-185, -20, 38]
]
const OUTER_CORES: Array = [
	[30, -80, 40],
	[110, -60, 45],
	[-120, -60, 35],
	[130, 120, 30],
	[210, 30, 35],
	[-200, 90, 30],
	[40, 220, 35],
	[-110, 250, 25],
	[260, -40, 30]
]
const OUTER_HALF := 360
const DIAGONAL_THROUGH: Array = [-6, 4]
## The landmarks where they stood before CitySpread (id: [anchor x, z], margin); no bridge.
## One park a district, as before D-254 (CityParks: at least one, and none more at this size).
const PARK_EVERY := 1000000000
const LANDMARKS := {"stadium": [[-24, -57], 0], "wheel": [[30, -56], 2]}


## `base` (a copy of the tuning) with the pre-D-135 rings: four districts, the first two stages.
static func apply(base: Dictionary) -> void:
	var city: Dictionary = base["city"]
	city["half"] = HALVES[0]
	city["coast_z"] = COASTS[0]
	city["districts"] = HALVES.duplicate()
	city["district_lot_grow"] = LOT_GROW.duplicate()
	city["cores"] = CORES.duplicate(true)
	city["outer_cores"] = OUTER_CORES.duplicate(true)
	city["outer_half"] = OUTER_HALF
	city["diagonal_through"] = DIAGONAL_THROUGH.duplicate()
	var pinned: Array = []
	for spec: Dictionary in city["landmarks"]:
		if LANDMARKS.has(spec["id"]):
			var keep: Dictionary = spec.duplicate(true)
			var at: Array = LANDMARKS[spec["id"]]
			keep["anchor"] = at[0]
			keep["margin"] = at[1]
			pinned.append(keep)
	city["landmarks"] = pinned
	city["park_every"] = PARK_EVERY
	var stages: Array = base["growth"]["stages"]
	for k: int in 2:
		var over: Dictionary = stages[k]["city"]
		over["half"] = HALVES[k]
		over["coast_z"] = COASTS[k]
		over.erase("outer_cores")  # the stage's own skyline (D-254) for the 1.5x play area
