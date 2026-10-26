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
	rng: RandomNumberGenerator,
	lines: Array[float],
	outer: float,
	gaps: Array[int],
	rule: Dictionary
) -> void:
	var open := rule.duplicate()
	open["open"] = true
	for p: int in CityLineFit.run(rng, roundi(lines[-1]), ceili(outer), gaps, open):
		lines.append(float(p))
	for p: int in CityLineFit.run(rng, roundi(lines[0]), -ceili(outer), gaps, open):
		lines.push_front(float(p))


## The street lines' gap bounds [lo, hi], m: long blocks one way, short the other (Manhattan):
## x-lines far apart, z-lines close; the outskirts' ("far_") vary far more, so they are no even
## grid, but none is cut thinner than a lot between two avenues.
static func gaps(cfg: Dictionary) -> Dictionary:
	var long: Array = cfg["block_long"]
	var short: Array = cfg["block_short"]
	var thin := roundi(
		CityGen.width_of(CityGen.AVENUE, cfg) + 2.0 * Num.f(cfg["sidewalk"]) + CityGen.MIN_LOT_M
	)
	var out := {
		"long": [Num.i(long[0]), Num.i(long[1])] as Array[int],
		"short": [Num.i(short[0]), Num.i(short[1])] as Array[int],
	}
	out["far_long"] = [maxi(Num.i(long[0]) - 6, thin), Num.i(long[1]) + 14] as Array[int]
	out["far_short"] = [maxi(Num.i(short[0]) - 2, thin), Num.i(short[1]) + 12] as Array[int]
	return out


## Every district's ring lines and one or two lines through the first district are avenues; an
## inner avenue is a line `fits` allows (the diagonal crosses it clear of the grid at an
## avenue's width, CityLineFit), when there is one.
static func avenues(
	rng: RandomNumberGenerator,
	lines: Array[float],
	rings: Array[float],
	fits: Callable,
	cfg: Dictionary
) -> Dictionary:
	var out := {}
	var inner: Array[int] = []
	var clear: Array[int] = []
	for i: int in lines.size():
		var ring := false
		for h: float in rings:
			ring = ring or is_equal_approx(absf(lines[i]), h)
		if ring:
			out[i] = true
		elif absf(lines[i]) < rings[0]:
			inner.append(i)
			if fits.call(i):
				clear.append(i)
	if not clear.is_empty():
		inner = clear
	for n: int in mini(Num.i(cfg["avenues"]), inner.size()):
		var pick := inner[rng.randi_range(0, inner.size() - 1)]
		inner.erase(pick)
		out[pick] = true
	return out


## Every street line of the plan and its avenues: {xs, zs, avenues_x, avenues_z} (line indices).
## rng: the plan's own stream (the first district's lines and the avenue picks); later districts
## and the outskirts draw from their own (map_seed + 2, + 1).
static func draw(rng: RandomNumberGenerator, cfg: Dictionary, diag: Dictionary) -> Dictionary:
	var rings := CityGen.districts(cfg)
	var outer := Num.f(cfg["outer_half"])
	var x_rule := CityLineFit.x_rule(cfg, diag, rings)
	var gaps := gaps(cfg)
	var long_gaps: Array[int] = gaps["long"]
	var short_gaps: Array[int] = gaps["short"]
	var far_long: Array[int] = gaps["far_long"]
	var far_short: Array[int] = gaps["far_short"]
	# Each later district's streets, out to its own ring avenue, draw from their own stream; the
	# outskirts from theirs, so tuning them never reshuffles the city. The x-lines come first: the
	# z-lines then sit between the diagonal's crossings with them (CityLineFit).
	var grow := RandomNumberGenerator.new()
	grow.seed = Num.i(cfg["map_seed"]) + 2
	var far := RandomNumberGenerator.new()
	far.seed = Num.i(cfg["map_seed"]) + 1
	var inner_rule := x_rule.duplicate()
	inner_rule["avenue"] = true  # room for the inner avenue (CityLineFit)
	var xs := across(rng, rings[0], long_gaps[0], long_gaps[1], inner_rule)
	for k: int in range(1, rings.size()):
		ring(grow, xs, [rings[k - 1], rings[k]] as Array[float], long_gaps, x_rule)
	extend(far, xs, outer, far_long, x_rule)
	var x_fits := func(i: int) -> bool: return CityLineFit.avenue_fits_x(x_rule, xs, i)
	var avenues_x := avenues(rng, xs, rings, x_fits, cfg)
	var avenue_at: Array[float] = []
	for i: int in avenues_x:
		avenue_at.append(xs[i])
	var z_rule := CityLineFit.z_rule(cfg, diag, xs, rings, avenue_at)
	var zs := across(rng, rings[0], short_gaps[0], short_gaps[1], z_rule)
	for k: int in range(1, rings.size()):
		ring(grow, zs, [rings[k - 1], rings[k]] as Array[float], short_gaps, z_rule)
	extend(far, zs, outer, far_short, z_rule)
	var need := (
		CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + CityGen.width_of(CityGen.AVENUE, cfg) * 0.5
	)
	var z_fits := func(j: int) -> bool: return CityLineFit.clearance(diag, "z", zs[j], xs) >= need
	var avenues_z := avenues(rng, zs, rings, z_fits, cfg)
	return {"xs": xs, "zs": zs, "avenues_x": avenues_x, "avenues_z": avenues_z}
