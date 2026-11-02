class_name LeapArc
extends RefCounted
## The height of the croc's leap through its flight (director 2026-10-26, "High arc, lands on roof":
## he springs high over the street and comes down on top of the target building). One parabola from
## the street at take-off to `land_y` (the target's roof, or the street) whose top clears, by
## `clear`, every building the body passes over on the way (its discs' footprints, each disc's
## bottom held above the roof), so the body never clips through a building in flight; a target
## taken in its side (`carve`, D-361) is not cleared: the arc ends at its facade and the body
## carves into it. Planned once at the press from the standing city; Dash reads at(). Part of
## Dash; pure, no randomness.

## The height it lands at (world units above the street) and the top of the arc.
var land_y := 0.0
var top := 0.0
## Buildings the planned path still passes through at the arc's height (0 when it clears them all).
var blocked := 0
## The building the leap takes in its side (D-361), set before plan(); -1 for none.
var carve := -1
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
## Buildings the body already overlaps at take-off are skipped (it stands among them), and so is
## `carve`, a building the leap takes in its side (D-361): the arc ends at its facade and the body
## carves into it rather than clearing it.
func plan(discs: Array, ends: PackedVector2Array, ahead: Vector2, numbers: Vector4) -> void:
	_discs = discs
	var start := ends[0]
	var land := ends[1]
	land_y = numbers.x
	var clear := numbers.y
	var skip := _overlaps(start, ahead)
	if carve >= 0:
		skip[carve] = true
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


## The first standing building (in path order) the body's discs pass over on the way from `ends[0]`
## to `ends[1]` along `ahead` that stands taller than `numbers.x` (world units), sampling every
## `numbers.y` units; buildings it overlaps at take-off are skipped. -1 for none. A leap never
## clears such a building: it takes it in its side (Dash.aim_at; director 2026-11-03, D-361).
func wall(discs: Array, ends: PackedVector2Array, ahead: Vector2, numbers: Vector2) -> int:
	_discs = discs
	var s := _sim.body_scale()
	var tall := _tall_near(ends, numbers.x)
	if tall.is_empty():
		return -1
	var skip := _overlaps(ends[0], ahead)
	var count := maxi(1, ceili(ends[0].distance_to(ends[1]) / maxf(numbers.y, 0.01)))
	for n: int in range(1, count + 1):
		var pose := ends[0].lerp(ends[1], float(n) / count)
		for d: Array in _discs:
			var c := pose + ahead * Num.f(d[0]) * s
			for i: int in tall:
				var b := _sim.buildings[i]
				var gap := Vector2(
					maxf(absf(c.x - b.x) - b.w * 0.5, 0.0), maxf(absf(c.y - b.z) - b.d * 0.5, 0.0)
				)
				if not skip.has(i) and gap.length() < Num.f(d[1]) * s:
					return i
	return -1


## The standing buildings taller than `limit` whose footprints may come within the body's reach
## of the segment `ends` (BuildingGrid, padded by the farthest disc's edge).
func _tall_near(ends: PackedVector2Array, limit: float) -> PackedInt32Array:
	var pad := 0.0
	for d: Array in _discs:
		pad = maxf(pad, absf(Num.f(d[0])) + Num.f(d[1]))
	pad *= _sim.body_scale()
	var lo := Vector2(minf(ends[0].x, ends[1].x), minf(ends[0].y, ends[1].y)) - Vector2.ONE * pad
	var hi := Vector2(maxf(ends[0].x, ends[1].x), maxf(ends[0].y, ends[1].y)) + Vector2.ONE * pad
	var out := PackedInt32Array()
	for i: int in _sim.grid.in_rect(lo, hi):
		var b := _sim.buildings[i]
		if b.frame.alive_count > 0 and float(b.height) > limit:
			out.append(i)
	return out


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
