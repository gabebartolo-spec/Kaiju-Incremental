class_name CityLines
extends RefCounted
## The street centre lines of the city plan on one axis (part of CityGen.map, split out to keep
## files small): across the first district, out through each later district, and on through the
## outskirts. Pure and seeded by the caller's streams.


## Street centre lines across the playable city on one axis: random gaps, with lines exactly
## on the ring (+-half).
static func across(rng: RandomNumberGenerator, half: float, lo: int, hi: int) -> Array[float]:
	var out: Array[float] = [-half]
	var p := -half
	while half - p > hi + lo:
		p += rng.randi_range(lo, hi)
		out.append(p)
	if half - p > hi:  # split a long last gap in two
		out.append(p + roundi((half - p) * 0.5))
	out.append(half)
	return out


## A district's street lines between the ring at +-from and its own ring at +-to, both ways,
## with the same block sizes as the city inside.
static func ring(
	rng: RandomNumberGenerator, lines: Array[float], from: float, to: float, lo: int, hi: int
) -> void:
	for side: float in [1.0, -1.0]:
		var p := from
		while to - p > hi + lo:
			p += rng.randi_range(lo, hi)
			_add(lines, p * side)
		if to - p > hi:  # split a long last gap in two
			_add(lines, (p + roundi((to - p) * 0.5)) * side)
		_add(lines, to * side)


static func _add(lines: Array[float], v: float) -> void:
	if v > lines[lines.size() - 1]:
		lines.append(v)
	else:
		lines.push_front(v)


## Carries the lines on out to +-outer, both ways.
static func extend(
	rng: RandomNumberGenerator, lines: Array[float], outer: float, lo: int, hi: int
) -> void:
	var p := lines[lines.size() - 1]
	while p < outer:
		p += rng.randi_range(lo, hi)
		lines.append(p)
	p = lines[0]
	while p > -outer:
		p -= rng.randi_range(lo, hi)
		lines.push_front(p)
