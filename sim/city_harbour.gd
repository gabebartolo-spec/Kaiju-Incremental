class_name CityHarbour
extends RefCounted
## The bay the kaiju rises from at the start of every run (director 2026-10-26: "move it to the
## bay where a shoreline makes more natural sense ... deploy the kaiju from the bay rather than
## the river"; "Sea bay, real beach"): a crescent of sea cut south from the coast into the city's
## north edge, its city end one continuous sand beach inside the arena, straight quays on its two
## flanks. A rule over the street plan, never fixed coordinates (a random city reuses it):
## centred on the north-south street nearest the city's centre line, as wide as city "harbour"
## "width_share" of the arena (and the stage's biggest body, EmergeReach.fit), its beach "reach_in"
## inside the arena's north edge. Part of CityGen.map, which records it as plan["harbour"]
## {cx, half, mouth, curve_from, apex} and the rise as plan["rise_spawn"] (in the water, on the
## centre line) and plan["rise_bank"] (on the promenade past the beach). Pure.

const CUT_MIN := 0.01  # metres: a street piece the bay leaves shorter than this is no street


## Marks the bay on `plan` (CityGen.map's, its streets laid): its beach's apex stops at the far
## pavement of a street it would run under (that street runs on along the beach); each street
## its water reaches ends at the water (at the beach or a quay, never short of it on bare
## ground), turns every block wholly inside it into sea ("harbour"), records the bay and the
## rise. A city without a "harbour" row has none.
static func mark(plan: Dictionary, cfg: Dictionary) -> void:
	if not cfg.has("harbour"):
		return
	var h: Dictionary = cfg["harbour"]
	var edge := CityGen.half_extent(cfg) + Num.f(cfg["arena_margin"])
	var half := maxf(Num.f(h["width_share"]) * edge, Num.f(h.get("fit_width", 0.0)) * 0.5)
	var cx := _centre(plan)
	var apex := _clear_of_streets(plan, cfg, -edge + Num.f(h["reach_in"]), cx, half)
	var curve := half * Num.f(h["crescent_share"])
	plan["harbour"] = {
		"cx": cx,
		"half": half,
		"mouth": Num.f(cfg["coast_z"]),
		"curve_from": apex - curve,
		"apex": apex,
	}
	var spawn_z := apex - Num.f(h["beach"]) - Num.f(h["nose_gap"])
	plan["rise_spawn"] = Vector2(cx, spawn_z)
	plan["rise_bank"] = Vector2(cx, apex + Num.f(h["bank_inset"]))
	var water := bands(plan, cfg)
	var kept: Array[Dictionary] = []
	for street: Dictionary in plan["streets"]:
		kept.append_array(_cut(plan, street, water))
	plan["streets"] = kept
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		var corners := [rect.position, rect.end, Vector2(rect.position.x, rect.end.y)]
		corners.append(Vector2(rect.end.x, rect.position.y))
		if corners.all(func(c: Vector2) -> bool: return holds(plan, c)):  # the bay is convex
			if not block.has("was"):
				block["was"] = block["use"]
			block["use"] = "harbour"


## The beach's apex z, moved north (smaller z) off every east-west street between x cx - half
## and cx + half whose carriageway or pavement it would fall on, to that street's far pavement
## edge: the street runs whole along the beach, its pavement meeting the sand.
static func _clear_of_streets(
	plan: Dictionary, cfg: Dictionary, apex: float, cx: float, half: float
) -> float:
	var nodes: Array[Vector2] = plan["nodes"]
	var side := Num.f(cfg["sidewalk"])
	var moved := true
	while moved:
		moved = false
		for street: Dictionary in plan["streets"]:
			var a := nodes[Num.i(street["from"])]
			var b := nodes[Num.i(street["to"])]
			var reach := Num.f(street["width"]) * 0.5 + side
			var across := maxf(a.x, b.x) > cx - half and minf(a.x, b.x) < cx + half
			if absf(a.y - b.y) < 0.001 and across and absf(apex - a.y) < reach - 0.001:
				apex = a.y - reach
				moved = true
	return apex


## What is left of `street` once the bay's water (its bands) is cut out of it: the street
## itself if no band reaches its carriageway; else each dry piece of a north-south or
## east-west street, ending where its carriageway meets the water (a new node there); none for
## a street wholly in the water, or any other (the diagonal) the water reaches.
static func _cut(plan: Dictionary, street: Dictionary, water: Array[Rect2]) -> Array[Dictionary]:
	var nodes: Array[Vector2] = plan["nodes"]
	var a := nodes[Num.i(street["from"])]
	var b := nodes[Num.i(street["to"])]
	var width := Num.f(street["width"])
	var half := width * 0.5
	var axis := -1
	if absf(a.x - b.x) < 0.001:
		axis = 1
	elif absf(a.y - b.y) < 0.001:
		axis = 0
	var road := Rect2(a.min(b), (b - a).abs())
	if axis == 1:
		road = road.grow_individual(half, 0.0, half, 0.0)  # its carriageway, not past its ends
	elif axis == 0:
		road = road.grow_individual(0.0, half, 0.0, half)
	else:
		road = road.grow(half)
	var wet: Array[Rect2] = []
	for w: Rect2 in water:
		if w.intersects(road):
			wet.append(w)
	if wet.is_empty():
		return [street]
	if axis < 0:
		return []
	var p0 := a if a[axis] < b[axis] else b
	var p1 := b if a[axis] < b[axis] else a
	var lo := INF
	var hi := -INF
	for w: Rect2 in wet:  # the bay is convex: the bands it reaches are one span along the street
		lo = minf(lo, w.position[axis])
		hi = maxf(hi, w.end[axis])
	lo = maxf(lo, p0[axis])  # the water cuts the street, never lengthens it
	hi = minf(hi, p1[axis])
	var before := p0[axis] < lo - CUT_MIN  # a dry piece before the water
	var after := p1[axis] > hi + CUT_MIN
	var joins_p1 := before and _joins(p1, p1[axis] - lo, width, water)
	if joins_p1 or (after and _joins(p0, hi - p0[axis], width, water)):
		return [street]
	var out: Array[Dictionary] = []
	if before:
		var end := p0
		end[axis] = lo
		out.append(_piece(plan, street, p0, end))
	if after:
		var start := p1
		start[axis] = hi
		out.append(_piece(plan, street, start, p1))
	return out


## Whether a street the water would stop `gap` metres short of its own junction `node` runs on
## whole instead: the junction's centre is dry and the gap is no longer than the street is wide
## (the bay's curve only clips the junction's corner: the street meets its cross street, never
## ends in a dead end a few metres short of it).
static func _joins(node: Vector2, gap: float, width: float, water: Array[Rect2]) -> bool:
	if gap > width:
		return false
	for w: Rect2 in water:
		if w.has_point(node):
			return false
	return true


## A copy of `street` running from a to b, a new node at whichever end is not one yet.
static func _piece(plan: Dictionary, street: Dictionary, a: Vector2, b: Vector2) -> Dictionary:
	var out := street.duplicate()
	out["from"] = _node_at(plan, a)
	out["to"] = _node_at(plan, b)
	return out


static func _node_at(plan: Dictionary, p: Vector2) -> int:
	var nodes: Array[Vector2] = plan["nodes"]
	for n: int in nodes.size():
		if nodes[n].distance_to(p) < 0.001:
			return n
	nodes.append(p)
	return nodes.size() - 1


## The north-south street line nearest the city's centre line (x 0): the bay's centre.
static func _centre(plan: Dictionary) -> float:
	var xs: Array[float] = plan["xs"]
	var best := 0.0
	var gap := INF
	for x: float in xs:
		if absf(x) < gap:
			gap = absf(x)
			best = x
	return best


## The bay's water as rects (x, z), each wholly inside it: the straight reach from the coast to
## where the crescent begins, then one band every city "harbour" "step" metres across the
## crescent, each as wide as the curve at its city-side edge, so the land always covers the true
## curve (the beach runs on under it, CityGround). Empty without a bay. outer: each band as wide
## as the curve at its sea-side edge instead, so together they cover all the water (the true
## curve) rather than lie inside it.
static func bands(plan: Dictionary, cfg: Dictionary, outer: bool = false) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var mouth := Num.f(b["mouth"])
	var from := Num.f(b["curve_from"])
	var apex := Num.f(b["apex"])
	out.append(Rect2(cx - half, mouth - 1.0, half * 2.0, from - mouth + 1.0))
	var step := Num.f(cfg["harbour"]["step"])
	var z := from
	while z < apex - 0.001:
		var z1 := minf(apex, z + step)
		var at := z if outer else z1
		var w := half * sqrt(maxf(0.0, 1.0 - pow((at - from) / (apex - from), 2.0)))
		if w > 0.001:
			out.append(Rect2(cx - w, z, w * 2.0, z1 - z))
		z = z1
	return out


## Whether p lies in the bay's water (the true curve, not the bands).
static func holds(plan: Dictionary, p: Vector2) -> bool:
	if not plan.has("harbour"):
		return false
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var from := Num.f(b["curve_from"])
	var apex := Num.f(b["apex"])
	if absf(p.x - cx) > half or p.y < Num.f(b["mouth"]) or p.y > apex:
		return false
	if p.y <= from:
		return true
	var u := (p.x - cx) / half
	var v := (p.y - from) / (apex - from)
	return u * u + v * v <= 1.0


## The southmost z of the bay's water (the true curve) anywhere between x0 and x1; -INF where
## the bay never reaches (or there is none).
static func south_at(plan: Dictionary, x0: float, x1: float) -> float:
	if not plan.has("harbour"):
		return -INF
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	if x1 < cx - half or x0 > cx + half:
		return -INF
	var u := (clampf(cx, x0, x1) - cx) / half
	var from := Num.f(b["curve_from"])
	return from + (Num.f(b["apex"]) - from) * sqrt(maxf(0.0, 1.0 - u * u))


## The crescent's curve, the beach's waterline-to-street edge, as points from its west end to
## its east end (city "harbour" "arc_points" of them).
static func arc(plan: Dictionary, cfg: Dictionary) -> PackedVector2Array:
	var out := PackedVector2Array()
	if not plan.has("harbour"):
		return out
	var b: Dictionary = plan["harbour"]
	var cx := Num.f(b["cx"])
	var half := Num.f(b["half"])
	var from := Num.f(b["curve_from"])
	var depth := Num.f(b["apex"]) - from
	var n := Num.i(cfg["harbour"]["arc_points"])
	for k: int in n + 1:
		var a := PI * float(k) / n  # PI at the west end, 0 at the east: south half of the curve
		out.append(Vector2(cx - cos(a) * half, from + sin(a) * depth))
	return out


## How far p lies from the beach's curve (the arc), metres.
static func from_shore(plan: Dictionary, cfg: Dictionary, p: Vector2) -> float:
	var line := arc(plan, cfg)
	var best := INF
	for k: int in line.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, line[k], line[k + 1])
		best = minf(best, p.distance_to(q))
	return best


## The sea's surface (world y): city "harbour" "sea_level".
static func sea(cfg: Dictionary) -> float:
	return Num.f(cfg["harbour"]["sea_level"]) if cfg.has("harbour") else 0.0


## The sea floor at the rise (world y): the sea's surface less city "harbour" "seabed_depth"
## (EmergeReach.fit: the stage's biggest body crouched, plus "seabed_clear"; the data's own
## figure until it is fitted).
static func seabed(cfg: Dictionary) -> float:
	return sea(cfg) - Num.f(cfg["harbour"]["seabed_depth"]) if cfg.has("harbour") else 0.0


## The ground's height at p: 0 (the street) on land; in the bay the sea floor, rising across
## the beach (city "harbour" "beach" metres from its curve) to "sand_top", just under the street.
static func floor_at(plan: Dictionary, cfg: Dictionary, p: Vector2) -> float:
	if not holds(plan, p):
		return 0.0
	var h: Dictionary = cfg["harbour"]
	var share := clampf(from_shore(plan, cfg, p) / Num.f(h["beach"]), 0.0, 1.0)
	return lerpf(Num.f(h["sand_top"]), seabed(cfg), share)


## The buildings of `entries` (CityGen.generate's) clear of the bay's water.
static func dry(plan: Dictionary, cfg: Dictionary, entries: Array[Dictionary]) -> Array[Dictionary]:
	var water := bands(plan, cfg)
	var out: Array[Dictionary] = []
	for e: Dictionary in entries:
		var w := Num.f(e.get("w", 0.0))
		var d := Num.f(e.get("d", 0.0))
		var r := Rect2(Num.f(e["x"]) - w * 0.5, Num.f(e["z"]) - d * 0.5, w, d)
		if not water.any(func(b: Rect2) -> bool: return b.intersects(r)):
			out.append(e)
	return out


## Lots for each built block the bay's water reaches that `standing` (CityGen.generate's
## buildings, after dry) leaves with none: filled again on the block's largest dry part
## (dry_part), from numbers of their own so no other lot moves, and kept clear of the water.
static func refill(
	plan: Dictionary, cfg: Dictionary, standing: Array[Dictionary]
) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not plan.has("harbour"):
		return out
	var water := bands(plan, cfg)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:sea bay lots" % Num.i(cfg["map_seed"]))
	for block: Dictionary in plan["blocks"]:
		var rect: Rect2 = block["rect"]
		if str(block["use"]) != "built" or _empty_of(rect, standing).is_empty():
			continue
		if not water.any(func(b: Rect2) -> bool: return b.intersects(rect)):
			continue
		var part := block.duplicate()
		part["rect"] = dry_part(rect, water)
		out.append_array(CityLots.fill_block(rng, plan, part, cfg, 1.0))
	return dry(plan, cfg, out)


## [rect] when no entry of `standing` has its centre in rect, else [].
static func _empty_of(rect: Rect2, standing: Array[Dictionary]) -> Array[Rect2]:
	var area := rect.grow(0.01)
	for e: Dictionary in standing:
		if area.has_point(Vector2(Num.f(e["x"]), Num.f(e["z"]))):
			return []
	return [rect]


## The largest part of `rect` wholly clear of `water`'s rects that reach it: the strip south,
## north, east or west of all of them.
static func dry_part(rect: Rect2, water: Array[Rect2]) -> Rect2:
	var lo := rect.end
	var hi := rect.position
	for w: Rect2 in water:
		if w.intersects(rect):
			lo = lo.min(w.position)
			hi = hi.max(w.end)
	var parts: Array[Rect2] = [
		Rect2(rect.position.x, hi.y, rect.size.x, rect.end.y - hi.y),
		Rect2(rect.position, Vector2(rect.size.x, lo.y - rect.position.y)),
		Rect2(hi.x, rect.position.y, rect.end.x - hi.x, rect.size.y),
		Rect2(rect.position, Vector2(lo.x - rect.position.x, rect.size.y)),
	]
	var best := Rect2()
	for p: Rect2 in parts:
		if p.size.x > 0.0 and p.size.y > 0.0 and p.get_area() > best.get_area():
			best = p
	return best
