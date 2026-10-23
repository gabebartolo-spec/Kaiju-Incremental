class_name HudCounts
extends RefCounted
## What the rampage HUD adds to the sim's result and shows on its clock (kept out of
## rampage_hud.gd, which sits at the 400-line cap).


## What only the view counts: the civilians the kaiju crushed and those who fled the streets.
static func of(street: StreetLife) -> Dictionary:
	return {
		"civilians": street.civilians_killed() if street != null else 0,
		"fled": street.fled if street != null else 0,
	}


## The clock: whole seconds left; Endless mode has no countdown, so it counts up as m:ss.
static func clock(sim: RampageSim) -> String:
	if sim.endless == null:
		return "%d" % ceili(maxf(0.0, sim.time_left))
	return "%d:%02d" % [int(sim.elapsed) / 60, int(sim.elapsed) % 60]
