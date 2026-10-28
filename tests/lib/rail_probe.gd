extends RefCounted
## The trains suite's readings of a sim's railway (split out of run_trains_tests.gd to keep files
## small).


## The piece of the line at world z (its index in the sim's buildings), or -1.
static func piece_at(sim: RampageSim, z: float) -> int:
	for n: int in sim.rail.pieces:
		var b := sim.buildings[n]
		if absf(z - b.z) < b.d * 0.5:
			return n
	return -1


## The cells the carve took from building n over `events` (cells_carved), as grid indices.
static func carved(events: Array[Dictionary], n: int) -> Dictionary:
	var out := {}
	for event: Dictionary in events:
		if str(event["type"]) == "cells_carved" and Num.i(event["building"]) == n:
			var index: PackedInt32Array = event["index"]
			for i: int in index:
				out[i] = true
	return out
