class_name FiringPosts
extends RefCounted
## Where a tank posts itself (D-066): a firing post on a road in the firing band round the
## kaiju with a clear line of fire, spread from the other tanks' posts round it on an arc; with
## every post taken, a reserve post out of range on the reserve ring or one behind it. Part of
## Convoy; numbers are army.convoy in data/tuning.json.

var convoy: Convoy
var graph: RoadGraph
var sim: RampageSim
var cfg: Dictionary


func _init(p_convoy: Convoy) -> void:
	convoy = p_convoy
	graph = convoy.graph
	sim = convoy.sim
	cfg = convoy.cfg


## The post for `tank` with routes `found` (RoadSearch.search): {at, node, edge, reserve}, or {}
## to keep the reserve post it holds (or when there is none to be had). The cheapest route wins:
## spread_deg round the kaiju from every other post first, then post_gap apart alone.
func choose(tank: RampageSim.Tank, r: ConvoyRoute, found: Dictionary, urgent: bool) -> Dictionary:
	var k := sim.kaiju_pos
	var others := _posts(tank.id)
	var spread := deg_to_rad(Num.f(cfg["spread_deg"]))
	var follow := Num.f(cfg["follow"])
	var gap := Num.f(cfg["post_gap"])
	var cands := _band_posts(tank, r, found)
	for arc: float in [spread, 0.0]:
		for c: Dictionary in cands:
			var at: Vector2 = c["at"]
			if _spaced(at, others, arc, gap) and clear_line(at, k):
				return c
	var held := r.goal.distance_to(k)
	var rings := reserve_rings()
	var widest := rings[rings.size() - 1] + follow
	var keep := r.reserve and not urgent and held > convoy.reach() and held < widest
	if keep and _spaced(r.goal, others, 0.0, follow):
		return {}
	for c: Dictionary in ring_posts(tank, r, found, rings):
		var at: Vector2 = c["at"]
		if _spaced(at, others, 0.0, follow):
			c["reserve"] = true
			return c
	return {}


## The reserve ring (reserve x full reach) and three wider ones behind it.
func reserve_rings() -> Array[float]:
	var out := convoy.reach() * Num.f(cfg["reserve"])
	var rings: Array[float] = []
	for n: int in 4:
		rings.append(out * (1.0 + 0.25 * n))
	return rings


## Firing posts: points post_gap apart along every reachable, open road inside the firing band
## (band x full reach), the ones nearest the standoff ring on the cheapest routes first.
func _band_posts(tank: RampageSim.Tank, r: ConvoyRoute, found: Dictionary) -> Array[Dictionary]:
	var k := sim.kaiju_pos
	var band: Array = cfg["band"]
	var lo := convoy.reach() * Num.f(band[0])
	var hi := convoy.reach() * Num.f(band[1])
	var mid := convoy.reach() * Num.f(cfg["standoff"])
	var step := Num.f(cfg["post_gap"])
	var cands: Array[Dictionary] = []
	for e: int in graph.edges_within(k, hi):
		if graph.blocked[e] != 0 or r.skip.has(e) or graph.off_line(k, e) > hi:
			continue
		var length := graph.edge_len[e]
		var a := graph.nodes[graph.edge_a[e]]
		var b := graph.nodes[graph.edge_b[e]]
		var last := -INF  # metres along the road of the last post taken
		for n: int in floori(length) + 1:
			var at := a.lerp(b, minf(1.0, n / maxf(length, 0.001)))
			var d := at.distance_to(k)
			if d < lo or d > hi or n - last < step or to_body(at) < convoy.danger():
				continue
			last = n
			var c := _reach_post(tank, r, found, [e, at])
			if not c.is_empty():
				c["cost"] = Num.f(c["cost"]) + absf(d - mid) * 2.0
				cands.append(c)
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["cost"] < y["cost"])
	return cands


## Every point where a reachable, open road crosses one of `rings` round the kaiju, cheapest
## route first.
func ring_posts(
	tank: RampageSim.Tank, r: ConvoyRoute, found: Dictionary, rings: Array[float]
) -> Array[Dictionary]:
	var k := sim.kaiju_pos
	var cands: Array[Dictionary] = []
	var widest: float = rings.max()
	for e: int in graph.edges_within(k, widest):
		if graph.blocked[e] != 0 or r.skip.has(e):
			continue
		var a := graph.nodes[graph.edge_a[e]]
		var b := graph.nodes[graph.edge_b[e]]
		for ring: float in rings:
			for t: float in _ring_hits(a, b, k, ring):
				if to_body(a.lerp(b, t)) < convoy.danger():
					continue
				var c := _reach_post(tank, r, found, [e, a.lerp(b, t)])
				if not c.is_empty():
					cands.append(c)
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["cost"] < y["cost"])
	return cands


## A post at spot = [road e, point at] and how to get there: {at, node (where the route
## leaves the graph; -1 drives straight along the road the tank is on), edge, cost}, or {} if
## out of reach.
func _reach_post(
	tank: RampageSim.Tank, r: ConvoyRoute, found: Dictionary, spot: Array
) -> Dictionary:
	var e: int = spot[0]
	var at: Vector2 = spot[1]
	if r.edge == e and graph.on_edge(tank.pos, e):
		var turn := not r.path.is_empty() and (at - tank.pos).dot(r.heading) < 0.0
		var extra := Num.f(cfg["uturn_cost"]) if turn else 0.0
		return {"at": at, "node": -1, "edge": e, "cost": tank.pos.distance_to(at) + extra}
	var cost: PackedFloat32Array = found["cost"]
	var na := graph.edge_a[e]
	var nb := graph.edge_b[e]
	var via_a := cost[na] + graph.nodes[na].distance_to(at)
	var via_b := cost[nb] + graph.nodes[nb].distance_to(at)
	if minf(via_a, via_b) == INF:
		return {}
	return {"at": at, "node": na if via_a <= via_b else nb, "edge": e, "cost": minf(via_a, via_b)}


## Parameters t in [0, 1] where segment a-b crosses the circle (centre c, radius rr).
static func _ring_hits(a: Vector2, b: Vector2, c: Vector2, rr: float) -> Array[float]:
	var out: Array[float] = []
	var d := b - a
	var f := a - c
	var qa := d.dot(d)
	var qb := 2.0 * f.dot(d)
	var disc := qb * qb - 4.0 * qa * (f.dot(f) - rr * rr)
	if qa < 0.0001 or disc < 0.0:
		return out
	for t: float in [(-qb - sqrt(disc)) / (2.0 * qa), (-qb + sqrt(disc)) / (2.0 * qa)]:
		if t >= 0.0 and t <= 1.0:
			out.append(t)
	return out


## Where the other tanks are posted (their goal, or where they stand without one).
func _posts(except: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for other: RampageSim.Tank in sim.tanks:
		if other.id == except:
			continue
		var o: ConvoyRoute = convoy.routes.get(other.id)
		out.append(o.goal if o != null and o.goal.x != INF else other.pos)
	return out


## Is `at` gap from every post, and (arc > 0) arc round the kaiju from each?
func _spaced(at: Vector2, others: Array[Vector2], arc: float, gap: float) -> bool:
	var k := sim.kaiju_pos
	for p: Vector2 in others:
		if p.distance_to(at) < gap or (arc > 0.0 and absf((at - k).angle_to(p - k)) < arc):
			return false
	return true


## The kaiju's head: its snout, where the breath starts (BreathCone). kaiju_pos is the model's
## origin (on the croc its tail root); danger is measured from the body between the two.
func head() -> Vector2:
	var at: Vector2 = BreathCone.of(sim)["origin"]
	return at


## How far p is from the kaiju's body (the line from its origin to its head).
func to_body(p: Vector2) -> float:
	return Geometry2D.get_closest_point_to_segment(p, sim.kaiju_pos, head()).distance_to(p)


## The roads within `near` of the kaiju's body (road -> true).
func roads_by_body(near: float) -> Dictionary:
	var h := head()
	var out := {}
	for e: int in graph.edges_within(sim.kaiju_pos, near + sim.kaiju_pos.distance_to(h)):
		var a := graph.nodes[graph.edge_a[e]]
		if RoadGraph._near(a, graph.nodes[graph.edge_b[e]], sim.kaiju_pos, h) < near:
			out[e] = true
	return out


## Does the route from `from` through `points` pass inside the danger radius of the body (any
## nearer it than `from` itself, when it already stands inside)?
func crosses_danger(from: Vector2, points: Array) -> bool:
	var h := head()
	var inner := minf(convoy.danger(), to_body(from) - 0.5)
	var a := from
	for b: Vector2 in points:
		if RoadGraph._near(a, b, sim.kaiju_pos, h) < inner:
			return true
		a = b
	return false


## Straight back along the road under the tank, away from the kaiju, to `follow` beyond the
## danger radius (no further than that road's end): [path, legs], empty if it is already out.
func fall_back(tank: RampageSim.Tank, r: ConvoyRoute) -> Array:
	var e := graph.road_under(tank.pos, r.edge)
	var axis := graph.axis(e)
	var body := Geometry2D.get_closest_point_to_segment(tank.pos, sim.kaiju_pos, head())
	var away := axis if axis.dot(tank.pos - body) >= 0.0 else -axis
	var na := graph.nodes[graph.edge_a[e]]
	var nb := graph.nodes[graph.edge_b[e]]
	var end := maxf((na - tank.pos).dot(away), (nb - tank.pos).dot(away))
	var want := convoy.danger() + Num.f(cfg["follow"]) - tank.pos.distance_to(body)
	if want <= 0.0 or end <= 0.0:
		return [[], []]
	return [[tank.pos + away * minf(want, end)], [e]]


## Is the line from `from` to `to` (stopping short of the kaiju's body) clear of standing
## buildings at least cover x the kaiju's height (a lower one it fires over)?
func clear_line(from: Vector2, to: Vector2) -> bool:
	var body := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale()
	var length := from.distance_to(to)
	if length <= body:
		return true
	var end := from.lerp(to, (length - body) / length)
	var over := Num.f(cfg["cover"]) * sim.reach_height()
	var seen := {}
	var steps := ceili(from.distance_to(end) / (graph.cell * 0.5)) + 1
	for s: int in steps + 1:
		for i: int in graph.lots_at(graph.cell_of(from.lerp(end, float(s) / steps))):
			if seen.has(i):
				continue
			seen[i] = true
			var b := sim.buildings[i]
			if float(b.frame.alive_count) / float(b.w * b.d) < over:
				continue
			if _hits_rect(from, end, Rect2(b.x - b.w * 0.5, b.z - b.d * 0.5, b.w, b.d)):
				return false
	return true


static func _hits_rect(a: Vector2, b: Vector2, rect: Rect2) -> bool:
	if rect.has_point(a) or rect.has_point(b):
		return true
	var c: Array[Vector2] = [
		rect.position,
		Vector2(rect.end.x, rect.position.y),
		rect.end,
		Vector2(rect.position.x, rect.end.y)
	]
	for n: int in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[n], c[(n + 1) % 4]) != null:
			return true
	return false
