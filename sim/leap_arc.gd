class_name LeapArc
extends RefCounted
## The height of the croc's leap through its flight (director 2026-10-26, "High arc, lands on roof":
## he springs high over the street and comes down on top of the target building). One parabola from
## the street at take-off to `land_y` (the target's roof, or the street) whose top clears, by
## `clear`, every building the body passes over on the way (its discs' footprints, each disc's
## bottom held above the roof), so the body never clips through a building in flight. Planned once
## at the press from the standing city; Dash reads at(). Part of Dash; pure, no randomness.

## The height it lands at (world units above the street) and the top of the arc.
var land_y := 0.0
var top := 0.0
## Buildings the planned path still passes through at the arc's height (0 when it clears them all).
var blocked := 0
var _a := 0.0
var _b := 0.0
var _sim: RampageSim
var _discs: Array = []


func _init(sim: RampageSim) -> void:
	_sim = sim


## Height (world units) at `f` of the flight, 0..1: 0 at take-off, land_y at the contact.
func at(f: float) -> float:
	return -_a * f * f + _b * f


## Plans the arc of a leap from `start` to `land` along `ahead` (kaiju_pos both; the body's discs at
## body scale 1), landing at `p_land_y`: samples the path every `step` units, then raises the top
## by `clear` at a time (at most `tries` times) until every sample clears what it passes over.
## Buildings the body already overlaps at take-off are skipped (it stands among them).
func plan(discs: Array, ends: PackedVector2Array, ahead: Vector2, numbers: Vector4) -> void:
	_discs = discs
	var start := ends[0]
	var land := ends[1]
	land_y = numbers.x
	var clear := numbers.y
	var skip := _overlaps(start, ahead)
	var span := start.distance_to(land)
	var count := maxi(1, ceili(span / maxf(numbers.z, 0.01)))
	var needs := PackedVector2Array()
	top = land_y
	for i: int in range(1, count + 1):
		var f := float(i) / count
		var need := _need(start.lerp(land, f), ahead, skip)
		needs.append(Vector2(f, need))
		top = maxf(top, need)
	top += clear
	for _n: int in Num.i(numbers.w):
		_fit()
		blocked = 0
		for need: Vector2 in needs:
			blocked += 1 if at(need.x) < need.y else 0
		if blocked == 0:
			return
		top += clear


## The parabola through (0, 0) and (1, land_y) peaking at `top`.
func _fit() -> void:
	var peak := maxf(top, maxf(land_y, 0.001))
	_b = 2.0 * peak + 2.0 * sqrt(maxf(0.0, peak * (peak - land_y)))
	_a = _b - land_y


## How high the body must be lifted at `pose` to pass over every standing building its discs
## overlap there (but those in `skip`): a building's height less the disc's bottom.
func _need(pose: Vector2, ahead: Vector2, skip: Dictionary) -> float:
	var s := _sim.body_scale()
	var need := 0.0
	for d: Array in _discs:
		var c := pose + ahead * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		for i: int in _sim.buildings.size():
			var b := _sim.buildings[i]
			if b.frame.alive_count == 0 or skip.has(i):
				continue
			var gap := Vector2(
				maxf(absf(c.x - b.x) - b.w * 0.5, 0.0), maxf(absf(c.y - b.z) - b.d * 0.5, 0.0)
			)
			if gap.length() < r:
				need = maxf(need, b.height - Num.f(d[2]) * s)
	return need


## The standing buildings the discs overlap at `pose`: {index: true}.
func _overlaps(pose: Vector2, ahead: Vector2) -> Dictionary:
	var s := _sim.body_scale()
	var out := {}
	for d: Array in _discs:
		var c := pose + ahead * Num.f(d[0]) * s
		var r := Num.f(d[1]) * s
		for i: int in _sim.buildings.size():
			var b := _sim.buildings[i]
			var gap := Vector2(
				maxf(absf(c.x - b.x) - b.w * 0.5, 0.0), maxf(absf(c.y - b.z) - b.d * 0.5, 0.0)
			)
			if b.frame.alive_count > 0 and gap.length() < r:
				out[i] = true
	return out
