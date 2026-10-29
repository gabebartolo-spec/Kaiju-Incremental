class_name RoadNet
extends RefCounted
## The road graph's data and lookups (split out of RoadGraph to keep files small): the nodes and
## roads cut from the street plan (CityGen.map), clipped to the box round the playable city plus
## the entry depth, the grids that file roads and building lots by cell, and the distance to a
## road. RoadGraph adds what tanks ask of it: room for a hull, routes, the roads a tower closes.
## Numbers are army.convoy in data/tuning.json.

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
		if b.is_span():  # traffic runs on under the viaduct and over a bridge
			continue
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


## Road e's direction (a to b).
func axis(e: int) -> Vector2:
	return (nodes[edge_b[e]] - nodes[edge_a[e]]).normalized()
