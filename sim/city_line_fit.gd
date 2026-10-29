class_name CityLineFit
extends RefCounted
## Fits one run of street lines (CityLines) between two lines, on whole metres: each gap is drawn
## from the caller's stream as before, then the gap nearest the draw is taken that still lets the
## run end on its end line, never under `lo` (the narrowest block a lot fits in) and never so
## that the diagonal avenue meets the grid in an overlapping junction (director 2026-10-26 on a
## 6-way crossing: "No, split them apart"; the city audit's "close!" rule, D-265).
##
## The diagonal (z = c at an x-line) and the grid meet cleanly when, on every x-line, its
## crossing c lies at least s from every z-line: s = half the diagonal's width plus half the
## widest street of the grid crossing (street or avenue). So:
## - x_rule: an x-line's c keeps s_avenue off the fixed ring z-lines, and two x-lines' c values lie
##   far enough apart for a z-line to sit between them (s each side, plus a metre for whole
##   metres): the x blocks along the diagonal draw a little longer;
## - z_rule: a z-line keeps s off every x-line's c (one z-line sits between each two crossings).
## A run with no clean fit breaks as few of these rules as it can.
## Pure: the same stream, ends and rule give the same lines.

const BIG := 1 << 20  # an unreachable run's cost
const STEP := 1.0  # lines sit on whole metres; a z-line needs a window this wide between crossings


## The lines after `start` up to `end` (included), or for rule["open"] up to the first one
## at or past `end`. gaps: [lo, hi] drawn; a fitted gap may run to max(hi, 2 lo - 1), the widest
## gap that cannot hold two blocks; where no run fits clean within that, up to lo more (an
## outskirts x-line pair can leave the diagonal's crossings too far apart for short blocks to
## thread). Where no run meets every rule, the one that breaks the fewest is taken (each line in
## a barred place or gap counts one). With rule["avenue"] the run also leaves at least one line
## an avenue fits on (avenue_fits_x), for CityGen's inner avenue.
## With rule["report"] (a Dictionary) the rules the run breaks are added to its "breaks".
static func run(
	rng: RandomNumberGenerator, start: int, end: int, gaps: Array[int], rule: Dictionary
) -> Array[int]:
	var lo := gaps[0]
	var hi := gaps[1]
	var cap := maxi(hi, 2 * lo - 1)
	var run_at := [start, 1 if end >= start else -1, absi(end - start)]
	var length: int = run_at[2]
	var states := 3 if rule.get("avenue", false) else 1
	var cost := _costs(run_at, [lo, cap], rule, states)
	if cost[0] > 0:  # no clean run: let one gap stretch a block further before breaking a rule
		var wide := _costs(run_at, [lo, cap + lo], rule, states)
		if wide[0] < cost[0]:
			cap += lo
			cost = wide
	if rule.has("report"):  # the fewest-breaks fallback taken (CityLines.draw: plan "fit_breaks")
		var report: Dictionary = rule["report"]
		report["breaks"] = Num.i(report["breaks"]) + (cost[0] if cost[0] < BIG else 1)
	var out: Array[int] = []
	var d := 0
	var st := 0
	var open: bool = rule.get("open", false)
	while (d < length) if open else (d != length):
		var draw := rng.randi_range(lo, hi)
		var best := -1
		for g: int in range(lo, cap + 1):
			var e := d + g
			if e * states >= cost.size():
				continue
			var then := cost[e * states + _next(run_at, d, e, st, rule)]
			if then >= BIG or then + _step_cost(run_at, d, e, rule) != cost[d * states + st]:
				continue  # off the cheapest run
			if best < 0 or absi(g - draw) < absi(best - draw):
				best = g
		if best < 0:  # no run at all (a run shorter than lo): one gap to the end
			best = length - d if not open else draw
		st = _next(run_at, d, d + best, st, rule) if states > 1 else 0
		d += best
		out.append(start + Num.i(run_at[1]) * d)
	return out


## cost[d * states + st]: the fewest broken rules from a line at start + dir d, in avenue state
## st, to the end (BIG: unreachable). run_at: [start, dir, length].
static func _costs(
	run_at: Array, gaps: Array[int], rule: Dictionary, states: int
) -> PackedInt32Array:
	var length: int = run_at[2]
	var open: bool = rule.get("open", false)
	var size := length + (gaps[1] if open else 0) + 1
	var cost := PackedInt32Array()
	cost.resize(size * states)
	cost.fill(BIG)
	for d: int in range(size - 1, -1, -1):
		for st: int in states:
			if (d >= length) if open else (d == length):
				cost[d * states + st] = 0 if st == states - 1 else 1  # no avenue line: one broken
				continue
			var best := BIG
			for g: int in range(gaps[0], gaps[1] + 1):
				var e := d + g
				if e >= size:
					break
				var then := cost[e * states + (_next(run_at, d, e, st, rule) if states > 1 else 0)]
				if then < BIG:
					best = mini(best, then + _step_cost(run_at, d, e, rule))
			cost[d * states + st] = best
	return cost


## The avenue state after a line at e (the previous at d): 0 none yet, 1 the line at d has room
## for an avenue on its near side, 2 a line with room both sides is laid.
static func _next(run_at: Array, d: int, e: int, st: int, rule: Dictionary) -> int:
	if st == 2 or not rule.get("avenue", false):
		return st
	var a := _at(run_at, d)
	var b := _at(run_at, e)
	var diag: Dictionary = rule["diag"]
	var gap := absf(crossing(diag, b) - crossing(diag, a))
	var avenue := Num.f(rule["s_avenue"])
	if st == 1 and gap >= avenue + _s_of(b, rule) + STEP:
		return 2
	var inner := e != Num.i(run_at[2])
	return 1 if inner and gap >= avenue + _s_of(a, rule) + STEP else 0


static func _at(run_at: Array, d: int) -> float:
	return float(Num.i(run_at[0]) + Num.i(run_at[1]) * d)


## What a gap from d to e breaks: the line at e in a barred place (a fixed end line never
## counts), and the gap itself.
static func _step_cost(run_at: Array, d: int, e: int, rule: Dictionary) -> int:
	var n := 0 if _gap_ok(_at(run_at, d), _at(run_at, e), rule) else 1
	var fixed: bool = e == Num.i(run_at[2]) and not rule.get("open", false)
	if not fixed and not _pos_ok(roundi(_at(run_at, e)), rule):
		n += 1
	return n


static func _pos_ok(p: int, rule: Dictionary) -> bool:
	if str(rule.get("axis", "")) == "z":
		var bad: Dictionary = rule["bad"]
		return not bad.has(p)
	if str(rule.get("axis", "")) == "x":
		var diag: Dictionary = rule["diag"]
		var c := crossing(diag, float(p))
		for z: float in rule["fixed_z"]:
			if absf(c - z) < Num.f(rule["s_avenue"]):
				return false
	return true


static func _gap_ok(a: float, b: float, rule: Dictionary) -> bool:
	if str(rule.get("axis", "")) != "x":
		return true
	var need := _s_of(a, rule) + _s_of(b, rule) + STEP
	var diag: Dictionary = rule["diag"]
	var ca := crossing(diag, a)
	var cb := crossing(diag, b)
	if absf(cb - ca) < need:
		return false
	# A ring or pinned z-line between the two crossings is a z-line fixed in place: the z-lines either side
	# of it must still reach it in one gap (z_cap), so neither crossing lies too far from it.
	var cap := Num.f(rule["z_cap"])
	for r: float in rule["fixed_z"]:
		if (r - ca) * (r - cb) < 0.0:
			if absf(r - ca) > cap - _s_of(a, rule) or absf(r - cb) > cap - _s_of(b, rule):
				return false
	return true


## Clearance an x-line at x needs from the z-lines: an avenue's (the rings, and any listed in
## rule["avenue_x"]) or a street's.
static func _s_of(x: float, rule: Dictionary) -> float:
	for r: float in rule["ring_z"]:
		if is_equal_approx(absf(x), absf(r)):
			return Num.f(rule["s_avenue"])
	if x in rule.get("avenue_x", []):
		return Num.f(rule["s_avenue"])
	return Num.f(rule["s_street"])


## The diagonal's z where it crosses the x-line at x.
static func crossing(diag: Dictionary, x: float) -> float:
	var at: Vector2 = diag["at"]
	var dir: Vector2 = diag["dir"]
	return at.y + (x - at.x) * dir.y / dir.x


## The x-lines' rule: rings are the district ring lines (both axes share them); fixed_z those and
## the sea bay's pinned z-lines (CityHarbour.pins: the back street), which no fitted z-line can
## dodge the diagonal for, so the x-lines keep its crossings an avenue's clearance off them; z_cap
## the widest z gap CityLines fits (the z-lines' own max(hi, 2 lo - 1)).
static func x_rule(cfg: Dictionary, diag: Dictionary, rings: Array[float]) -> Dictionary:
	var ring_z: Array[float] = []
	for r: float in rings:
		ring_z.append(r)
		ring_z.append(-r)
	var fixed_z := ring_z.duplicate()
	var pinned: Array[float] = CityHarbour.pins(cfg)["z"]
	fixed_z.append_array(pinned)
	var s := _clearances(cfg)
	var short: Array = cfg["block_short"]
	var z_cap := maxi(Num.i(short[1]), 2 * Num.i(short[0]) - 1)
	return {
		"axis": "x",
		"diag": diag,
		"ring_z": ring_z,
		"fixed_z": fixed_z,
		"s_street": s[0],
		"s_avenue": s[1],
		"z_cap": float(z_cap),
	}


## Whether x-line i may be an avenue: the diagonal's crossings either side leave a z-line room
## at an avenue's clearance on its side.
static func avenue_fits_x(rule: Dictionary, xs: Array[float], i: int) -> bool:
	var diag: Dictionary = rule["diag"]
	var c := crossing(diag, xs[i])
	for k: int in [i - 1, i + 1]:
		if k < 0 or k >= xs.size():
			continue
		var need := Num.f(rule["s_avenue"]) + _s_of(xs[k], rule) + STEP
		if absf(crossing(diag, xs[k]) - c) < need:
			return false
	return true


## The z-lines' rule: every whole metre within s of an x-line's crossing is barred.
static func z_rule(
	cfg: Dictionary, diag: Dictionary, xs: Array[float], rings: Array[float], avenue_x: Array
) -> Dictionary:
	var s := _clearances(cfg)
	var x_rules := x_rule(cfg, diag, rings)
	x_rules["avenue_x"] = avenue_x
	var bad := {}
	for x: float in xs:
		var c := crossing(diag, x)
		var need := _s_of(x, x_rules)
		for z: int in range(ceili(c - need), floori(c + need) + 1):
			if absf(z - c) < need:
				bad[z] = true
	return {"axis": "z", "bad": bad, "s_street": s[0], "s_avenue": s[1]}


## [street, avenue]: how far a grid crossing of a street (avenue) must stay from the diagonal's
## crossing on the same line for their junction boxes not to overlap.
static func _clearances(cfg: Dictionary) -> Array[float]:
	var diag := CityGen.width_of(CityGen.DIAGONAL, cfg) * 0.5
	return [
		diag + CityGen.width_of(CityGen.STREET, cfg) * 0.5,
		diag + CityGen.width_of(CityGen.AVENUE, cfg) * 0.5,
	]


## How far line `v` on `axis` keeps from the nearest crossing of the diagonal with the other axis
## (INF with none): an avenue needs _clearances()[1].
static func clearance(diag: Dictionary, axis: String, v: float, others: Array[float]) -> float:
	var out := INF
	for o: float in others:
		var c := crossing(diag, o if axis == "z" else v)
		out = minf(out, absf((v if axis == "z" else o) - c))
	return out


## Whether the x-lines of cfg's plan can meet every rule whatever the seed (the runs between the
## fixed ring lines and out to the outskirts; the z-lines then always fit between the diagonal's
## crossings): the check tools/audit/diagonal_fit.gd uses to pick city.diagonal_through and
## city.diagonal_deg. diag: CityGen.diagonal_of(cfg), or a candidate.
static func x_runs_fit(cfg: Dictionary, diag: Dictionary) -> bool:
	var rings := CityGen.districts(cfg)
	var rule := x_rule(cfg, diag, rings)
	for r: float in rings:
		if not _pos_ok(roundi(r), rule) or not _pos_ok(-roundi(r), rule):
			return false
	var gaps := CityLines.gaps(cfg)
	var long: Array[int] = gaps["long"]
	var cap := maxi(long[1], 2 * long[0] - 1)
	var inner := rule.duplicate()
	inner["avenue"] = true
	var r0 := roundi(rings[0])
	if _costs([-r0, 1, 2 * r0], [long[0], cap], inner, 3)[0] != 0:
		return false
	for k: int in range(1, rings.size()):
		var from := roundi(rings[k - 1])
		for side: int in [1, -1]:
			var run_at := [from * side, side, roundi(rings[k]) - from]
			if _costs(run_at, [long[0], cap], rule, 1)[0] != 0:
				return false
	var far: Array[int] = gaps["far_long"]
	var open := rule.duplicate()
	open["open"] = true
	var full := roundi(rings[-1])
	var outer := ceili(Num.f(cfg["outer_half"]))
	for side: int in [1, -1]:
		var run_at := [full * side, side, outer - full]
		if _costs(run_at, [far[0], maxi(far[1], 2 * far[0] - 1)], open, 1)[0] != 0:
			return false
	return true
