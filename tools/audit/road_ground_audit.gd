extends RefCounted
## ROADS audit, ground half (D-265): what lies beside and under every road of the real city
## (CityBand.extent), read off the street plan (CityGen.map) the way CityGround lays it.
##   water  a road piece over the river's open water off every bridge deck (CityRiver.bridges)
##   kerb   a stretch of road edge, away from its junctions, with no kerbed pavement beside it
##          (CityGen.pavement of a block or a landmark's plaza), no other carriageway and no
##          water (a bridge's parapet or the quay); alleys carry no pavement by design
## The kerb check samples each edge every SAMPLE_M at half a pavement out from the kerb line.
## Pure; the same plan always gives the same answer.

const Graph := preload("res://tools/audit/road_graph_audit.gd")
const SAMPLE_M := 1.0
const WATER_STEP := 0.5
const CELL := 8.0  # bucket side for the rect index (m)


static func audit(plan: Dictionary, cfg: Dictionary) -> Array[Dictionary]:
	var g := Graph.Net.new(plan, cfg)
	var out: Array[Dictionary] = []
	out.append_array(_water(g))
	out.append_array(_kerbs(g))
	return out


static func _water(g: Graph.Net) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var water := CityRiver.channels(g.plan, g.cfg)
	if water.is_empty():
		return out
	var channel := water[0].grow(-0.01)
	var decks := CityRiver.bridges(g.plan, g.cfg)
	for k: int in g.pieces:
		var steps := maxi(1, ceili(g.length(k) / WATER_STEP))
		for i: int in steps + 1:
			var p := g.end_a(k).lerp(g.end_b(k), float(i) / steps)
			if channel.has_point(p) and not _in_any(decks, p, 0.01):
				out.append(Graph.violation("water", p, "%s over open water" % g.kind(k)))
				break
	return out


static func _in_any(rects: Array[Rect2], p: Vector2, grow: float) -> bool:
	for r: Rect2 in rects:
		if r.grow(grow).has_point(p):
			return true
	return false


static func _kerbs(g: Graph.Net) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var ctx := _context(g)
	for k: int in g.pieces:
		if g.kind(k) == CityGen.ALLEY:
			continue
		var bad := _bare_edge(g, ctx, k)
		if bad.x != INF:
			out.append(Graph.violation("kerb", bad, "%s edge with no pavement" % g.kind(k)))
	return out


## What may stand beside a road edge: pavements (blocks and plazas) and every piece's
## carriageway, bucketed by CELL; the river's water.
static func _context(g: Graph.Net) -> Dictionary:
	var pavements := {}
	for block: Dictionary in g.plan["blocks"]:
		_file(pavements, CityGen.pavement(block, g.cfg), {})
	var roads := {}
	for k: int in g.streets.size():
		var half := Num.f(g.streets[k]["width"]) * 0.5
		var box := Rect2(g.end_a(k), Vector2.ZERO).expand(g.end_b(k)).grow(half)
		_file(roads, box, {"k": k, "a": g.end_a(k), "b": g.end_b(k), "half": half})
	return {
		"pavements": pavements,
		"roads": roads,
		"water": CityRiver.channels(g.plan, g.cfg),
		"walk": Num.f(g.cfg["sidewalk"]),
	}


static func _file(index: Dictionary, rect: Rect2, item: Dictionary) -> void:
	var lo := Vector2i((rect.position / CELL).floor())
	var hi := Vector2i((rect.end / CELL).floor())
	var entry := item.duplicate()
	entry["box"] = rect
	for x: int in range(lo.x, hi.x + 1):
		for z: int in range(lo.y, hi.y + 1):
			var key := Vector2i(x, z)
			if not index.has(key):
				index[key] = []
			var list: Array = index[key]
			list.append(entry)


## The first sample beside road k with nothing there, or (INF, INF).
static func _bare_edge(g: Graph.Net, ctx: Dictionary, k: int) -> Vector2:
	var half := Num.f(g.streets[k]["width"]) * 0.5
	var walk := Num.f(ctx["walk"])
	var length := g.length(k)
	var dir := (g.end_b(k) - g.end_a(k)) / maxf(length, 0.001)
	var normal := Vector2(-dir.y, dir.x)
	var clear := _junction_reach(g, k) + walk + 0.5
	var t := clear
	while t <= length - clear:
		for side: float in [-1.0, 1.0]:
			var p := g.end_a(k) + dir * t + normal * side * (half + walk * 0.5)
			if maxf(absf(p.x), absf(p.y)) < g.extent and not _covered(ctx, p, k):
				return p
		t += SAMPLE_M
	return Vector2(INF, INF)


## How far the widest street meeting either end of piece k reaches out from its crossing.
static func _junction_reach(g: Graph.Net, k: int) -> float:
	var out := 0.0
	for n: int in [g.from_of(k), g.to_of(k)]:
		for other: int in g.arms(n):
			if other != k:
				out = maxf(out, Num.f(g.streets[other]["width"]) * 0.5)
	return out


static func _covered(ctx: Dictionary, p: Vector2, k: int) -> bool:
	var key := Vector2i((p / CELL).floor())
	var pavements: Dictionary = ctx["pavements"]
	var near: Array = pavements.get(key, [])
	for item: Dictionary in near:
		var box: Rect2 = item["box"]
		if box.has_point(p):
			return true
	var roads: Dictionary = ctx["roads"]
	near = roads.get(key, [])
	for item: Dictionary in near:
		var box: Rect2 = item["box"]
		if Num.i(item["k"]) == k or not box.has_point(p):
			continue
		var a: Vector2 = item["a"]
		var b: Vector2 = item["b"]
		var on := Geometry2D.get_closest_point_to_segment(p, a, b)
		if on.distance_to(p) <= Num.f(item["half"]):
			return true
	var water: Array[Rect2] = ctx["water"]
	return _in_any(water, p, 0.5)
