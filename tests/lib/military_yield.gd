extends RefCounted
## A tank made to give way by one inside the danger radius (TankSpacing.demand_way) does not yield
## for ever. TankSpacing.yielding stops re-arming a yield after yield_limit() (`stuck x yield_cap`)
## seconds so the tank gets a free step (a re-plan) from time to time; demand_way re-armed it every
## step the other tank stayed held up, so a boxed-in tank yielded to the end of the run. The case:
## one straight road, A inside the danger radius and held up behind B outside it, C right ahead of
## B so B has no room to back out of A's way. A's held-up step is Convoy._drive's blocked branch
## (give_way); B is driven by the real Convoy._drive. Part of the military suite.
## Seeded by design: city seed 0, no random draw here.

const DT := 1.0 / 15.0
const SECONDS := 60.0
## Hull centre to hull centre along the road: a hull and its clearance apart, inside `follow`, so
## B cannot close up on C.
const GAP := 7.0
## How far inside the danger radius A stands.
const INSIDE := 2.0
## Hull spots along the road that must be drivable: A, B, C and A's way out beyond.
const LENGTH := 5

var _check: Callable
var _make: Callable


## check: the runner's check; make(tier, seed) -> RampageSim.
func _init(p_check: Callable, make: Callable) -> void:
	_check = p_check
	_make = make


func run() -> void:
	var sim: RampageSim = _make.call(1, 0)
	var convoy := sim.army_units.convoy
	var graph := convoy.graph
	var road := _straight_road(sim)
	if road.is_empty():
		_check.call(false, "a straight road with room for a column of three tanks")
		return
	var u: Vector2 = road["dir"]
	var at: Vector2 = road["at"]
	var e: int = road["edge"]
	sim.facing = u.orthogonal()  # the body runs off the road: its distance to the column is along it
	sim.kaiju_pos = at - u * (convoy.danger() - INSIDE)
	var tanks: Array[RampageSim.Tank] = []
	for n: int in 3:
		var tank := RampageSim.Tank.new()
		tank.id = n
		tank.pos = at + u * GAP * n
		tank.hp = 100.0
		sim.tanks.append(tank)
		tanks.append(tank)
		var route := ConvoyRoute.new()
		route.edge = graph.road_under(tank.pos, e)
		route.heading = u
		route.front = u
		convoy.routes[n] = route
	var a := tanks[0]
	var b := tanks[1]
	var ra: ConvoyRoute = convoy.routes[0]
	var rb: ConvoyRoute = convoy.routes[1]
	ra.path.assign([at + u * GAP * (LENGTH - 1)])  # A's way out runs through B and C
	ra.edges.assign([e])
	ra.retreating = true
	var spacing := convoy.spacing
	var back := Num.f(sim.army["speed"]) * Num.f(convoy.cfg["reverse"]) * DT
	_check.call(
		convoy.spacing.in_danger(a) and not convoy.spacing.in_danger(b),
		(
			"A stands inside the danger radius and B outside it (%.1f, %.1f of %.1f m)"
			% [convoy.posts.to_body(a.pos), convoy.posts.to_body(b.pos), convoy.danger()]
		)
	)
	var start := b.pos
	var longest := 0.0  # the longest stretch B starts its step still yielding
	var stretch := 0.0
	var free := 0  # steps B starts free to drive
	var most := 0.0  # the most yield_all (seconds yielding this time) reaches
	for n: int in roundi(SECONDS / DT):
		ra.stuck_t = DT  # A stays held up behind B
		spacing.give_way(a, b, back)
		if rb.yield_t > 0.0:
			stretch += DT
			longest = maxf(longest, stretch)
		else:
			stretch = 0.0
			free += 1
		convoy._drive(b, rb, DT)
		most = maxf(most, rb.yield_all)
	var stuck := Num.f(convoy.cfg["stuck"])
	var cap := convoy.spacing.yield_limit()
	var said := (
		(
			"B, made to give way by A for %.0f s while boxed in by C, yields at most %.1f s at a time"
			+ " (the %.0f s cap and one more wait) and is free to drive %d steps (yield_all up to"
			+ " %.1f s, moved %.1f m)"
		)
		% [SECONDS, longest, cap, free, most, b.pos.distance_to(start)]
	)
	print("YIELD " + said)
	_check.call(longest <= cap + stuck + 0.5 and free >= 3, said)


## A straight stretch of road, over any number of blocks, with room for A, B and C a GAP apart and
## A's way out beyond: {edge (a road under A), at (A's spot), dir (along the road)}, or {}.
func _straight_road(sim: RampageSim) -> Dictionary:
	var graph := sim.army_units.convoy.graph
	for e: int in graph.edge_a.size():
		var u := graph.axis(e)
		var from := graph.nodes[graph.edge_a[e]]
		for s: float in range(0, int(graph.edge_len[e]), 2):
			var ok := true
			for n: int in LENGTH:
				var p := from + u * (s + GAP * n)
				ok = ok and graph.drivable(p, u) and graph.square(u, graph.road_under(p, e))
			if ok:
				return {"edge": e, "at": from + u * s, "dir": u}
	return {}
