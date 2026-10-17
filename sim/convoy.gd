class_name Convoy
extends RefCounted
## How the tanks move (D-066): like an army, not a swarm. They enter by road from the city's
## edge and drive the street plan (CityGen.map: avenues, streets and the diagonal; never an
## alley, a lot or a building) in columns that keep their gap. Each takes a firing position on
## a road at standoff range with a clear line of fire to the kaiju, spread round it on an arc,
## holds it while it is good, bounds to a new one when the kaiju moves (one tank of a column at
## a time, the other covering), backs off when the kaiju closes inside the danger radius, and
## re-routes when a toppled tower blocks its road. Pure and seeded; Army owns spawning, firing
## and damage, and calls in here. All numbers are army.convoy in data/tuning.json.

## A tank's route through the plan: Army keeps one per tank (by id) in `routes`.
class Route:
	var path: Array[Vector2] = []  # waypoints still to drive, the firing position last
	var edges: Array[int] = []  # the road each leg runs along (-1: off the plan)
	var goal := Vector2(INF, INF)
	var reserve := false  # its goal is a reserve post, out of range
	var edge := -1  # the road it is on now
	var column := -1
	var replan_t := 0.0
	var stuck_t := 0.0
	var avoid := -1  # a road it was stuck on: left out of its next plan
	var retreating := false
	var give_to := -1  # an older tank it is backing up for
	var yield_t := 0.0
	var yield_all := 0.0  # how long it has been giving way this time


var sim: RampageSim
var cfg: Dictionary
## The street plan as a graph: node positions, roads (a, b, length, cost) and each node's roads.
var nodes: Array[Vector2] = []
var edge_a := PackedInt32Array()
var edge_b := PackedInt32Array()
var edge_len := PackedFloat32Array()
var edge_cost := PackedFloat32Array()
var edge_lane := PackedFloat32Array()  # how far right of the centre line tanks drive
var blocked := PackedByteArray()
var links: Array[PackedInt32Array] = []
## Nodes on the edge of the plan (where a road leaves the box): where columns enter.
var entries := PackedInt32Array()
var routes: Dictionary = {}  # tank id -> Route
var _box: float
var _grid: Dictionary = {}  # Vector2i cell -> PackedInt32Array of building indices
var _cell: float


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg
	_box = sim.arena_half + Num.f(cfg["entry_depth"])
	_build_graph(CityGen.map(sim.city))
	_index_buildings()


## The roads tanks may use, clipped to the box round the playable city plus the entry depth.
func _build_graph(plan: Dictionary) -> void:
	var at: Dictionary = {}  # rounded position -> node
	var plan_nodes: Array = plan["nodes"]
	for street: Dictionary in plan["streets"]:
		var kind := str(street["kind"])
		if kind == CityGen.ALLEY:
			continue
		var a: Vector2 = plan_nodes[Num.i(street["from"])]
		var b: Vector2 = plan_nodes[Num.i(street["to"])]
		var clip := _clip(a, b)
		if clip.is_empty():
			continue
		var cost := Num.f(cfg["street_cost"]) if kind == CityGen.STREET else 1.0
		var na := _node(at, clip[0])
		var nb := _node(at, clip[1])
		if na == nb:
			continue
		edge_a.append(na)
		edge_b.append(nb)
		var length := nodes[na].distance_to(nodes[nb])
		edge_len.append(length)
		edge_cost.append(length * cost)
		var width := Num.f(street["width"])
		edge_lane.append(width * 0.25 if width >= Num.f(cfg["two_lanes"]) else 0.0)
		blocked.append(0)
		links[na].append(edge_a.size() - 1)
		links[nb].append(edge_a.size() - 1)
	for n: int in nodes.size():
		var p := nodes[n]
		if maxf(absf(p.x), absf(p.y)) >= _box - 0.01 and links[n].size() == 1:
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
		var p0 := a[axis]
		var dp := d[axis]
		for side: float in [-1.0, 1.0]:
			var q := _box - side * p0  # distance to the wall along this side
			var pv := side * dp
			if absf(pv) < 0.000001:
				if q < 0.0:
					return []
				continue
			var t := q / pv
			if pv > 0.0:
				t1 = minf(t1, t)
			else:
				t0 = maxf(t0, t)
	if t0 >= t1:
		return []
	return [a + d * t0, a + d * t1]


## Buildings by grid cell, for line-of-fire tests.
func _index_buildings() -> void:
	_cell = Num.f(cfg["grid"])
	for i: int in sim.buildings.size():
		var b := sim.buildings[i]
		var lo := _cell_of(Vector2(b.x - b.w * 0.5, b.z - b.d * 0.5))
		var hi := _cell_of(Vector2(b.x + b.w * 0.5, b.z + b.d * 0.5))
		for cx: int in range(lo.x, hi.x + 1):
			for cz: int in range(lo.y, hi.y + 1):
				var key := Vector2i(cx, cz)
				if not _grid.has(key):
					_grid[key] = PackedInt32Array()
				var list: PackedInt32Array = _grid[key]
				list.append(i)
				_grid[key] = list


func _cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / _cell), floori(p.y / _cell))


## Full reach and the danger radius for the kaiju as it is now.
func reach() -> float:
	return Num.f(sim.army["range"]) + sim.stomp_radius()


func danger() -> float:
	return reach() * Num.f(cfg["danger"])


## Where a new tank enters: a road entry at the city's edge (or, in a city grown past the
## spawn radius, the road crossing nearest spawn_radius from the kaiju, D-039), picked by a
## seeded bearing. Returns where the tank with `id` starts (and records its route), or INF when
## that way in is still taken by the tank before it.
func enter(id: int, column: int, node: int) -> Vector2:
	if node < 0 or links[node].is_empty() or not _clear_of_tanks(nodes[node], Num.f(cfg["follow"])):
		return Vector2(INF, INF)
	var r := Route.new()
	r.column = column
	r.edge = links[node][0]
	routes[id] = r
	return nodes[node]


## The entry node for a column on `bearing` from the kaiju.
func pick_entry(bearing: float) -> int:
	var dir := Vector2.from_angle(bearing)
	var spawn_radius := Num.f(sim.army["spawn_radius"])
	var best := -1
	var best_d := INF
	if _box <= spawn_radius:
		var aim := dir * _box * 2.0
		for n: int in entries:
			var d := nodes[n].distance_squared_to(aim)
			if d < best_d:
				best_d = d
				best = n
		return best
	var aim := sim.kaiju_pos + dir * spawn_radius
	for n: int in nodes.size():
		var d := nodes[n].distance_squared_to(aim)
		if d < best_d and links[n].size() > 0:
			best_d = d
			best = n
	return best


func _clear_of_tanks(p: Vector2, gap: float) -> bool:
	for tank: RampageSim.Tank in sim.tanks:
		if tank.pos.distance_to(p) < gap:
			return false
	return true


## One step for every tank: read what fell across the roads, re-plan where needed, then drive.
func step(dt: float) -> void:
	_read_rubble()
	var near := danger()
	for tank: RampageSim.Tank in sim.tanks:
		var r: Route = routes.get(tank.id)
		if r == null:
			r = Route.new()
			routes[tank.id] = r
		if tank.heading == Vector2.ZERO and r.edge >= 0:  # a new tank faces into its road
			var a := nodes[edge_a[r.edge]]
			var b := nodes[edge_b[r.edge]]
			tank.heading = (b - a).normalized() if tank.pos.distance_to(a) < tank.pos.distance_to(b) else (a - b).normalized()
		r.replan_t -= dt
		var urgent := tank.pos.distance_to(sim.kaiju_pos) < near
		if not urgent and r.path.is_empty():
			r.retreating = false
		if urgent and not r.retreating:
			_plan(tank, r, true)
		elif r.replan_t <= 0.0:
			r.replan_t = Num.f(cfg["replan"])
			if not _goal_good(r) and (urgent or not _covering(tank, r)):
				_plan(tank, r, urgent)
		_drive(tank, r, dt)
	for id: int in routes.keys():
		if not sim.tanks.any(func(t: RampageSim.Tank) -> bool: return t.id == id):
			routes.erase(id)


## A goal is good while it is in the band between danger and full reach with a clear shot.
func _goal_good(r: Route) -> bool:
	if r.goal.x == INF:
		return false
	var d := r.goal.distance_to(sim.kaiju_pos)
	return d >= danger() and d <= reach() and clear_line(r.goal, sim.kaiju_pos)


## Bounding overwatch: a tank at its post waits for its column's moving tank to settle first.
func _covering(tank: RampageSim.Tank, r: Route) -> bool:
	if not r.path.is_empty() or r.goal.x == INF or r.column < 0:
		return false
	if r.goal.distance_to(sim.kaiju_pos) > reach():  # out of range: it cannot cover anyone
		return false
	for other: RampageSim.Tank in sim.tanks:
		if other.id == tank.id:
			continue
		var o: Route = routes.get(other.id)
		if o != null and o.column == r.column and not o.path.is_empty():
			r.replan_t = Num.f(cfg["replan"]) * 0.25
			return true
	return false


## Picks a firing position and the road route to it.
func _plan(tank: RampageSim.Tank, r: Route, urgent: bool) -> void:
	var start := _start(tank, r)
	r.stuck_t = 0.0
	r.replan_t = Num.f(cfg["replan"])
	if start.is_empty():
		r.avoid = -1
		return
	var from: Dictionary = start["from"]
	var dist := _dijkstra(from, r.avoid)
	var goal := _choose(tank, r, dist, urgent)
	if goal.is_empty() and urgent:  # every post taken, and the kaiju on top of it: back off anyway
		var away := _ring_posts(tank, r, dist, [reach() * Num.f(cfg["reserve"])] as Array[float])
		goal = {} if away.is_empty() else away[0]
		if not goal.is_empty():
			goal["reserve"] = true
	r.avoid = -1
	if goal.is_empty():
		r.retreating = urgent  # nowhere to go: try again at the next re-plan, not every step
		return
	var at: Vector2 = goal["at"]
	var path: Array[Vector2] = []
	var legs: Array[int] = []
	var head := Num.i(goal["node"])
	if head >= 0:
		var prev: PackedInt32Array = dist["prev"]
		var chain: Array[int] = []
		var n := head
		while prev[n] >= 0:
			var e := prev[n]
			chain.push_front(e)
			n = edge_a[e] if edge_b[e] == n else edge_b[e]
		# n is a start node: onto the plan first if off it, then along the road it is on.
		var via: Vector2 = start["via"]
		if via.distance_to(tank.pos) > 0.05:
			path.append(via)
			legs.append(-1)
		path.append(nodes[n])
		legs.append(Num.i(start["edge"]))
		for e: int in chain:
			n = edge_b[e] if edge_a[e] == n else edge_a[e]
			path.append(nodes[n])
			legs.append(e)
	path.append(at)
	legs.append(Num.i(goal["edge"]))
	while not path.is_empty() and path[0].distance_to(tank.pos) < 0.05:  # already there
		path.remove_at(0)
		legs.remove_at(0)
	_keep_right(tank, path, legs)
	r.path = path
	r.edges = legs
	r.goal = at
	r.reserve = goal.get("reserve", false)
	r.retreating = urgent and not path.is_empty()


## On a road wide enough for two lanes a tank keeps to the right of the centre line (each
## waypoint moves right of the way it arrives), so columns going opposite ways pass each other.
func _keep_right(tank: RampageSim.Tank, path: Array[Vector2], legs: Array[int]) -> void:
	var from := tank.pos
	for i: int in path.size():
		var centre := path[i]
		var e := legs[i]
		if e >= 0 and edge_lane[e] > 0.0 and centre.distance_to(from) > 0.01:
			var d := (centre - from).normalized()
			path[i] = centre + Vector2(-d.y, d.x) * edge_lane[e]
		from = centre


## Where a tank sets off from: {edge, via (its point on that road), from: {node: cost}} with
## both ends of the road it is on, or of the nearest road (driving straight onto it first) when
## it is off the plan. When it was stuck on this road, only the end behind it.
func _start(tank: RampageSim.Tank, r: Route) -> Dictionary:
	var e := r.edge
	var p := tank.pos
	if e < 0:
		var best := INF
		for k: int in edge_a.size():
			var q := Geometry2D.get_closest_point_to_segment(p, nodes[edge_a[k]], nodes[edge_b[k]])
			var d := q.distance_squared_to(p)
			if d < best:
				best = d
				e = k
		if e < 0:
			return {}
	var via := Geometry2D.get_closest_point_to_segment(p, nodes[edge_a[e]], nodes[edge_b[e]])
	var off := via.distance_to(p)
	var from := {}
	for n: int in [edge_a[e], edge_b[e]]:
		from[n] = off + via.distance_to(nodes[n])
	if r.avoid == e and not r.path.is_empty() and from.size() == 2:
		var ahead := edge_a[e]
		if nodes[edge_b[e]].distance_to(r.path[0]) < nodes[edge_a[e]].distance_to(r.path[0]):
			ahead = edge_b[e]
		from.erase(ahead)
	return {"edge": e, "via": via, "from": from}


## Cheapest road cost from the start nodes to every node: a road passing inside the danger
## radius costs heavily (tanks drive round the kaiju, not past its feet); blocked roads and the
## one it was stuck on are out.
func _dijkstra(start: Dictionary, avoid: int) -> Dictionary:
	var count := nodes.size()
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
	var near := danger()
	var penalty := Num.f(cfg["danger_cost"])
	var held := _held_roads()
	var oncoming := _driven_roads()
	while not heap.is_empty():
		var top := _pop(heap)
		var n := int(top.y)
		if top.x > cost[n]:
			continue
		for e: int in links[n]:
			if blocked[e] != 0 or e == avoid:
				continue
			var to := edge_b[e] if edge_a[e] == n else edge_a[e]
			var c := top.x + edge_cost[e]
			var q := Geometry2D.get_closest_point_to_segment(sim.kaiju_pos, nodes[n], nodes[to])
			if q.distance_to(sim.kaiju_pos) < near:
				c += penalty
			if held.has(e):
				c += Num.f(cfg["held_cost"])
			if edge_lane[e] == 0.0 and oncoming.has(e):
				var way: Vector2 = oncoming[e]
				if way.dot(nodes[to] - nodes[n]) < 0.0:
					c += Num.f(cfg["oncoming_cost"])
			if c < cost[to]:
				cost[to] = c
				prev[to] = e
				_push(heap, Vector2(c, to))
	return {"cost": cost, "prev": prev}


## Roads where a tank stands at its post: others route round them rather than queue behind.
func _held_roads() -> Dictionary:
	var out := {}
	for other: RampageSim.Tank in sim.tanks:
		var o: Route = routes.get(other.id)
		if o != null and o.path.is_empty() and o.edge >= 0:
			out[o.edge] = true
	return out


## Which way other tanks are driving each road on their routes (road -> direction), so a tank
## plans round a one-lane street a column is coming down rather than meet it head-on.
func _driven_roads() -> Dictionary:
	var out := {}
	for other: RampageSim.Tank in sim.tanks:
		var o: Route = routes.get(other.id)
		if o == null:
			continue
		var from := other.pos
		for i: int in o.path.size():
			if o.edges[i] >= 0:
				out[o.edges[i]] = o.path[i] - from
			from = o.path[i]
	return out


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


## The firing position: a post on a road in the firing band (_band_posts), reachable, with a
## clear shot, and spread from the other tanks' posts by spread_deg round the kaiju (then by
## post_gap alone when the band is crowded). The cheapest route wins. With every post taken, a reserve post out of range on the
## reserve ring, keeping the one it holds. {at, node, edge, reserve} or {}.
func _choose(tank: RampageSim.Tank, r: Route, dist: Dictionary, urgent: bool) -> Dictionary:
	var k := sim.kaiju_pos
	var posts := _posts(tank.id)
	var spread := deg_to_rad(Num.f(cfg["spread_deg"]))
	var follow := Num.f(cfg["follow"])
	var gap := Num.f(cfg["post_gap"])
	var cands := _band_posts(tank, r, dist)
	for pass_no: int in 2:
		for c: Dictionary in cands:
			var at: Vector2 = c["at"]
			if _spaced(at, posts, pass_no, spread, gap) and clear_line(at, k):
				return c
	var out := reach() * Num.f(cfg["reserve"])
	var wider: Array[float] = []
	for n: int in 4:  # the reserve ring and three wider ones behind it
		wider.append(out * (1.0 + 0.25 * n))
	var held := r.goal.distance_to(k)
	var widest := wider[wider.size() - 1] + follow
	if r.reserve and not urgent and held > reach() and held < widest and _spaced(r.goal, posts, 1, 0.0, follow):
		return {}  # keep the reserve post it has
	for c: Dictionary in _ring_posts(tank, r, dist, wider):
		var at: Vector2 = c["at"]
		if _spaced(at, posts, 1, 0.0, follow):
			c["reserve"] = true
			return c
	return {}


## Firing posts: points every post_gap along every reachable, open road inside the firing band
## (band x full reach), the ones nearest the standoff ring on the cheapest routes first.
func _band_posts(tank: RampageSim.Tank, r: Route, dist: Dictionary) -> Array[Dictionary]:
	var cost: PackedFloat32Array = dist["cost"]
	var k := sim.kaiju_pos
	var band: Array = cfg["band"]
	var lo := reach() * Num.f(band[0])
	var hi := reach() * Num.f(band[1])
	var mid := reach() * Num.f(cfg["standoff"])
	var step := Num.f(cfg["post_gap"])
	var cands: Array[Dictionary] = []
	for e: int in edge_a.size():
		if blocked[e] != 0 or e == r.avoid:
			continue
		var a := nodes[edge_a[e]]
		var b := nodes[edge_b[e]]
		if Geometry2D.get_closest_point_to_segment(k, a, b).distance_to(k) > hi:
			continue
		var length := edge_len[e]
		var last := -INF  # metres along the road of the last post taken, posts step apart
		for n: int in floori(length) + 1:
			var at := a.lerp(b, minf(1.0, n / maxf(length, 0.001)))
			var d := at.distance_to(k)
			if d < lo or d > hi or n - last < step:
				continue
			last = n
			var via_a := cost[edge_a[e]] + a.distance_to(at)
			var via_b := cost[edge_b[e]] + b.distance_to(at)
			var off := absf(d - mid) * 2.0
			if r.edge == e:  # on the same road: drive straight along it
				cands.append({"at": at, "node": -1, "edge": e, "cost": tank.pos.distance_to(at) + off})
			elif minf(via_a, via_b) < INF:
				var node := edge_a[e] if via_a <= via_b else edge_b[e]
				cands.append({"at": at, "node": node, "edge": e, "cost": minf(via_a, via_b) + off})
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["cost"] < y["cost"])
	return cands


## Every point where a reachable, open road crosses one of `rings` round the kaiju, cheapest
## route first: {at, node (where it leaves the road graph, -1: straight along its own road),
## edge, cost}.
func _ring_posts(tank: RampageSim.Tank, r: Route, dist: Dictionary, rings: Array[float]) -> Array[Dictionary]:
	var cost: PackedFloat32Array = dist["cost"]
	var k := sim.kaiju_pos
	var cands: Array[Dictionary] = []
	for e: int in edge_a.size():
		if blocked[e] != 0 or e == r.avoid:
			continue
		var a := nodes[edge_a[e]]
		var b := nodes[edge_b[e]]
		for ring: float in rings:
			for t: float in _ring_hits(a, b, k, ring):
				var at := a.lerp(b, t)
				var via_a := cost[edge_a[e]] + a.distance_to(at)
				var via_b := cost[edge_b[e]] + b.distance_to(at)
				if r.edge == e:  # on the same road: drive straight along it
					cands.append({"at": at, "node": -1, "edge": e, "cost": tank.pos.distance_to(at)})
				elif minf(via_a, via_b) < INF:
					var node := edge_a[e] if via_a <= via_b else edge_b[e]
					cands.append({"at": at, "node": node, "edge": e, "cost": minf(via_a, via_b)})
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["cost"] < y["cost"])
	return cands


## Parameters t in [0, 1] where segment a-b crosses the circle (centre c, radius rr).
static func _ring_hits(a: Vector2, b: Vector2, c: Vector2, rr: float) -> Array[float]:
	var out: Array[float] = []
	var d := b - a
	var f := a - c
	var qa := d.dot(d)
	if qa < 0.0001:
		return out
	var qb := 2.0 * f.dot(d)
	var qc := f.dot(f) - rr * rr
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return out
	var s := sqrt(disc)
	for t: float in [(-qb - s) / (2.0 * qa), (-qb + s) / (2.0 * qa)]:
		if t >= 0.0 and t <= 1.0:
			out.append(t)
	return out


## Where the other tanks are posted (their goal, or where they stand without one).
func _posts(except: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for other: RampageSim.Tank in sim.tanks:
		if other.id == except:
			continue
		var o: Route = routes.get(other.id)
		out.append(o.goal if o != null and o.goal.x != INF else other.pos)
	return out


func _spaced(at: Vector2, posts: Array[Vector2], pass_no: int, spread: float, gap: float) -> bool:
	var k := sim.kaiju_pos
	for p: Vector2 in posts:
		if pass_no == 0 and absf((at - k).angle_to(p - k)) < spread:
			return false
		if p.distance_to(at) < gap:
			return false
	return true


## Is the line from `from` to the kaiju (stopping short of its body) clear of standing buildings
## at least cover x the kaiju's height (a lower one it fires over)?
func clear_line(from: Vector2, to: Vector2) -> bool:
	var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var span := to - from
	var length := span.length()
	if length <= body:
		return true
	var end := from + span * ((length - body) / length)
	var over := Num.f(cfg["cover"]) * sim.reach_height()
	var seen := {}
	var steps := ceili(from.distance_to(end) / (_cell * 0.5)) + 1
	for s: int in steps + 1:
		var key := _cell_of(from.lerp(end, float(s) / steps))
		if not _grid.has(key):
			continue
		for i: int in _grid[key]:
			if seen.has(i):
				continue
			seen[i] = true
			var b := sim.buildings[i]
			if float(b.frame.alive_count) / float(b.w * b.d) < over:
				continue
			var rect := Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)
			if _hits_rect(from, end, rect):
				return false
	return true


static func _hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var corners: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y),
	]
	for n: int in 4:
		if Geometry2D.segment_intersects_segment(a, b, corners[n], corners[(n + 1) % 4]) != null:
			return true
	return false


## Drives along the route at speed (reversing slower, hull still to the kaiju, when it backs
## off), its hull never overlapping another's (with `clear` to spare) and holding `follow`
## behind one ahead of it in its lane.
func _drive(tank: RampageSim.Tank, r: Route, dt: float) -> void:
	tank.reversing = false
	if r.yield_t > 0.0:  # giving way: back up while the older tank is still held up, then wait
		r.yield_t -= dt
		var older: RampageSim.Tank = null
		for other: RampageSim.Tank in sim.tanks:
			if other.id == r.give_to:
				older = other
		if older != null:
			_back_off(tank, older, Num.f(sim.army["speed"]) * Num.f(cfg["reverse"]) * dt)
			var o: Route = routes.get(older.id)
			if o != null and o.stuck_t > 0.0 and r.yield_t <= 0.0 and r.yield_all < Num.f(cfg["stuck"]) * 3.0:
				r.yield_t = dt  # it is still held up: keep out of its way a while longer
			r.yield_all += dt
		return
	r.yield_all = 0.0
	if r.path.is_empty():
		return
	var target := r.path[0]
	var to := target - tank.pos
	var dist := to.length()
	var dir := to / dist if dist > 0.0001 else Vector2.ZERO
	var speed := Num.f(sim.army["speed"])
	if r.retreating and dir.dot(sim.kaiju_pos - tank.pos) < 0.0:
		tank.reversing = true
		speed *= Num.f(cfg["reverse"])
	var move := minf(dist, speed * dt)
	var next := tank.pos + dir * move
	var blocker := _blocker(tank, next, dir)
	if blocker != null:
		r.stuck_t += dt
		_give_way(tank, blocker, speed * Num.f(cfg["reverse"]) * dt)
		if r.stuck_t >= Num.f(cfg["stuck"]):
			r.avoid = r.edges[0] if not r.edges.is_empty() else -1
			_plan(tank, r, r.retreating)
		return
	r.stuck_t = 0.0
	tank.heading = dir
	tank.pos = next
	if not r.edges.is_empty() and r.edges[0] >= 0:
		r.edge = r.edges[0]
	if move >= dist - 0.0001:
		r.path.remove_at(0)
		r.edges.remove_at(0)
		if r.path.is_empty():
			r.retreating = false


## Right of way: blocked by an older tank that is itself held up trying to move, the younger
## one gives way for `stuck` seconds, backing up (hull still facing its way) while it is in the
## older one's road.
func _give_way(tank: RampageSim.Tank, blocker: RampageSim.Tank, step: float) -> void:
	var o: Route = routes.get(blocker.id)
	if blocker.id > tank.id or o == null or o.path.is_empty() or o.stuck_t <= 0.0:
		return
	var r: Route = routes[tank.id]
	r.give_to = blocker.id
	r.yield_t = Num.f(cfg["stuck"])
	_back_off(tank, blocker, step)


func _back_off(tank: RampageSim.Tank, older: RampageSim.Tank, step: float) -> void:
	var o: Route = routes.get(older.id)
	if o == null or o.stuck_t <= 0.0:
		return
	var own := tank.heading if tank.heading != Vector2.ZERO else (tank.pos - older.pos).normalized()
	var back := -own if own.dot(tank.pos - older.pos) < 0.0 else own
	var to := tank.pos + back * step
	if _blocker(tank, to, own) == null:
		tank.pos = to
		tank.reversing = back.dot(own) < 0.0


## The tank in the way of a move to `next` heading `dir`, or null.
func _blocker(tank: RampageSim.Tank, next: Vector2, dir: Vector2) -> RampageSim.Tank:
	var hull: Array = cfg["hull"]
	var clear := Num.f(cfg["clear"])
	var half := Vector2(Num.f(hull[0]), Num.f(hull[1])) * 0.5 + Vector2(clear, clear)
	var follow := Num.f(cfg["follow"])
	for other: RampageSim.Tank in sim.tanks:
		if other.id == tank.id:
			continue
		var now := tank.pos.distance_to(other.pos)
		var then := next.distance_to(other.pos)
		if then > follow + half.x:
			continue
		var facing := other.heading if other.heading != Vector2.ZERO else dir
		var own := tank.heading if tank.heading != Vector2.ZERO else dir
		if hulls_overlap(next, dir, other.pos, facing, half):
			# Never into a new overlap; out of one (a tank set down on another) only by opening up.
			if then <= now or not hulls_overlap(tank.pos, own, other.pos, facing, half):
				return other
		if then >= now:
			continue
		var ahead := other.pos - tank.pos
		var lane := dir.dot(ahead) > 0.0 and absf(dir.cross(ahead)) < half.y * 2.0
		if lane and then < follow and facing.dot(dir) > 0.7:
			return other  # ahead of it in its lane, going its way: hold the column gap
	return null


## Do two hulls (centres, headings, half length and half width) overlap? Separating axes.
static func hulls_overlap(p: Vector2, u: Vector2, q: Vector2, w: Vector2, half: Vector2) -> bool:
	var axes: Array[Vector2] = [u, u.orthogonal(), w, w.orthogonal()]
	var d := q - p
	for axis: Vector2 in axes:
		var ra := half.x * absf(u.dot(axis)) + half.y * absf(u.orthogonal().dot(axis))
		var rb := half.x * absf(w.dot(axis)) + half.y * absf(w.orthogonal().dot(axis))
		if absf(d.dot(axis)) > ra + rb:
			return false
	return true


## A tower that toppled across a road closes it for the rest of the rampage: tanks on a route
## through it re-plan at once.
func _read_rubble() -> void:
	var hull: Array = cfg["hull"]
	var half_tank := Num.f(hull[1]) * 0.5
	var closed := false
	for event: Dictionary in sim.events:
		if str(event["type"]) != "fall_land" or str(event.get("kind", "")) != "topple":
			continue
		var from: Vector2 = event["from"]
		var to: Vector2 = event["to"]
		var reach_out := Num.f(event["width"]) * 0.5 + half_tank
		for e: int in edge_a.size():
			if blocked[e] == 0 and _segments_near(nodes[edge_a[e]], nodes[edge_b[e]], from, to, reach_out):
				blocked[e] = 1
				closed = true
	if not closed:
		return
	for tank: RampageSim.Tank in sim.tanks:
		var r: Route = routes.get(tank.id)
		if r == null:
			continue
		for e: int in r.edges:
			if e >= 0 and blocked[e] != 0:
				_plan(tank, r, r.retreating)
				break


static func _segments_near(a: Vector2, b: Vector2, c: Vector2, d: Vector2, within: float) -> bool:
	if Geometry2D.segment_intersects_segment(a, b, c, d) != null:
		return true
	var best := minf(
		Geometry2D.get_closest_point_to_segment(a, c, d).distance_to(a),
		Geometry2D.get_closest_point_to_segment(b, c, d).distance_to(b)
	)
	best = minf(best, Geometry2D.get_closest_point_to_segment(c, a, b).distance_to(c))
	best = minf(best, Geometry2D.get_closest_point_to_segment(d, a, b).distance_to(d))
	return best < within
