class_name RoadSearch
extends RefCounted
## Cheapest routes over the RoadGraph (D-066), Dijkstra from a tank's start nodes. A road by
## the kaiju's feet costs heavily (tanks drive round the kaiju, not past it), so does one where
## a tank holds its post (others go round rather than queue behind) and a one-lane street a
## column is coming down (no head-on meetings). Closed roads and the ones a stuck tank backs
## away from are out. The search stays inside `disc` round the kaiju, where every post is.

var graph: RoadGraph
var cfg: Dictionary
## Set by Convoy each step: road -> true by the kaiju, road -> true held, road -> direction driven.
var near_kaiju: Dictionary = {}
var held: Dictionary = {}
var driven: Dictionary = {}


func _init(p_graph: RoadGraph, p_cfg: Dictionary) -> void:
	graph = p_graph
	cfg = p_cfg


## {cost: per node, prev: the road it was reached by} from start {node: cost}, leaving out the
## roads in `skip`, never further than disc from centre.
func search(start: Dictionary, skip: Dictionary, centre: Vector2, disc: float) -> Dictionary:
	var count := graph.nodes.size()
	var cost := PackedFloat32Array()
	cost.resize(count)
	cost.fill(INF)
	var prev := PackedInt32Array()
	prev.resize(count)
	prev.fill(-1)
	var heap: Array[Vector2] = []  # (cost, node)
	for n: int in start.keys():
		cost[n] = Num.f(start[n])
		_push(heap, Vector2(cost[n], n))
	while not heap.is_empty():
		var top := _pop(heap)
		var n := int(top.y)
		if top.x > cost[n]:
			continue
		for e: int in graph.links[n]:
			if graph.blocked[e] != 0 or skip.has(e):
				continue
			var to := graph.edge_b[e] if graph.edge_a[e] == n else graph.edge_a[e]
			if graph.nodes[to].distance_squared_to(centre) > disc * disc:
				continue
			var c := _surcharged(top.x + graph.edge_cost[e], e, n, to)
			if c < cost[to]:
				cost[to] = c
				prev[to] = e
				_push(heap, Vector2(c, to))
	return {"cost": cost, "prev": prev}


## `c`, the cost of taking road e from node n to node `to`, plus its penalties: the kaiju is
## by it, a tank holds its post on it, or a column is coming the other way down its one lane.
func _surcharged(c: float, e: int, n: int, to: int) -> float:
	if near_kaiju.has(e):
		c += Num.f(cfg["danger_cost"])
	if held.has(e):
		c += Num.f(cfg["held_cost"])
	if graph.edge_lane[e] == 0.0 and driven.has(e):
		var way: Vector2 = driven[e]
		if way.dot(graph.nodes[to] - graph.nodes[n]) < 0.0:
			c += Num.f(cfg["oncoming_cost"])
	return c


## The roads from a start node to `head` (in driving order) and that start node: [chain, node].
func chain_to(found: Dictionary, head: int) -> Array:
	var prev: PackedInt32Array = found["prev"]
	var chain: Array[int] = []
	var n := head
	while prev[n] >= 0:
		var e := prev[n]
		chain.push_front(e)
		n = graph.edge_a[e] if graph.edge_b[e] == n else graph.edge_b[e]
	return [chain, n]


static func _push(heap: Array[Vector2], v: Vector2) -> void:
	heap.append(v)
	var i := heap.size() - 1
	while i > 0:
		var up := (i - 1) / 2
		if heap[up].x <= heap[i].x:
			break
		var tmp := heap[up]
		heap[up] = heap[i]
		heap[i] = tmp
		i = up


static func _pop(heap: Array[Vector2]) -> Vector2:
	var top := heap[0]
	var last: Vector2 = heap.pop_back()
	if heap.is_empty():
		return top
	heap[0] = last
	var i := 0
	while true:
		var l := i * 2 + 1
		var m := i
		if l < heap.size() and heap[l].x < heap[m].x:
			m = l
		if l + 1 < heap.size() and heap[l + 1].x < heap[m].x:
			m = l + 1
		if m == i:
			break
		var tmp := heap[m]
		heap[m] = heap[i]
		heap[i] = tmp
		i = m
	return top


## Where a tank at `p` sets off from: {edge (the road under it), via (its point on that road's
## line), from: {node: cost}}, both ends of that road, or only the end behind it when it was held
## up on this road going the other way.
func origin(p: Vector2, r: ConvoyRoute) -> Dictionary:
	var e := graph.road_under(p, r.edge)
	var na := graph.nodes[graph.edge_a[e]]
	var nb := graph.nodes[graph.edge_b[e]]
	var via := Geometry2D.get_closest_point_to_segment(p, na, nb)
	var off := via.distance_to(p)
	var from := {
		graph.edge_a[e]: off + via.distance_to(na), graph.edge_b[e]: off + via.distance_to(nb)
	}
	if r.skip.has(e) and not r.path.is_empty():  # only the end behind it
		var ahead_b := nb.distance_to(r.path[0]) < na.distance_to(r.path[0])
		from.erase(graph.edge_b[e] if ahead_b else graph.edge_a[e])
	elif not r.path.is_empty() and r.heading != Vector2.ZERO:  # turning back costs more
		var behind_b := (nb - p).dot(r.heading) < 0.0
		var back := graph.edge_b[e] if behind_b else graph.edge_a[e]
		from[back] = Num.f(from[back]) + Num.f(cfg["uturn_cost"])
	return {"edge": e, "via": via, "from": from}
