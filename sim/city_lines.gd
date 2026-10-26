class_name CityLines
extends RefCounted
## The street centre lines of the city plan on one axis (part of CityGen.map, split out to keep
## files small): across the first district, out through each later district, and on through the
## outskirts. Pure and seeded by the caller's streams.
##
## Each gap is drawn at random and then fitted (CityLineFit): the nearest gap to the draw that
## still lets the run reach its end line, never shorter than a block (so no block is cut thinner
## than a lot, director's audit D-265), and, where the diagonal avenue crosses, placed so the
## diagonal crosses every line mid-block: never in a grid crossing's junction box (director
## 2026-10-26 on a 6-way crossing: "No, split them apart"). The rule for each axis comes from
## CityLineFit.x_rule / z_rule.


## Street centre lines across the playable city on one axis: drawn gaps, with lines exactly on
## the ring (+-half).
static func across(
	rng: RandomNumberGenerator, half: float, lo: int, hi: int, rule: Dictionary
) -> Array[float]:
	var out: Array[float] = [-half]
	for p: int in CityLineFit.run(rng, roundi(-half), roundi(half), [lo, hi], rule):
		out.append(float(p))
	return out


## A district's street lines between the ring at +-from and its own ring at +-to, both ways,
## with the same block sizes as the city inside.
static func ring(
	rng: RandomNumberGenerator,
	lines: Array[float],
	span: Array[float],
	gaps: Array[int],
	rule: Dictionary
) -> void:
	for side: int in [1, -1]:
		var from := roundi(span[0]) * side
		for p: int in CityLineFit.run(rng, from, roundi(span[1]) * side, gaps, rule):
			_add(lines, float(p))


static func _add(lines: Array[float], v: float) -> void:
	if v > lines[lines.size() - 1]:
		lines.append(v)
	else:
		lines.push_front(v)


## Carries the lines on out to +-outer, both ways (no end line: the first past +-outer ends it).
static func extend(
	rng: RandomNumberGenerator, lines: Array[float], outer: float, gaps: Array[int], rule: Dictionary
) -> void:
	var open := rule.duplicate()
	open["open"] = true
	for p: int in CityLineFit.run(rng, roundi(lines[-1]), ceili(outer), gaps, open):
		lines.append(float(p))
	for p: int in CityLineFit.run(rng, roundi(lines[0]), -ceili(outer), gaps, open):
		lines.push_front(float(p))
