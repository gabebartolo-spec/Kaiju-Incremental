class_name Convoy
extends RefCounted
## How the tanks move (D-066): like an army, not a swarm. They enter by road and drive the street
## plan (RoadGraph: never an alley, a lot or a building) in columns that keep their gap, pivoting
## at turns. Each takes a firing post on a road at standoff with a clear line of fire, spread on
## an arc (FiringPosts), holds it while good, bounds to a new one when the kaiju moves (one tank
## of a column at a time), backs off inside the danger radius, re-routes round a tank or a toppled
## tower in its way, and gives way to an older tank. Pure and seeded; Army owns spawning, firing
## and damage. Numbers: army.convoy in data/tuning.json.

var sim: RampageSim
var cfg: Dictionary
var graph: RoadGraph
var search: RoadSearch
var posts: FiringPosts
var spacing: TankSpacing
var routes: Dictionary = {}  # tank id -> ConvoyRoute
var kaiju_vel := Vector2.ZERO  # how the kaiju walks (m/s), from its last step
var _kaiju_was := Vector2(INF, INF)
var _plans_left := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg
	graph = RoadGraph.new(sim, cfg)
	search = RoadSearch.new(graph, cfg)
	posts = FiringPosts.new(self)
	spacing = TankSpacing.new(self)


## Full reach and the danger radius for the kaiju as it is now.
func reach() -> float:
	return Num.f(sim.army["range"]) + sim.stomp_radius()


func danger() -> float:  # from the body line: its edge (body_radius) + edge_gap, at least
	var edge := Num.f(sim.powers_cfg["body_radius"]) * sim.body_scale() + Num.f(cfg["edge_gap"])
	return maxf(reach() * Num.f(cfg["danger"]), edge)


## Is the line of fire from `from` to `to` clear (FiringPosts.clear_line)?
func clear_line(from: Vector2, to: Vector2) -> bool:
	return posts.clear_line(from, to)


## Where tank `id`'s hull points (ZERO before it has a route): the view draws exactly this.
func front(id: int) -> Vector2:
	var r: ConvoyRoute = routes.get(id)
	return r.front if r != null else Vector2.ZERO


## Where a new tank enters at `node` (pick_entry): records its route and returns where it
## starts, or INF when that way in is still taken by the tank before it.
func enter(id: int, column: int, node: int) -> Vector2:
	if node < 0 or graph.links[node].is_empty():
		return Vector2(INF, INF)
	for tank: RampageSim.Tank in sim.tanks:
		if tank.pos.distance_to(graph.nodes[node]) < Num.f(cfg["follow"]):
			return Vector2(INF, INF)
	var e := graph.links[node][0]
	var far := graph.edge_b[e] if graph.edge_a[e] == node else graph.edge_a[e]
	var into := (graph.nodes[far] - graph.nodes[node]).normalized()  # facing into its road
	if not graph.drivable(graph.nodes[node], into):  # a stub too short for the hull
		return Vector2(INF, INF)
	var r := ConvoyRoute.new()
	r.column = column
	r.edge = e
	r.heading = into
	r.front = into
	routes[id] = r
	return graph.nodes[node]


## The way in for a column on `bearing` (RoadGraph.pick_entry).
func pick_entry(bearing: float) -> int:
	return graph.pick_entry(bearing, sim.kaiju_pos, Num.f(sim.army["spawn_radius"]))


## One step for every tank: read what fell across the roads, re-plan where needed (at most
## plans_per_step, the urgent ones always), then drive.
func step(dt: float) -> void:
	if dt > 0.0:
		kaiju_vel = (sim.kaiju_pos - _kaiju_was) / dt if _kaiju_was.x != INF else Vector2.ZERO
		_kaiju_was = sim.kaiju_pos
	_read_rubble()
	var near := danger()
	_refresh_costs(near)
	_plans_left = Num.i(cfg["plans_per_step"])
	for tank: RampageSim.Tank in sim.tanks:
		var r: ConvoyRoute = routes.get(tank.id)
		if r == null:
			r = ConvoyRoute.new()
			routes[tank.id] = r
		r.replan_t -= dt
		var urgent := posts.to_body(tank.pos) < near
		if not urgent and r.path.is_empty():
			r.retreating = false
		if urgent and not r.retreating:
			_plan(tank, r, true)
		elif r.replan_t <= 0.0 and (_plans_left > 0 or urgent):
			r.replan_t = Num.f(cfg["replan"])
			if not _goal_good(r) and (urgent or not _covering(tank, r)):
				_plans_left -= 1
				_plan(tank, r, urgent)
		_drive(tank, r, dt)
	for id: int in routes.keys():
		if not sim.tanks.any(func(t: RampageSim.Tank) -> bool: return t.id == id):
			routes.erase(id)


## The search costs this step: roads by the kaiju's feet, held at a post, and driven (which way).
func _refresh_costs(near: float) -> void:
	search.near_kaiju = posts.roads_by_body(near)
	search.held = {}
	search.driven = {}
	for tank: RampageSim.Tank in sim.tanks:
		var o: ConvoyRoute = routes.get(tank.id)
		if o == null:
			continue
		if o.path.is_empty() and o.edge >= 0:
			search.held[o.edge] = true
		var from := tank.pos
		for i: int in o.path.size():
			if o.edges[i] >= 0:
				search.driven[o.edges[i]] = o.path[i] - from
			from = o.path[i]


## A post is good while in the band between danger and full reach with a clear shot (on the way
## to it, while no further than commit x reach: a tank does not turn back at every kaiju step).
func _goal_good(r: ConvoyRoute) -> bool:
	if r.goal.x == INF:
		return false
	var d := r.goal.distance_to(sim.kaiju_pos)
	var clear := posts.to_body(r.goal) >= danger()  # clear of the body, head to tail root
	if not r.path.is_empty():  # on its way it commits to the post, unless the kaiju drew off
		return clear and d <= reach() * Num.f(cfg["commit"])
	return clear and d <= reach() and clear_line(r.goal, sim.kaiju_pos)


## Bounding overwatch: a tank at its post waits for its column's moving tank to settle first.
func _covering(tank: RampageSim.Tank, r: ConvoyRoute) -> bool:
	if not r.path.is_empty() or r.goal.x == INF or r.column < 0:
		return false
	if r.goal.distance_to(sim.kaiju_pos) > reach():  # out of range: it cannot cover anyone
		return false
	for other: RampageSim.Tank in sim.tanks:
		var o: ConvoyRoute = routes.get(other.id)
		if other.id != tank.id and o != null and o.column == r.column and not o.path.is_empty():
			r.replan_t = Num.f(cfg["replan"]) * 0.25
			return true
	return false


## Picks a post (FiringPosts) and the road route to it; urgent: the kaiju is on top of it.
func _plan(tank: RampageSim.Tank, r: ConvoyRoute, urgent: bool) -> void:
	r.stuck_t = 0.0
	r.replan_t = Num.f(cfg["replan"])
	var start := _start(tank, r)
	var rings := posts.reserve_rings()
	var widest: float = rings.max()
	var disc := maxf(tank.pos.distance_to(sim.kaiju_pos), widest) + Num.f(cfg["search_margin"])
	var from: Dictionary = start["from"]
	var found := search.search(from, r.skip, sim.kaiju_pos, disc)
	if graph.on_edge(tank.pos, Num.i(start["edge"])):
		r.edge = Num.i(start["edge"])
	var goal := posts.choose(tank, r, found, urgent)
	if goal.is_empty() and urgent:  # every post taken and the kaiju on top of it: back off anyway
		var away := posts.ring_posts(tank, r, found, [rings[0]] as Array[float])
		if not away.is_empty():
			goal = away[0]
			goal["reserve"] = true
	r.skip = {}
	if goal.is_empty():
		r.retreating = urgent  # nowhere to go: try again at the next re-plan, not every step
		return
	var chain: Array[int] = []
	start["node"] = -1
	if Num.i(goal["node"]) >= 0:
		var walk := search.chain_to(found, Num.i(goal["node"]))
		var roads: Array = walk[0]
		chain.assign(roads)
		start["node"] = walk[1]
	var way := graph.waypoints(tank.pos, start, chain, goal)
	var points: Array = way[0]
	if posts.crosses_danger(tank.pos, points):  # never past the kaiju's feet: back off instead
		way = posts.fall_back(tank, r)
		points = way[0]
		goal["at"] = points[0] if not points.is_empty() else Vector2(INF, INF)
	var legs: Array = way[1]
	r.path.assign(points)
	r.edges.assign(legs)
	r.goal = goal["at"]
	r.reserve = goal.get("reserve", false)
	r.retreating = urgent and not r.path.is_empty()


## Where a tank sets off from: {edge (the road under it), via (its point on that road's line),
## from: {node: cost}}, both ends of that road, or only the end behind it when it was held up
## on this road going the other way.
func _start(tank: RampageSim.Tank, r: ConvoyRoute) -> Dictionary:
	var p := tank.pos
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


## Drives along the route at speed (reversing slower, front still to the kaiju, when it backs
## off), hull on the carriageway and clear of others, `follow` behind one ahead in its lane. It
## drives only along its hull: a turn it makes standing at hull_turn first (shuffling a hull's
## step forward or back where the turn will not fit). Held up `stuck` seconds, it re-plans
## round what held it.
func _drive(tank: RampageSim.Tank, r: ConvoyRoute, dt: float) -> void:
	r.reversing = false
	var back := Num.f(sim.army["speed"]) * Num.f(cfg["reverse"]) * dt
	var rate := deg_to_rad(Num.f(cfg["hull_turn"])) * dt
	if r.yield_t > 0.0:
		spacing.yielding(tank, r, dt, back)
		_settle(tank, r, rate)  # giving way mid-pivot: it waits squared to its road
		return
	if r.yield_all > 0.0:  # backed off its path: set off again from where it stands
		r.yield_all = 0.0
		_plan(tank, r, r.retreating)
	if r.path.is_empty():
		_settle(tank, r, rate)
		spacing.open_up(tank, r, back)  # the kaiju moved and a gun swung over a neighbour
		return
	r.path[0] = graph.square_leg(tank.pos, r.path[0], r.edges[0])  # never down a diagonal
	var to := r.path[0] - tank.pos
	var dist := to.length()
	var dir := to / dist if dist > 0.0001 else r.front
	var speed := Num.f(sim.army["speed"])
	var behind := r.front.dot(dir) < (0.0 if r.retreating else -0.5)  # back off, never turn tail
	var clear_of := r.retreating and posts.to_body(tank.pos) < danger()  # out fast, then slow
	if behind and r.front != Vector2.ZERO:  # and back up rather than turn about in the road
		r.reversing = true
		speed = Num.f(cfg["retreat_speed"]) if clear_of else speed * Num.f(cfg["reverse"])
	elif clear_of:
		speed = maxf(speed, Num.f(cfg["retreat_speed"]))
	var want := -dir if r.reversing else dir
	r.front = want if r.front == Vector2.ZERO else r.front
	var turn := r.front.angle_to(want)
	if dist <= 1.0 and absf(turn) > rate:  # the last metre is not worth a turn: it is there
		_arrive(r)
		return
	var front := r.front.rotated(clampf(turn, -rate, rate))
	var move := 0.0 if absf(turn) > rate else minf(dist, speed * dt)  # squared first, then on
	var next := tank.pos + dir * move
	if not r.retreating and move > 0.0 and posts.to_body(next) < danger():
		r.path.clear()  # brake short of the standoff line: never across it
		r.edges.clear()
		return
	var blocker := _blocker(tank, next, front)
	var fits := graph.drivable(next, front) and (move > 0.0 or _sweep_fits(tank, tank.pos, want))
	if blocker == null and not fits and graph.drivable(tank.pos, r.front):
		if move == 0.0 and _shuffle(tank, r, want, back):
			return
		blocker = tank  # the hull would leave the road, or the turn has no room: held up
	if blocker != null:
		_settle(tank, r, rate)  # held up, or no room to turn: it waits squared to its road
		r.stuck_t += dt
		spacing.give_way(tank, blocker, back)
		if r.stuck_t >= Num.f(cfg["stuck"]) * (0.5 if r.retreating else 1.0):  # falling back: sooner
			_held_up(tank, r, blocker)
		return
	r.stuck_t = 0.0
	r.heading = dir
	r.front = front
	tank.pos = next
	if not r.edges.is_empty() and r.edges[0] >= 0:
		r.edge = r.edges[0]
	if move > 0.0 and move >= dist - 0.0001 or dist <= 0.0001:
		_arrive(r)


## At its next waypoint: on to the one after.
func _arrive(r: ConvoyRoute) -> void:
	r.path.remove_at(0)
	r.edges.remove_at(0)
	r.retreating = r.retreating and not r.path.is_empty()


## No room to pivot here: a step along the hull (forward or back) to where the whole turn fits.
func _shuffle(tank: RampageSim.Tank, r: ConvoyRoute, turned: Vector2, step: float) -> bool:
	if not graph.square(r.front, r.edge):  # never along a half-turned hull
		return false
	for way: Vector2 in [r.front, -r.front]:
		var to := tank.pos + way * step
		if _fits(tank, to, r.front) and _sweep_fits(tank, to, turned):
			tank.pos = to
			return true
	return false


func _fits(tank: RampageSim.Tank, at: Vector2, front: Vector2) -> bool:
	return graph.drivable(at, front) and _blocker(tank, at, front) == null


## Room to swing the hull round to `to` standing at `at`, every pivot_deg of the way: a pivot
## starts only when it can finish.
func _sweep_fits(tank: RampageSim.Tank, at: Vector2, to: Vector2) -> bool:
	var r: ConvoyRoute = routes[tank.id]
	var turn := r.front.angle_to(to)
	var steps := ceili(absf(turn) / deg_to_rad(Num.f(cfg["pivot_deg"])))
	for k: int in range(1, steps + 1):
		if not _fits(tank, at, r.front.rotated(turn * k / steps)):
			return false
	return true


## At its post a tank squares its hull to its road (the nearer way; parked at a crossing, the
## road its hull lies nearer); only its turret turns. When that swing has no room (a tank
## pulled up beside it mid-pivot), it squares to the nearest road axis at the crossing that
## has, so it never waits half turned.
func _settle(tank: RampageSim.Tank, r: ConvoyRoute, rate: float) -> void:
	if r.edge < 0 or r.front == Vector2.ZERO:
		return
	var first: Array[Vector2] = []  # the roads it means to lie along
	var then: Array[Vector2] = []  # any other road under it at a crossing
	for e: int in graph.roads_at(graph.cell_of(tank.pos)) + PackedInt32Array([r.edge]):
		var under := graph.on_edge(tank.pos, e)
		var mine := e == r.edge or r.path.is_empty() and under
		if mine or under:
			var list := first if mine else then
			list.append(graph.axis(e) * (1.0 if graph.axis(e).dot(r.front) >= 0.0 else -1.0))
	var nearer := func(x: Vector2, y: Vector2) -> bool: return x.dot(r.front) > y.dot(r.front)
	first.sort_custom(nearer)
	then.sort_custom(nearer)
	for want: Vector2 in first + then:
		if absf(r.front.angle_to(want)) < 0.0001:
			return  # squared already
		var front := r.front.rotated(clampf(r.front.angle_to(want), -rate, rate))
		if _fits(tank, tank.pos, front):
			r.front = front
			return


## Held up too long: re-plan off this road, and round the roads under the tank in its way.
func _held_up(tank: RampageSim.Tank, r: ConvoyRoute, blocker: RampageSim.Tank) -> void:
	if not r.edges.is_empty() and r.edges[0] >= 0:
		r.skip[r.edges[0]] = true
	if blocker != tank:
		for e: int in graph.roads_at(graph.cell_of(blocker.pos)):
			if e != r.edge and graph.on_edge(blocker.pos, e):
				r.skip[e] = true
	_plan(tank, r, r.retreating)


func _blocker(tank: RampageSim.Tank, next: Vector2, dir: Vector2) -> RampageSim.Tank:
	return spacing.blocker(tank, next, dir)


## Toppled towers close their roads: a tank routed through one drops it and re-plans.
func _read_rubble() -> void:
	if not graph.read_rubble(sim.events):
		return
	for tank: RampageSim.Tank in sim.tanks:
		var r: ConvoyRoute = routes.get(tank.id)
		if r != null and r.edges.any(func(e: int) -> bool: return e >= 0 and graph.blocked[e] != 0):
			r.path.clear()  # never on through the rubble, even with no way round yet
			r.edges.clear()
			_plan(tank, r, r.retreating)
