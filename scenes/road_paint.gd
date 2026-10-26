class_name RoadPaint
extends RefCounted
## CityGround's road paint (split out to keep files small, D-159): quiet marks readable from the
## kaiju's height, kept clear of every crossing (roads suite R5) and zebras only at the central
## junction (D-054). Presentation only: transforms of the paint boxes, which CityGround draws.

const DASH_CLEAR := 2.5  # dashes stop this far short of a crossing road's asphalt
const ZEBRA_HALF := 0.6  # half a zebra stripe's length
const DASH_SLANT := 0.01  # |sin| below which a road runs on rather than crosses

var plan: Dictionary
var cfg: Dictionary
var coast: float
var paint: Array[Transform3D] = []


func _init(p_plan: Dictionary, p_cfg: Dictionary, p_coast: float) -> void:
	plan = p_plan
	cfg = p_cfg
	coast = p_coast


## Quiet road paint, readable from the kaiju's height: a dashed centre line on the avenues and
## the diagonal, and zebra crossings (one per arm) only at the few junctions where two avenues
## cross nearest the city centre (city.zebra_junctions). Nothing else gets crossings.
func marks() -> Array[Transform3D]:
	var nodes: Array[Vector2] = plan["nodes"]
	var reach := Num.f(cfg["half"]) + Num.f(cfg["markings_beyond"])
	var zebras := zebra_junctions()
	var crossing := _crossings()
	paint.clear()
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		if kind == CityGen.ALLEY:
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var a := nodes[ends[0]]
		var b := nodes[ends[1]]
		if maxf(maxf(absf(a.x), absf(a.y)), maxf(absf(b.x), absf(b.y))) > reach:
			continue
		if minf(a.y, b.y) < coast:
			continue
		var dir := (b - a).normalized()
		var width := Num.f(street["width"])
		var length := a.distance_to(b)
		if kind != CityGen.STREET:
			var lift := (
				CityGround.DIAG_TOP + CityGround.PAINT
				if kind == CityGen.DIAGONAL
				else CityGround.PAINT
			)
			_dashes(a, dir * length, width, [lift, _near_crossings(crossing, ends, dir)])
		if kind == CityGen.DIAGONAL:
			continue
		for i: int in 2:
			if zebras.has(ends[i]):
				var toward := dir if i == 0 else -dir
				var clear := _near_crossings(crossing, ends, dir).filter(
					func(road: Array) -> bool: return not nodes[ends[i]] in [road[0], road[1]]
				)
				_zebra(nodes[ends[i]] + toward * (width * 0.5 + 0.9), toward, width, clear)
	return paint


## The junctions that get zebra crossings: where an avenue along x meets one along z, nearest
## the centre first, at most city.zebra_junctions of them.
func zebra_junctions() -> Dictionary:
	var nodes: Array[Vector2] = plan["nodes"]
	var along_x := {}
	var along_z := {}
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) != CityGen.AVENUE:
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var flat := is_equal_approx(nodes[ends[0]].y, nodes[ends[1]].y)
		for end: int in ends:
			if flat:
				along_x[end] = true
			else:
				along_z[end] = true
	var both: Array[int] = []
	for n: int in along_x:
		if along_z.has(n) and nodes[n].y >= coast:
			both.append(n)
	both.sort_custom(
		func(p: int, q: int) -> bool:
			var dp := nodes[p].length()
			var dq := nodes[q].length()
			if not is_equal_approx(dp, dq):
				return dp < dq
			return nodes[p] < nodes[q]
	)
	var out := {}
	for k: int in mini(Num.i(cfg["zebra_junctions"]), both.size()):
		out[both[k]] = true
	return out


## Per node: every road (not alley) there, [from, to, half width].
func _crossings() -> Dictionary:
	var nodes: Array[Vector2] = plan["nodes"]
	var out := {}
	for street: Dictionary in plan["streets"]:
		if str(street["kind"]) == CityGen.ALLEY:
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var road := [nodes[ends[0]], nodes[ends[1]], Num.f(street["width"]) * 0.5]
		for end: int in ends:
			if not out.has(end):
				out[end] = []
			var list: Array = out[end]
			list.append(road)
	return out


## The roads crossing a road (along `dir`, between nodes `ends`) at its crossings or the next ones
## on: those its dashes must keep clear of (roads suite R5: lane paint stops at a junction's
## edge, the diagonal's crossings come in close pairs).
func _near_crossings(crossing: Dictionary, ends: Array[int], dir: Vector2) -> Array:
	var nodes: Array[Vector2] = plan["nodes"]
	var out := []
	for end: int in ends:
		for road: Array in crossing.get(end, []):
			for far: Vector2 in [road[0], road[1]]:
				var key := _node_at(nodes, far)
				for other: Array in crossing.get(key, []):
					var p0: Vector2 = other[0]
					var p1: Vector2 = other[1]
					var d := (p1 - p0).normalized()
					if absf(d.cross(dir)) > DASH_SLANT and not out.has(other):
						out.append(other)
	return out


static func _node_at(nodes: Array[Vector2], p: Vector2) -> int:
	return nodes.find(p)


## True when p lies on the asphalt of one of `roads` ([from, to, half]), reaching into its
## crossings, or within `margin` of it.
static func _on_crossing(p: Vector2, roads: Array, margin: float = DASH_CLEAR) -> bool:
	for road: Array in roads:
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var reach := Num.f(road[2]) + margin
		var dir := (b - a).normalized()
		var along := (p - a).dot(dir)
		if along > -reach and along < a.distance_to(b) + reach and absf((p - a).cross(dir)) < reach:
			return true
	return false


## Dashes down the centre line from a along `span` (direction times length), at height
## style[0], none in or near a crossing: within half the road's width plus DASH_CLEAR of either
## end, or near the asphalt of the roads in style[1] (_near_crossings).
func _dashes(a: Vector2, span: Vector2, width: float, style: Array) -> void:
	var dir := span.normalized()
	var length := span.length()
	var angle := -dir.angle() + PI * 0.5
	var y := Num.f(style[0])
	var near: Array = style[1]
	var gap := width * 0.5 + DASH_CLEAR  # none in or near the crossings
	var t := gap
	while t < length - gap:
		var p := a + dir * t
		t += 3.0
		if _on_crossing(p, near):
			continue
		paint.append(
			Transform3D(
				Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(0.12, 0.04, 0.9)),
				Vector3(p.x, y, p.y)
			)
		)


## A zebra crossing over a road `width` wide, its stripes along `along` centred on `at`; none where
## a stripe would reach another road's asphalt in `clear` (the diagonal passing close by).
func _zebra(at: Vector2, along: Vector2, width: float, clear: Array) -> void:
	var across := Vector2(-along.y, along.x)
	var angle := -along.angle() + PI * 0.5
	var n := floori(width / 0.6)
	for i: int in n:
		for end: float in [-ZEBRA_HALF, ZEBRA_HALF]:
			var tip := at + across * ((i + 0.5) * 0.6 - width * 0.5) + along * end
			if _on_crossing(tip, clear, 0.0):
				return
	for i: int in n:
		var p := at + across * ((i + 0.5) * 0.6 - width * 0.5)
		paint.append(
			Transform3D(
				Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(0.3, 0.04, 1.2)),
				Vector3(p.x, CityGround.PAINT, p.y)
			)
		)
