class_name Convoy
extends RefCounted
## How the tanks move (D-066): like an army, not a swarm. They enter by road from the city's
## edge and drive the street plan (RoadGraph: never an alley, a lot or a building) in columns
## that keep their gap. Each takes a firing post on a road at standoff range with a clear line
## of fire, spread round the kaiju on an arc (FiringPosts), holds it while it is good, bounds to
## a new one when the kaiju moves (one tank of a column at a time, the other covering), backs
## off when the kaiju closes inside the danger radius, re-routes round a tank in its way or a
## toppled tower across its road, and gives way to an older tank. Pure and seeded; Army owns
## spawning, firing and damage and calls in here. Numbers: army.convoy in data/tuning.json.


## A tank's route and drive state: one per tank (by id) in `routes`.
class Route:
	var path: Array[Vector2] = []  # waypoints still to drive, the post last
	var edges: Array[int] = []  # the road each leg runs along (-1: off the plan)
	var goal := Vector2(INF, INF)
	var reserve := false  # its post is a reserve post, out of range
	var edge := -1  # the road it is on now
	var column := -1
	var replan_t := 0.0
	var stuck_t := 0.0
	var skip: Dictionary = {}  # roads it was held up on: left out of its next plan
	var retreating := false
	var give_to := -1  # an older tank it is backing up for
	var yield_t := 0.0
	var yield_all := 0.0  # how long it has been giving way this time
	var heading := Vector2.ZERO  # the way it last drove
	var reversing := false  # backing off with its front still to the kaiju


var sim: RampageSim
var cfg: Dictionary
var graph: RoadGraph
var search: RoadSearch
var posts: FiringPosts
var routes: Dictionary = {}  # tank id -> Route
var _plans_left := 0


func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
	sim = p_sim
	cfg = p_cfg
	graph = RoadGraph.new(sim, cfg)
	search = RoadSearch.new(graph, cfg)
	posts = FiringPosts.new(self)


## Full reach and the danger radius for the kaiju as it is now.
func reach() -> float:
	return Num.f(sim.army["range"]) + sim.stomp_radius()


func danger() -> float:
	return reach() * Num.f(cfg["danger"])


## Is the line of fire from `from` to `to` clear (FiringPosts.clear_line)?
func clear_line(from: Vector2, to: Vector2) -> bool:
	return posts.clear_line(from, to)


## Is tank `id` backing off with its front to the kaiju (presentation keeps its hull so)?
func reversing(id: int) -> bool:
	var r: Route = routes.get(id)
	return r != null and r.reversing


## Where a new tank enters at `node` (pick_entry): records its route and returns where it
## starts, or INF when that way in is still taken by the tank before it.
func enter(id: int, column: int, node: int) -> Vector2:
	if node < 0 or graph.links[node].is_empty():
		return Vector2(INF, INF)
	for tank: RampageSim.Tank in sim.tanks:
		if tank.pos.distance_to(graph.nodes[node]) < Num.f(cfg["follow"]):
			return Vector2(INF, INF)
	var r := Route.new()
	r.column = column
	r.edge = graph.links[node][0]
	var e := r.edge
	var far := graph.edge_b[e] if graph.edge_a[e] == node else graph.edge_a[e]
	r.heading = (graph.nodes[far] - graph.nodes[node]).normalized()  # facing into its road
	routes[id] = r
	return graph.nodes[node]


## The way in for a column on `bearing`: the road entry at the city's edge on that side, or, in
## a city grown past the spawn radius, the road crossing nearest spawn_radius from the kaiju
## (D-039).
func pick_entry(bearing: float) -> int:
	var dir := Vector2.from_angle(bearing)
	var spawn_radius := Num.f(sim.army["spawn_radius"])
	var edge := graph.box <= spawn_radius
	var aim := dir * graph.box * 2.0 if edge else sim.kaiju_pos + dir * spawn_radius
	var pool: Array[int] = []
	pool.assign(graph.entries if edge else PackedInt32Array(range(graph.nodes.size())))
	var best := -1
	var best_d := INF
	for n: int in pool:
		var d := graph.nodes[n].distance_squared_to(aim)
		if d < best_d and not graph.links[n].is_empty():
			best_d = d
			best = n
	return best


## One step for every tank: read what fell across the roads, re-plan where needed (at most
## plans_per_step, the urgent ones always), then drive.
func step(dt: float) -> void:
	_read_rubble()
	var near := danger()
	_refresh_costs(near)
	_plans_left = Num.i(cfg["plans_per_step"])
	for tank: RampageSim.Tank in sim.tanks:
		var r: Route = routes.get(tank.id)
		if r == null:
			r = Route.new()
			routes[tank.id] = r
		r.replan_t -= dt
		var urgent := tank.pos.distance_to(sim.kaiju_pos) < near
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
	search.near_kaiju = {}
	for e: int in graph.edges_within(sim.kaiju_pos, near):
		if graph.off_line(sim.kaiju_pos, e) < near:
			search.near_kaiju[e] = true
	search.held = {}
	search.driven = {}
	for tank: RampageSim.Tank in sim.tanks:
		var o: Route = routes.get(tank.id)
		if o == null:
			continue
		if o.path.is_empty() and o.edge >= 0:
			search.held[o.edge] = true
		var from := tank.pos
		for i: int in o.path.size():
			if o.edges[i] >= 0:
				search.driven[o.edges[i]] = o.path[i] - from
			from = o.path[i]


## A post is good while it is in the band between danger and full reach with a clear shot.
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
		var o: Route = routes.get(other.id)
		if other.id != tank.id and o != null and o.column == r.column and not o.path.is_empty():
			r.replan_t = Num.f(cfg["replan"]) * 0.25
			return true
	return false


## Picks a post (FiringPosts) and the road route to it; urgent: the kaiju is on top of it.
func _plan(tank: RampageSim.Tank, r: Route, urgent: bool) -> void:
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
	var legs: Array = way[1]
	r.path.assign(points)
	r.edges.assign(legs)
	r.goal = goal["at"]
	r.reserve = goal.get("reserve", false)
	r.retreating = urgent and not r.path.is_empty()


## Where a tank sets off from: {edge (the road under it), via (its point on that road's line),
## from: {node: cost}}, both ends of that road, or only the end behind it when it was held up
## on this road going the other way.
func _start(tank: RampageSim.Tank, r: Route) -> Dictionary:
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
	return {"edge": e, "via": via, "from": from}


## Drives along the route at speed (reversing slower, front still to the kaiju, when it backs
## off), its hull never off the carriageway or overlapping another's, holding `follow` behind
## one ahead of it in its lane; held up `stuck` seconds, it re-plans round what held it.
func _drive(tank: RampageSim.Tank, r: Route, dt: float) -> void:
	r.reversing = false
	var back := Num.f(sim.army["speed"]) * Num.f(cfg["reverse"]) * dt
	if r.yield_t > 0.0:
		_yielding(tank, r, dt, back)
		return
	r.yield_all = 0.0
	if r.path.is_empty():
		return
	var to := r.path[0] - tank.pos
	var dist := to.length()
	var dir := to / dist if dist > 0.0001 else Vector2.ZERO
	var speed := Num.f(sim.army["speed"])
	if r.retreating and dir.dot(sim.kaiju_pos - tank.pos) < 0.0:
		r.reversing = true
		speed *= Num.f(cfg["reverse"])
	var move := minf(dist, speed * dt)
	var next := tank.pos + dir * move
	var blocker := _blocker(tank, next, dir)
	if blocker == null and not graph.drivable(next) and graph.drivable(tank.pos):
		blocker = tank  # the move would put its hull off the road: held up all the same
	if blocker != null:
		r.stuck_t += dt
		_give_way(tank, blocker, back)
		if r.stuck_t >= Num.f(cfg["stuck"]):
			_held_up(tank, r, blocker)
		return
	r.stuck_t = 0.0
	r.heading = dir
	tank.pos = next
	if not r.edges.is_empty() and r.edges[0] >= 0:
		r.edge = r.edges[0]
	if move >= dist - 0.0001:
		r.path.remove_at(0)
		r.edges.remove_at(0)
		r.retreating = r.retreating and not r.path.is_empty()


## Held up too long: re-plan off this road, and round the roads under the tank in its way.
func _held_up(tank: RampageSim.Tank, r: Route, blocker: RampageSim.Tank) -> void:
	if not r.edges.is_empty() and r.edges[0] >= 0:
		r.skip[r.edges[0]] = true
	if blocker != tank:
		for e: int in graph.roads_at(graph.cell_of(blocker.pos)):
			if e != r.edge and graph.on_edge(blocker.pos, e):
				r.skip[e] = true
	_plan(tank, r, r.retreating)


## Giving way: back up while the older tank is still held up (a while longer if it still is,
## up to 3 x stuck), then wait.
func _yielding(tank: RampageSim.Tank, r: Route, dt: float, back: float) -> void:
	r.yield_t -= dt
	for older: RampageSim.Tank in sim.tanks:
		if older.id != r.give_to:
			continue
		_back_off(tank, older, back)
		var o: Route = routes.get(older.id)
		var held := o != null and o.stuck_t > 0.0
		if held and r.yield_t <= 0.0 and r.yield_all < Num.f(cfg["stuck"]) * 3.0:
			r.yield_t = dt
		r.yield_all += dt


## Right of way: blocked by an older tank that is itself held up trying to move, the younger
## one gives way for `stuck` seconds.
func _give_way(tank: RampageSim.Tank, blocker: RampageSim.Tank, back: float) -> void:
	var o: Route = routes.get(blocker.id)
	if blocker.id >= tank.id or o == null or o.path.is_empty() or o.stuck_t <= 0.0:
		return
	var r: Route = routes[tank.id]
	r.give_to = blocker.id
	r.yield_t = Num.f(cfg["stuck"])
	_back_off(tank, blocker, back)


## Straight back along its hull, away from the older tank, only while the hull stays on the road.
func _back_off(tank: RampageSim.Tank, older: RampageSim.Tank, step: float) -> void:
	var o: Route = routes.get(older.id)
	var r: Route = routes[tank.id]
	if o == null or o.stuck_t <= 0.0:
		return
	var own := r.heading if r.heading != Vector2.ZERO else (tank.pos - older.pos).normalized()
	var back := own if own.dot(tank.pos - older.pos) > 0.0 else -own
	var to := tank.pos + back * step
	if graph.drivable(to) and _blocker(tank, to, own) == null:
		tank.pos = to
		r.reversing = back.dot(own) < 0.0


## The tank in the way of a move to `next` heading `dir`, or null: never into a new hull
## overlap (out of one only by opening up), never closer than `follow` behind one going its way
## in its lane.
func _blocker(tank: RampageSim.Tank, next: Vector2, dir: Vector2) -> RampageSim.Tank:
	var hull: Array = cfg["hull"]
	var clear := Num.f(cfg["clear"])
	var half := Vector2(Num.f(hull[0]), Num.f(hull[1])) * 0.5 + Vector2(clear, clear)
	var follow := Num.f(cfg["follow"])
	var mine: Route = routes[tank.id]
	var own := mine.heading if mine.heading != Vector2.ZERO else dir
	for other: RampageSim.Tank in sim.tanks:
		var then := next.distance_to(other.pos)
		if other.id == tank.id or then > follow + half.x:
			continue
		var now := tank.pos.distance_to(other.pos)
		var o: Route = routes.get(other.id)
		var facing := o.heading if o != null and o.heading != Vector2.ZERO else dir
		if hulls_overlap(next, dir, other.pos, facing, half):
			if then <= now or not hulls_overlap(tank.pos, own, other.pos, facing, half):
				return other
		var ahead := other.pos - tank.pos
		var lane := dir.dot(ahead) > 0.0 and absf(dir.cross(ahead)) < half.y * 2.0
		if then < now and lane and then < follow and facing.dot(dir) > 0.7:
			return other
	return null


## Do two hulls (centres, headings, half length and half width) overlap? Separating axes.
static func hulls_overlap(p: Vector2, u: Vector2, q: Vector2, w: Vector2, half: Vector2) -> bool:
	var d := q - p
	for axis: Vector2 in [u, u.orthogonal(), w, w.orthogonal()] as Array[Vector2]:
		var ra := half.x * absf(u.dot(axis)) + half.y * absf(u.orthogonal().dot(axis))
		var rb := half.x * absf(w.dot(axis)) + half.y * absf(w.orthogonal().dot(axis))
		if absf(d.dot(axis)) > ra + rb:
			return false
	return true


## A tower that toppled across a road closes it for the rest of the rampage: tanks on a route
## through it re-plan at once.
func _read_rubble() -> void:
	var closed := false
	for event: Dictionary in sim.events:
		if str(event["type"]) != "fall_land" or str(event.get("kind", "")) != "topple":
			continue
		var from: Vector2 = event["from"]
		var to: Vector2 = event["to"]
		closed = graph.close_strip(from, to, Num.f(event["width"])) or closed
	if not closed:
		return
	for tank: RampageSim.Tank in sim.tanks:
		var r: Route = routes.get(tank.id)
		if r != null and r.edges.any(func(e: int) -> bool: return e >= 0 and graph.blocked[e] != 0):
			_plan(tank, r, r.retreating)
