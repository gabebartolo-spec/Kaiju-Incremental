extends RefCounted
## The tanks' convoy with a stopwatch (tools/sim_timed.gd's TArmy swaps it in): TConvoy times the
## convoy's step; TConvoyDeep (--drill) also times its helpers and the road graph, search, posts and
## spacing it owns, each swapped for a timed copy built the same way. Same rules as sim_timed.gd:
## every method wraps `super` and changes nothing else.

const Prof := preload("res://tools/sim_prof.gd")


class TConvoy:
	extends Convoy

	func step(dt: float) -> void:
		Prof.begin("convoy.step")
		super.step(dt)
		Prof.end()


## The convoy's insides (--drill): its own helpers, and the road graph, search, posts and spacing it
## owns, each swapped for a timed copy built the same way.
class TConvoyDeep:
	extends TConvoy

	func _init(p_sim: RampageSim, p_cfg: Dictionary) -> void:
		super(p_sim, p_cfg)
		graph = TGraph.new(sim, cfg)
		search = TSearch.new(graph, cfg)
		posts = TPosts.new(self)
		spacing = TSpacing.new(self)

	func _read_rubble() -> void:
		Prof.begin("convoy.read_rubble")
		super._read_rubble()
		Prof.end()

	func _refresh_costs(near: float) -> void:
		Prof.begin("convoy.refresh_costs")
		super._refresh_costs(near)
		Prof.end()

	func _plan(tank: RampageSim.Tank, r: ConvoyRoute, urgent: bool) -> void:
		Prof.begin("convoy.plan")
		super._plan(tank, r, urgent)
		Prof.end()

	func _drive(tank: RampageSim.Tank, r: ConvoyRoute, dt: float) -> void:
		Prof.begin("convoy.drive")
		super._drive(tank, r, dt)
		Prof.end()

	func _goal_good(r: ConvoyRoute) -> bool:
		Prof.begin("convoy.goal_good")
		var good := super._goal_good(r)
		Prof.end()
		return good

	func _covering(tank: RampageSim.Tank, r: ConvoyRoute) -> bool:
		Prof.begin("convoy.covering")
		var covered := super._covering(tank, r)
		Prof.end()
		return covered

	func _sweep_fits(tank: RampageSim.Tank, at: Vector2, to: Vector2) -> bool:
		Prof.begin("convoy.sweep_fits")
		var fits := super._sweep_fits(tank, at, to)
		Prof.end()
		return fits

	func _settle(tank: RampageSim.Tank, r: ConvoyRoute, rate: float) -> void:
		Prof.begin("convoy.settle")
		super._settle(tank, r, rate)
		Prof.end()


class TGraph:
	extends RoadGraph

	func drivable(p: Vector2, front: Vector2) -> bool:
		Prof.begin("graph.drivable")
		var ok := super.drivable(p, front)
		Prof.end()
		return ok

	func road_under(p: Vector2, edge: int) -> int:
		Prof.begin("graph.road_under")
		var e := super.road_under(p, edge)
		Prof.end()
		return e

	func waypoints(from: Vector2, start: Dictionary, chain: Array[int], goal: Dictionary) -> Array:
		Prof.begin("graph.waypoints")
		var way := super.waypoints(from, start, chain, goal)
		Prof.end()
		return way

	func read_rubble(events: Array[Dictionary]) -> bool:
		Prof.begin("graph.read_rubble")
		var closed := super.read_rubble(events)
		Prof.end()
		return closed


class TSearch:
	extends RoadSearch

	func search(start: Dictionary, skip: Dictionary, centre: Vector2, disc: float) -> Dictionary:
		Prof.begin("search.search")
		var found := super.search(start, skip, centre, disc)
		Prof.end()
		return found


class TPosts:
	extends FiringPosts

	func body() -> PackedVector2Array:
		Prof.begin("posts.body")
		var at := super.body()
		Prof.end()
		return at

	func near_body(a: Vector2, b: Vector2) -> float:
		Prof.begin("posts.near_body")
		var d := super.near_body(a, b)
		Prof.end()
		return d

	func to_body(p: Vector2) -> float:
		Prof.begin("posts.to_body")
		var d := super.to_body(p)
		Prof.end()
		return d

	func roads_by_body(near: float) -> Dictionary:
		Prof.begin("posts.roads_by_body")
		var roads := super.roads_by_body(near)
		Prof.end()
		return roads

	func clear_line(from: Vector2, to: Vector2) -> bool:
		Prof.begin("posts.clear_line")
		var clear := super.clear_line(from, to)
		Prof.end()
		return clear

	func choose(
		tank: RampageSim.Tank, r: ConvoyRoute, found: Dictionary, urgent: bool
	) -> Dictionary:
		Prof.begin("posts.choose")
		var post := super.choose(tank, r, found, urgent)
		Prof.end()
		return post


class TSpacing:
	extends TankSpacing

	func blocker(tank: RampageSim.Tank, next: Vector2, dir: Vector2) -> RampageSim.Tank:
		Prof.begin("spacing.blocker")
		var other := super.blocker(tank, next, dir)
		Prof.end()
		return other

	func open_up(tank: RampageSim.Tank, r: ConvoyRoute, step: float) -> void:
		Prof.begin("spacing.open_up")
		super.open_up(tank, r, step)
		Prof.end()
