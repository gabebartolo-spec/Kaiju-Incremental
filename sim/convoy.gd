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
var hull: ConvoyHull
var routes: Dictionary = {}  # tank id -> ConvoyRoute
var kaiju_vel := Vector2.ZERO  # how the kaiju walks (m/s), from its last step
var _kaiju_was := Vector2(INF, INF)
var _plans_left := 0


## One tank's next stretch for a step (Convoy._aim): the way, the distance to the waypoint, the way
## its hull goes (backwards when reversing), the hull's front and the step it takes.
class Leg:
	var dir := Vector2.ZERO
	var dist := 0.0
	var want := Vector2.ZERO
	var front := Vector2.ZERO
	var move := 0.0
	var next := Vector2.ZERO


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg
	graph = RoadGraph.new(sim, cfg)
	search = RoadSearch.new(graph, cfg)
	posts = FiringPosts.new(self)
	spacing = TankSpacing.new(self)
	hull = ConvoyHull.new(self)


## Full reach for the kaiju as it is now, measured from its body line (FiringPosts.aim_point),
## never so short that the firing band ends inside the keep-away (band_depth past it).
func reach() -> float:
	var band: Array = cfg["band"]
	var least := (posts.keep_away() + Num.f(cfg["band_depth"])) / Num.f(band[1])
	return maxf(Num.f(sim.army["range"]) + sim.stomp_radius(), least)


## The danger radius, from the body line: the keep-away (FiringPosts.keep_away), or the danger
## share of reach when that is further.
func danger() -> float:
	return maxf(reach() * Num.f(cfg["danger"]), posts.keep_away())


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
		_tend(tank, near, dt)
	for id: int in routes.keys():
		if not sim.tanks.any(func(t: RampageSim.Tank) -> bool: return t.id == id):
			routes.erase(id)


## One tank's step: its route, a re-plan where its post has gone bad or the kaiju is on top of it,
## then the drive.
func _tend(tank: RampageSim.Tank, near: float, dt: float) -> void:
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
		_review(tank, r, urgent)
	_drive(tank, r, dt)


## Time to look at the post again: re-plan when it is no good and nothing covers it.
func _review(tank: RampageSim.Tank, r: ConvoyRoute, urgent: bool) -> void:
	r.replan_t = Num.f(cfg["replan"])
	if not _goal_good(r) and (urgent or not _covering(tank, r)):
		_plans_left -= 1
		_plan(tank, r, urgent)


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
	var start := search.origin(tank.pos, r)
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


## Drives along the route at speed (reversing slower, front still to the kaiju, when it backs
## off), hull on the carriageway and clear of others, `follow` behind one ahead in its lane. It
## drives only along its hull: a turn it makes standing at hull_turn first (shuffling a hull's
## step forward or back where the turn will not fit). Held up `stuck` seconds, it re-plans
## round what held it.
func _drive(tank: RampageSim.Tank, r: ConvoyRoute, dt: float) -> void:
	r.reversing = false
	if r.yield_t > 0.0:
		spacing.yielding(tank, r, dt, _back(dt))
		hull.settle(tank, r, _rate(dt))  # giving way mid-pivot: it waits squared to its road
		return
	if r.yield_all > 0.0:  # backed off its path: set off again from where it stands
		r.yield_all = 0.0
		_plan(tank, r, r.retreating)
	if r.path.is_empty():
		hull.settle(tank, r, _rate(dt))
		spacing.open_up(tank, r, _back(dt))  # the kaiju moved and a gun swung over a neighbour
		return
	var leg := _aim(tank, r, dt)
	if leg != null:
		_take(tank, r, leg, dt)


## How far a tank backs in a step, and how far its hull turns.
func _back(dt: float) -> float:
	return Num.f(sim.army["speed"]) * Num.f(cfg["reverse"]) * dt


func _rate(dt: float) -> float:
	return deg_to_rad(Num.f(cfg["hull_turn"])) * dt


## The next stretch of the route as this step would drive it, or null when the tank arrives at the
## waypoint or brakes short of the standoff line instead (nothing more to do this step).
func _aim(tank: RampageSim.Tank, r: ConvoyRoute, dt: float) -> Leg:
	var rate := _rate(dt)
	r.path[0] = graph.square_leg(tank.pos, r.path[0], r.edges[0])  # never down a diagonal
	r.path[0] = hull.onto_axis(tank.pos, r.path[0], r.edge)  # nor crabbing where it could not square
	var leg := Leg.new()
	var to := r.path[0] - tank.pos
	leg.dist = to.length()
	leg.dir = to / leg.dist if leg.dist > 0.0001 else r.front
	var speed := _speed(tank, r, leg.dir)
	leg.want = -leg.dir if r.reversing else leg.dir
	r.front = leg.want if r.front == Vector2.ZERO else r.front
	var turn := r.front.angle_to(leg.want)
	if leg.dist <= 1.0 and absf(turn) > rate:  # the last metre is not worth a turn: it is there
		_arrive(r)
		return null
	leg.front = r.front.rotated(clampf(turn, -rate, rate))
	leg.move = 0.0 if absf(turn) > rate else minf(leg.dist, speed * dt)  # squared first, then on
	leg.next = tank.pos + leg.dir * leg.move
	if not r.retreating and leg.move > 0.0 and posts.to_body(leg.next) < danger():
		r.path.clear()  # brake short of the standoff line: never across it
		r.edges.clear()
		return null
	return leg


## The speed along `dir`: backing up rather than turning about in the road (setting r.reversing),
## and out fast, then slow, when it is backing off the kaiju's body.
func _speed(tank: RampageSim.Tank, r: ConvoyRoute, dir: Vector2) -> float:
	var speed := Num.f(sim.army["speed"])
	var behind := r.front.dot(dir) < (0.0 if r.retreating else -0.5)  # back off, never turn tail
	var clear_of := r.retreating and posts.to_body(tank.pos) < danger()  # out fast, then slow
	if behind and r.front != Vector2.ZERO:  # and back up rather than turn about in the road
		r.reversing = true
		return Num.f(cfg["retreat_speed"]) if clear_of else speed * Num.f(cfg["reverse"])
	return maxf(speed, Num.f(cfg["retreat_speed"])) if clear_of else speed


## Takes the leg when the hull fits there, shuffles to make room to turn, or waits held up.
func _take(tank: RampageSim.Tank, r: ConvoyRoute, leg: Leg, dt: float) -> void:
	var blocker := spacing.blocker(tank, leg.next, leg.front)
	var fits := (
		graph.drivable(leg.next, leg.front)
		and (leg.move > 0.0 or hull.sweep_fits(tank, tank.pos, leg.want))
	)
	if blocker == null and not fits and graph.drivable(tank.pos, r.front):
		if leg.move == 0.0 and hull.shuffle(tank, r, leg.want, _back(dt)):
			return
		blocker = tank  # the hull would leave the road, or the turn has no room: held up
	if blocker != null:
		_wait(tank, r, blocker, dt)
	else:
		_commit(tank, r, leg)


## The hull fits: it drives the leg, and arrives at the waypoint when it reaches it.
func _commit(tank: RampageSim.Tank, r: ConvoyRoute, leg: Leg) -> void:
	r.stuck_t = 0.0
	r.heading = leg.dir
	r.front = leg.front
	tank.pos = leg.next
	if not r.edges.is_empty() and r.edges[0] >= 0:
		r.edge = r.edges[0]
	if leg.move > 0.0 and leg.move >= leg.dist - 0.0001 or leg.dist <= 0.0001:
		_arrive(r)


## Held up, or no room to turn: it waits squared to its road, gives way, and re-plans when stuck.
func _wait(tank: RampageSim.Tank, r: ConvoyRoute, blocker: RampageSim.Tank, dt: float) -> void:
	hull.settle(tank, r, _rate(dt))
	r.stuck_t += dt
	spacing.give_way(tank, blocker, _back(dt))
	if r.stuck_t >= Num.f(cfg["stuck"]) * (0.5 if r.retreating else 1.0):  # falling back: sooner
		_held_up(tank, r, blocker)


## At its next waypoint: on to the one after.
func _arrive(r: ConvoyRoute) -> void:
	r.path.remove_at(0)
	r.edges.remove_at(0)
	r.retreating = r.retreating and not r.path.is_empty()


## Held up too long: re-plan off this road, and round the roads under the tank in its way.
func _held_up(tank: RampageSim.Tank, r: ConvoyRoute, blocker: RampageSim.Tank) -> void:
	if not r.edges.is_empty() and r.edges[0] >= 0:
		r.skip[r.edges[0]] = true
	if blocker != tank:
		for e: int in graph.roads_at(graph.cell_of(blocker.pos)):
			if e != r.edge and graph.on_edge(blocker.pos, e):
				r.skip[e] = true
	_plan(tank, r, r.retreating)


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
