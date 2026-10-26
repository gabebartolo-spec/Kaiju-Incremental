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
## x-lines far apart, z-lines close; the outskirts' ("far_": city "block_far", m added to each
## bound) vary far more, so they are no even grid, but none is cut thinner than a lot between two
## avenues.
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
	var far: Dictionary = cfg["block_far"]
	var far_long: Array = far["long"]
	var far_short: Array = far["short"]
	out["far_long"] = (
		[maxi(Num.i(long[0]) + Num.i(far_long[0]), thin), Num.i(long[1]) + Num.i(far_long[1])]
		as Array[int]
	)
	out["far_short"] = (
		[maxi(Num.i(short[0]) + Num.i(far_short[0]), thin), Num.i(short[1]) + Num.i(far_short[1])]
		as Array[int]
	)
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


## Every street line of the plan and its avenues: {xs, zs, avenues_x, avenues_z} (line indices),
## and "breaks": the rules the fitted runs break (CityLineFit's fewest-breaks fallback; 0 when
## every run fits clean).
## rng: the plan's own stream (the first district's lines and the avenue picks); later districts
## and the outskirts draw from their own (map_seed + 2, + 1).
static func draw(rng: RandomNumberGenerator, cfg: Dictionary, diag: Dictionary) -> Dictionary:
	var rings := CityGen.districts(cfg)
	var outer := Num.f(cfg["outer_half"])
	var x_rule := CityLineFit.x_rule(cfg, diag, rings)
	var gaps := gaps(cfg)
	# Each later district's streets, out to its own ring avenue, draw from their own stream; the
	# outskirts from theirs, so tuning them never reshuffles the city. The x-lines come first: the
	# z-lines then sit between the diagonal's crossings with them (CityLineFit).
	var grow := RandomNumberGenerator.new()
	grow.seed = Num.i(cfg["map_seed"]) + 2
	var far := RandomNumberGenerator.new()
	far.seed = Num.i(cfg["map_seed"]) + 1
	var streams: Array[RandomNumberGenerator] = [rng, grow, far]
	var report := {"breaks": 0}
	x_rule["report"] = report
	var inner_rule := x_rule.duplicate()
	inner_rule["avenue"] = true  # room for the inner avenue (CityLineFit)
	var xs := _lay(streams, rings, outer, [gaps["long"], gaps["far_long"]], x_rule, inner_rule)
	var x_fits := func(i: int) -> bool: return CityLineFit.avenue_fits_x(x_rule, xs, i)
	var avenues_x := avenues(rng, xs, rings, x_fits, cfg)
	var avenue_at: Array[float] = []
	for i: int in avenues_x:
		avenue_at.append(xs[i])
	var z_rule := CityLineFit.z_rule(cfg, diag, xs, rings, avenue_at)
	z_rule["report"] = report
	var zs := _lay(streams, rings, outer, [gaps["short"], gaps["far_short"]], z_rule, z_rule)
	var need := (
		CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5 + CityGen.width_of(CityGen.AVENUE, cfg) * 0.5
	)
	var z_fits := func(j: int) -> bool: return CityLineFit.clearance(diag, "z", zs[j], xs) >= need
	var avenues_z := avenues(rng, zs, rings, z_fits, cfg)
	return {
		"xs": xs,
		"zs": zs,
		"avenues_x": avenues_x,
		"avenues_z": avenues_z,
		"breaks": Num.i(report["breaks"]),
	}


## One axis's lines: across the first district from streams[0] (with `first`, its rule), out
## through each later district from streams[1] and on through the outskirts to +-`outer` from
## streams[2] (with `rule`). bounds: [gaps, far gaps] (gaps).
static func _lay(
	streams: Array[RandomNumberGenerator],
	rings: Array[float],
	outer: float,
	bounds: Array,
	rule: Dictionary,
	first: Dictionary
) -> Array[float]:
	var near: Array[int] = bounds[0]
	var far: Array[int] = bounds[1]
	var out := across(streams[0], rings[0], near[0], near[1], first)
	for k: int in range(1, rings.size()):
		ring(streams[1], out, [rings[k - 1], rings[k]] as Array[float], near, rule)
	extend(streams[2], out, outer, far, rule)
	return out


## The rules the plan of `cfg` breaks to fit its street lines (draw's "breaks"; CityLineFit's
## fewest-breaks fallback): 0 when the diagonal and the rings let every run fit clean.
static func fit_breaks(cfg: Dictionary) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = Num.i(cfg["map_seed"])  # CityGen.map's own stream
	return Num.i(draw(rng, cfg, CityGen.diagonal_of(cfg))["breaks"])
