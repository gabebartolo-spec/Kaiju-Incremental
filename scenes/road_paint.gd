class_name RoadPaint
extends RefCounted
## CityGround's road paint (split out to keep files small, D-159): quiet marks readable from the
## kaiju's height, kept clear of every crossing (roads suite R5) and zebras only at the central
## junction (D-054). Presentation only: transforms of the paint boxes, which CityGround draws.
## Every number is city.road_paint in data/tuning.json.

const PERPENDICULAR := 0.999  # |sin| of a crossing square to the road (roads suite R5)
const ZEBRA_OFF := 0.9  # a zebra's centre past the crossing's kerb line
const ZEBRA_HALF := 0.6  # half a zebra stripe's length
const DASH_SLANT := 0.01  # |sin| below which a road runs on rather than crosses

var plan: Dictionary
var cfg: Dictionary
var rp: Dictionary  # city.road_paint
var coast: float
var paint: Array[Transform3D] = []


func _init(p_plan: Dictionary, p_cfg: Dictionary, p_coast: float) -> void:
	plan = p_plan
	cfg = p_cfg
	rp = p_cfg["road_paint"]
	coast = p_coast


## Road paint by real marking logic (D-248, D-054), readable from the kaiju's height, on every
## road the plan lays that is wide enough for two lanes (road_paint.two_lane_min): a dashed
## centre line on a street, a double solid one on a wider road, lane dashes and edge lines on a
## road with more than one lane each way, and a stop line across the approaching lane where a
## road meets a crossing one. Alleys get none; zebras (one per arm) only at the few junctions
## where two avenues cross nearest the city centre (city.zebra_junctions).
func marks() -> Array[Transform3D]:
	var nodes: Array[Vector2] = plan["nodes"]
	var zebras := zebra_junctions()
	var crossing := _crossings()
	paint.clear()
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		var width := Num.f(street["width"])
		if kind == CityGen.ALLEY or width < Num.f(rp["two_lane_min"]):
			continue
		var ends: Array[int] = [Num.i(street["from"]), Num.i(street["to"])]
		var a := nodes[ends[0]]
		var b := nodes[ends[1]]
		if minf(a.y, b.y) < coast:
			continue
		var dir := (b - a).normalized()
		var near := _near_crossings(crossing, ends, dir)
		var lift := CityGround.PAINT
		if kind == CityGen.DIAGONAL:
			lift += CityGround.DIAG_TOP
		_road_lines(a, dir, a.distance_to(b), width, [lift, near])
		if kind == CityGen.DIAGONAL:
			continue
		for i: int in 2:
			var toward := dir if i == 0 else -dir
			_junction_end(nodes[ends[i]], toward, width, [crossing, near, ends[i]], zebras)
	return paint


## The paint at one end of a road, at `at` (node join[2]): a stop line, and a zebra at the zebra
## junctions. `toward` runs from the node along the road; join = [crossing, near, node].
func _junction_end(
	at: Vector2, toward: Vector2, width: float, join: Array, zebras: Dictionary
) -> void:
	var crossing: Dictionary = join[0]
	var near: Array = join[1]
	var node: int = join[2]
	var box := box_of(crossing, node, toward)
	var zebra := zebras.has(node)
	if box > 0.0:
		_stop_line(at, toward, width, box + (ZEBRA_OFF + ZEBRA_HALF if zebra else 0.0), near)
	if zebra:
		var clear := near.filter(func(road: Array) -> bool: return not at in [road[0], road[1]])
		_zebra(at + toward * (width * 0.5 + ZEBRA_OFF), toward, width, clear)


## How far the junction box at `node` reaches along a road running `dir` into it: the half width
## of the widest road crossing it square (0 when none: a slanted crossing is laid over everything).
func box_of(crossing: Dictionary, node: int, dir: Vector2) -> float:
	var out := 0.0
	for road: Array in crossing.get(node, []):
		var p0: Vector2 = road[0]
		var p1: Vector2 = road[1]
		if absf((p1 - p0).normalized().cross(dir)) >= PERPENDICULAR:
			out = maxf(out, Num.f(road[2]))
	return out


## The lines down a road from a along dir: the centre line, then lane dashes and edge lines when
## there is more than one lane each way. style = [height, crossing roads to keep clear of].
func _road_lines(a: Vector2, dir: Vector2, length: float, width: float, style: Array) -> void:
	var side := Vector2(-dir.y, dir.x)
	var lanes := floori(width / (2.0 * Num.f(rp["lane_width"])))
	if width >= Num.f(rp["double_min"]):
		for s: float in [-1.0, 1.0]:
			_solid(a + side * s * Num.f(rp["double_gap"]) * 0.5, dir, length, width, style)
	else:
		_dashes(a, dir, length, width, style)
	for k: int in range(1, lanes):
		for s: float in [-1.0, 1.0]:
			var off := side * s * (width * 0.5 * float(k) / float(lanes))
			_dashes(a + off, dir, length, width, style)
	if lanes > 1:
		for s: float in [-1.0, 1.0]:
			var edge := width * 0.5 - Num.f(rp["edge_inset"])
			_solid(a + side * s * edge, dir, length, width, style)


## A stop line across the lane approaching `node` along an arm running `toward` from it (the
## driver's right-hand lane), just outside the junction box and `extra` past it; none when it
## would reach a slanted crossing's asphalt.
func _stop_line(node: Vector2, toward: Vector2, width: float, extra: float, near: Array) -> void:
	var inset := Num.f(rp["stop_inset"])
	var long := width * 0.5 - inset - Num.f(rp["edge_inset"])
	var side := Vector2(toward.y, -toward.x)
	var thick := Num.f(rp["stop_width"])
	var at := node + toward * (extra + Num.f(rp["stop_gap"]) + thick * 0.5)
	var mid := at + side * (inset + long * 0.5)
	for end: float in [-1.0, 1.0]:
		for ahead: float in [-1.0, 1.0]:
			var corner := mid + side * long * 0.5 * end + toward * thick * 0.5 * ahead
			if _on_crossing(corner, near, 0.0):
				return
	_stripe(mid, side, thick, long, CityGround.PAINT)


## One painted box centred on p, its length along `along`.
func _stripe(p: Vector2, along: Vector2, wide: float, length: float, y: float) -> void:
	var angle := -along.angle() + PI * 0.5
	paint.append(
		Transform3D(
			Basis(Vector3.UP, angle) * Basis.from_scale(Vector3(wide, 0.04, length)),
			Vector3(p.x, y, p.y)
		)
	)


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
static func _on_crossing(p: Vector2, roads: Array, margin: float) -> bool:
	for road: Array in roads:
		var a: Vector2 = road[0]
		var b: Vector2 = road[1]
		var reach := Num.f(road[2]) + margin
		var dir := (b - a).normalized()
		var along := (p - a).dot(dir)
		if along > -reach and along < a.distance_to(b) + reach and absf((p - a).cross(dir)) < reach:
			return true
	return false


## Dashes along a line from a (a road's, or parallel to it) in direction dir, at height
## style[0], none in or near a crossing: within half the road's width plus dash_clear of either
## end, or near the asphalt of the roads in style[1] (_near_crossings).
func _dashes(a: Vector2, dir: Vector2, length: float, width: float, style: Array) -> void:
	var y := Num.f(style[0])
	var near: Array = style[1]
	var clear := Num.f(rp["dash_clear"])
	var t := width * 0.5 + clear
	while t < length - width * 0.5 - clear:
		var p := a + dir * t
		t += Num.f(rp["dash_pitch"])
		if not _on_crossing(p, near, clear):
			_stripe(p, dir, Num.f(rp["line_width"]), Num.f(rp["dash_length"]), y)


## A solid line along the same span, in the stretches clear of every crossing.
func _solid(a: Vector2, dir: Vector2, length: float, width: float, style: Array) -> void:
	var y := Num.f(style[0])
	var near: Array = style[1]
	var clear := Num.f(rp["dash_clear"])
	var step := Num.f(rp["solid_step"])
	var last := length - width * 0.5 - clear
	var from := -1.0
	var t := width * 0.5 + clear
	while t <= last + 0.0001:
		var open := not _on_crossing(a + dir * t, near, clear)
		if open and from < 0.0:
			from = t
		if from >= 0.0 and (not open or t + step > last):
			var to := t if open else t - step
			if to > from:
				_stripe(a + dir * (from + to) * 0.5, dir, Num.f(rp["line_width"]), to - from, y)
			from = -1.0
		t += step


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
