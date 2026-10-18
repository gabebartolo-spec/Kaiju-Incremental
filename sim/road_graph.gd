class_name RoadGraph
extends RefCounted
## The roads tanks use (D-066), from the street plan (CityGen.map): avenues, streets and the
## diagonal, never an alley, clipped to the box round the playable city plus the entry depth.
## Also the grids that keep a hull on the carriageway and off every lot, the start of a route
## and the waypoints along one (right-hand lane on a two-lane road), and the roads a toppled
## tower closes. Part of Convoy; numbers are army.convoy in data/tuning.json.

var sim: RampageSim
var cfg: Dictionary
var nodes: Array[Vector2] = []
## Roads: their two nodes, length, route cost, lane offset and half width; each node's roads.
var edge_a := PackedInt32Array()
var edge_b := PackedInt32Array()
var edge_len := PackedFloat32Array()
var edge_cost := PackedFloat32Array()
var edge_lane := PackedFloat32Array()  # how far right of the centre line tanks drive
var edge_half := PackedFloat32Array()
var blocked := PackedByteArray()  # closed by a toppled tower
var links: Array[PackedInt32Array] = []
## Nodes on the edge of the box (where a road leaves it): where columns enter.
var entries := PackedInt32Array()
var box: float
var cell: float
var _roads: Dictionary = {}  # Vector2i cell -> PackedInt32Array of roads through it
var _lots: Dictionary = {}  # Vector2i cell -> PackedInt32Array of building indices


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg
	box = sim.arena_half + Num.f(cfg["entry_depth"])
	cell = Num.f(cfg["grid"])
	_build(CityGen.map(sim.city))
	_index()


func _build(plan: Dictionary) -> void:
	var at: Dictionary = {}  # rounded position -> node
	var plan_nodes: Array = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		if kind == CityGen.ALLEY:
			continue
		var from: Vector2 = plan_nodes[Num.i(street["from"])]
		var to: Vector2 = plan_nodes[Num.i(street["to"])]
		var clip := _clip(from, to)
		if clip.is_empty():
			continue
		var na := _node(at, clip[0])
		var nb := _node(at, clip[1])
		if na == nb:
			continue
		var length := nodes[na].distance_to(nodes[nb])
		var width := Num.f(street["width"])
		edge_a.append(na)
		edge_b.append(nb)
		edge_len.append(length)
		edge_cost.append(length * (Num.f(cfg["street_cost"]) if kind == CityGen.STREET else 1.0))
		edge_lane.append(width * 0.25 if width >= Num.f(cfg["two_lanes"]) else 0.0)
		edge_half.append(width * 0.5)
		blocked.append(0)
		links[na].append(edge_a.size() - 1)
		links[nb].append(edge_a.size() - 1)
	for n: int in nodes.size():
		var p := nodes[n]
		if maxf(absf(p.x), absf(p.y)) >= box - 0.01 and links[n].size() == 1:
			entries.append(n)


func _node(at: Dictionary, p: Vector2) -> int:
	var key := Vector2i(roundi(p.x * 100.0), roundi(p.y * 100.0))
	if not at.has(key):
		at[key] = nodes.size()
		nodes.append(p)
		links.append(PackedInt32Array())
	return Num.i(at[key])


## The part of segment a-b inside the box, or [] (Liang-Barsky).
func _clip(a: Vector2, b: Vector2) -> Array[Vector2]:
	var t0 := 0.0
	var t1 := 1.0
	var d := b - a
	for axis: int in 2:
		for side: float in [-1.0, 1.0]:
			var q := box - side * a[axis]  # distance to the wall along this side
			var pv := side * d[axis]
			if absf(pv) < 0.000001:
				if q < 0.0:
					return []
				continue
			if pv > 0.0:
				t1 = minf(t1, q / pv)
			else:
				t0 = maxf(t0, q / pv)
	if t0 >= t1:
		return []
	return [a + d * t0, a + d * t1]


## Roads and building lots by grid cell.
func _index() -> void:
	for e: int in edge_a.size():
		var a := nodes[edge_a[e]]
		var b := nodes[edge_b[e]]
		_file(_roads, Rect2(a.min(b), a.max(b) - a.min(b)).grow(cell), e)
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var half := Vector2(b.w, b.d) * 0.5
		_file(_lots, Rect2(Vector2(b.x, b.z) - half, half * 2.0), i)


func _file(grid: Dictionary, area: Rect2, item: int) -> void:
	var from := cell_of(area.position)
	var to := cell_of(area.end)
	for cx: int in range(from.x, to.x + 1):
		for cz: int in range(from.y, to.y + 1):
			var key := Vector2i(cx, cz)
			var list: PackedInt32Array = grid.get(key, PackedInt32Array())
			list.append(item)
			grid[key] = list


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / cell), floori(p.y / cell))


func roads_at(key: Vector2i) -> PackedInt32Array:
	return _roads.get(key, PackedInt32Array())


func lots_at(key: Vector2i) -> PackedInt32Array:
	return _lots.get(key, PackedInt32Array())


## The roads with any part within `radius` of `at` (by grid cell, a superset).
func edges_within(at: Vector2, radius: float) -> Dictionary:
	var out := {}
	var lo := cell_of(at - Vector2(radius, radius))
	var hi := cell_of(at + Vector2(radius, radius))
	for cx: int in range(lo.x, hi.x + 1):
		for cz: int in range(lo.y, hi.y + 1):
			for e: int in roads_at(Vector2i(cx, cz)):
				out[e] = true
	return out


func off_line(p: Vector2, e: int) -> float:
	return (
		Geometry2D
		. get_closest_point_to_segment(p, nodes[edge_a[e]], nodes[edge_b[e]])
		. distance_to(p)
	)


## Is p on road e's carriageway?
func on_edge(p: Vector2, e: int) -> bool:
	return off_line(p, e) <= edge_half[e]


## Room for a whole hull at p: its centre no further off a road's centre line than the road's
## half width plus the sidewalk, less half the hull and a hand's breadth, and clear of every
## building lot (where a street runs out into an alley between buildings).
func drivable(p: Vector2) -> bool:
	var hull: Array = cfg["hull"]
	var spare := Num.f(sim.city["sidewalk"]) - Num.f(hull[1]) * 0.5 - 0.1
	var on := false
	for e: int in roads_at(cell_of(p)):
		if off_line(p, e) <= edge_half[e] + spare:
			on = true
			break
	if not on:
		return false
	var clear := Num.f(hull[1]) * 0.5 + 0.05
	var key := cell_of(p)
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			for i: int in lots_at(key + Vector2i(dx, dz)):
				var b := sim.buildings[i]
				var lo := Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5)
				if p.clamp(lo, lo + Vector2(b.w, b.d)).distance_to(p) < clear:
					return false
	return true


## The road nearest p (the one it is on when `edge` still holds it).
func road_under(p: Vector2, edge: int) -> int:
	if edge >= 0 and on_edge(p, edge):
		return edge
	var near: Array[int] = []
	for dx: int in [-1, 0, 1]:
		for dz: int in [-1, 0, 1]:
			for k: int in roads_at(cell_of(p) + Vector2i(dx, dz)):
				near.append(k)
	if near.is_empty():  # far off the plan: every road
		near.assign(range(edge_a.size()))
	var best := -1
	var best_d := INF
	for k: int in near:
		var d := off_line(p, k)
		if d < best_d:
			best_d = d
			best = k
	return best


## The waypoints from `from` along `chain` (roads, from start node n) to `at` on road `last`:
## [path, legs]. A tank off its road's line steps onto it first; on a road wide enough for two
## lanes it keeps right of the centre line (each waypoint moves right of the way it arrives),
## so columns going opposite ways pass each other.
func waypoints(from: Vector2, start: Dictionary, chain: Array[int], goal: Dictionary) -> Array:
	var path: Array[Vector2] = []
	var legs: Array[int] = []
	var on := Num.i(start["edge"])
	var n := Num.i(start["node"])
	if n >= 0:
		var via: Vector2 = start["via"]
		if via.distance_to(from) > edge_lane[on] + 0.25:
			path.append(via)
			legs.append(-1)
		path.append(nodes[n])
		legs.append(on)
		for e: int in chain:
			n = edge_b[e] if edge_a[e] == n else edge_a[e]
			path.append(nodes[n])
			legs.append(e)
	path.append(goal["at"])
	legs.append(Num.i(goal["edge"]))
	while not path.is_empty() and path[0].distance_to(from) < 0.05:  # already there
		path.remove_at(0)
		legs.remove_at(0)
	var last := from
	for i: int in path.size():
		var centre := path[i]
		var e := legs[i]
		if e >= 0 and edge_lane[e] > 0.0 and centre.distance_to(last) > 0.01:
			var d := (centre - last).normalized()
			path[i] = centre + Vector2(-d.y, d.x) * edge_lane[e]
		last = centre
	return [path, legs]


## Closes every open road within reach of a fallen strip (from -> to, `width` across) plus half
## a hull. True when one closed.
func close_strip(from: Vector2, to: Vector2, width: float) -> bool:
	var hull: Array = cfg["hull"]
	var within := width * 0.5 + Num.f(hull[1]) * 0.5
	var closed := false
	for e: int in edge_a.size():
		if blocked[e] == 0 and _near(nodes[edge_a[e]], nodes[edge_b[e]], from, to) < within:
			blocked[e] = 1
			closed = true
	return closed


static func _near(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> float:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return 0.0
	var best := minf(
		Geometry2D.get_closest_point_to_segment(a, c, d).distance_to(a),
		Geometry2D.get_closest_point_to_segment(b, c, d).distance_to(b)
	)
	best = minf(best, Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c))
	return minf(best, Geometry2D.get_closest_point_to_segment(d, a, b).distance_to(d))
