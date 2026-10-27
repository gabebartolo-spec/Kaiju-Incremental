class_name ConvoyHull
extends RefCounted
## A tank's hull on the road (D-066), part of Convoy: where it fits, how it squares to its road,
## and how it makes room to pivot. No tank turns or steps into a place its whole hull (and every
## part of it on the way round) does not fit on the carriageway clear of other tanks. Numbers:
## army.convoy (pivot_deg) in data/tuning.json.

var convoy: Convoy
var graph: RoadGraph
var cfg: Dictionary


func _init(p_convoy: Convoy) -> void:
	convoy = p_convoy
	graph = convoy.graph
	cfg = convoy.cfg


## A leg askew to every road under the tank (a lane point past a crossing's centre, or one
## square_leg could not square) is driven along the nearest of those roads: never crabbing.
func onto_axis(at: Vector2, to: Vector2, edge: int) -> Vector2:
	var v := to - at
	if v.length() < 0.0001:
		return to
	var way := v.normalized()
	var best := Vector2.ZERO
	for e: int in graph.roads_at(graph.cell_of(at)) + PackedInt32Array([edge]):
		if e < 0 or not graph.on_edge(at, e):
			continue
		if graph.square(way, e):
			return to
		if absf(way.dot(graph.axis(e))) > absf(way.dot(best)):
			best = graph.axis(e)
	return to if best == Vector2.ZERO else at + best * v.dot(best)


## No room to pivot here: a step along the hull (forward or back) to where the whole turn fits.
func shuffle(tank: RampageSim.Tank, r: ConvoyRoute, turned: Vector2, step: float) -> bool:
	if not graph.square(r.front, r.edge):  # never along a half-turned hull
		return false
	for way: Vector2 in [r.front, -r.front]:
		var to := tank.pos + way * step
		if fits(tank, to, r.front) and sweep_fits(tank, to, turned):
			tank.pos = to
			return true
	return false


func fits(tank: RampageSim.Tank, at: Vector2, front: Vector2) -> bool:
	return graph.drivable(at, front) and convoy.spacing.blocker(tank, at, front) == null


## Room to swing the hull round to `to` standing at `at`, every pivot_deg of the way: a pivot
## starts only when it can finish.
func sweep_fits(tank: RampageSim.Tank, at: Vector2, to: Vector2) -> bool:
	var r: ConvoyRoute = convoy.routes[tank.id]
	var turn := r.front.angle_to(to)
	var steps := ceili(absf(turn) / deg_to_rad(Num.f(cfg["pivot_deg"])))
	for k: int in range(1, steps + 1):
		if not fits(tank, at, r.front.rotated(turn * k / steps)):
			return false
	return true


## At its post a tank squares its hull to its road (the nearer way; parked at a crossing, the
## road its hull lies nearer); only its turret turns. When that swing has no room (a tank
## pulled up beside it mid-pivot), it squares to the nearest road axis at the crossing that
## has, so it never waits half turned.
func settle(tank: RampageSim.Tank, r: ConvoyRoute, rate: float) -> void:
	if r.edge < 0 or r.front == Vector2.ZERO:
		return
	for want: Vector2 in _axes(tank, r):
		if absf(r.front.angle_to(want)) < 0.0001:
			return  # squared already
		var front := r.front.rotated(clampf(r.front.angle_to(want), -rate, rate))
		if fits(tank, tank.pos, front):
			r.front = front
			return


## The road axes under the tank, hull-ward way, nearest the hull first: the roads it means to lie
## along, then any other road under it at a crossing.
func _axes(tank: RampageSim.Tank, r: ConvoyRoute) -> Array[Vector2]:
	var first: Array[Vector2] = []
	var then: Array[Vector2] = []
	for e: int in graph.roads_at(graph.cell_of(tank.pos)) + PackedInt32Array([r.edge]):
		var under := graph.on_edge(tank.pos, e)
		var mine := e == r.edge or r.path.is_empty() and under
		if mine or under:
			var list := first if mine else then
			list.append(graph.axis(e) * (1.0 if graph.axis(e).dot(r.front) >= 0.0 else -1.0))
	var nearer := func(x: Vector2, y: Vector2) -> bool: return x.dot(r.front) > y.dot(r.front)
	first.sort_custom(nearer)
	then.sort_custom(nearer)
	return first + then
