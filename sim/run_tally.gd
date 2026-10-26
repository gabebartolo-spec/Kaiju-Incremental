class_name RunTally
extends RefCounted
## The results screen's tally that only the sim can count (D-259 "Destruction tally": landmarks
## felled). A landmark is felled once it has lost tuning "results" "landmark_felled_share" of the
## chunks it stood with when the rampage began; a stadium never topples, so a share counts, not a
## fall. Pure sim: read when the rampage ends (RampageSim.result, which is result here).


## What `sim` (RampageSim) did, for the results screen (and the save's bests). "best_combo" is
## the combo system's hook (D-259): it is absent until the combo lands, and the screen shows a dash.
static func result(sim: RampageSim) -> Dictionary:
	return {
		"rubble": Num.i(floor(sim.rubble)),
		"destruction": sim.destruction(),
		"buildings": sim.collapse.destroyed_buildings(),
		"seconds": sim.elapsed,
		"tanks": sim.tanks_destroyed,
		"helis": sim.air.destroyed,
		"rooftops": sim.army_units.rooftops_destroyed,
		"agents": sim.army_units.taskforce.kills,
		"city_seconds": sim.army_units.taskforce.city_seconds(),
		"toppled": sim.collapse.toppled,
		"tallest_topple": sim.collapse.tallest_topple,
		"landmarks": landmarks_felled(sim.buildings),
		"reason": sim.end_reason,
	}


## How many landmarks in `buildings` (RampageSim.Building) are felled.
static func landmarks_felled(buildings: Array) -> int:
	var share := Num.f(Content.section("results")["landmark_felled_share"])
	var n := 0
	for b: RampageSim.Building in buildings:
		if b.landmark != "" and felled(b.start_chunks, b.frame.alive_count, share):
			n += 1
	return n


## True when a structure that started with `start` chunks and has `alive` left has lost `share`.
static func felled(start: int, alive: int, share: float) -> bool:
	return start > 0 and Num.f(start - alive) >= share * Num.f(start)
