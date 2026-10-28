extends RefCounted
## Traffic islands where the diagonal meets avenues (TrafficIsland; director 2026-10-26: "Where
## the diagonal meets avenues", after the city audit, D-265, found none in any seed): on the
## shipped plan's seeds at the first and last stage every city gets at least one island, each
## within wedge_reach of a crossing of the diagonal with an avenue; no island blocks a lane
## (its footprint plus a car's half width off each lane line) or stands on a parked car. With the
## rule off (city.traffic_island.at "") the same cities get none, so the rule is what plants them.

const SEEDS: Array[int] = [7301, 1234, 98765]
const TIERS: Array[int] = [1, 3]

var _check: Callable
var _root: Node


func _init(check_fn: Callable, root: Node) -> void:
	_check = check_fn
	_root = root


func run() -> void:
	for tier: int in TIERS:
		for map_seed: int in SEEDS:
			var got := _city(tier, map_seed, "diagonal_avenue")
			var islands: Array = got["islands"]
			(
				_check
				. call(
					islands.size() >= 1 and Num.i(got["off_crossing"]) == 0,
					(
						(
							"stage %d, map_seed %d: islands where the diagonal meets avenues (%d at %s, %d"
							+ " away from such a crossing)"
						)
						% [tier, map_seed, islands.size(), islands, Num.i(got["off_crossing"])]
					)
				)
			)
			(
				_check
				. call(
					Num.f(got["lane_gap"]) >= 0.0 and Num.i(got["on_cars"]) == 0,
					(
						(
							"stage %d, map_seed %d: no island blocks a lane (closest %.2f clear of a car"
							+ " in its lane) or stands on a parked car (%d do)"
						)
						% [tier, map_seed, Num.f(got["lane_gap"]), Num.i(got["on_cars"])]
					)
				)
			)
	var off := _city(1, SEEDS[0], "")
	var none: Array = off["islands"]
	_check.call(none.is_empty(), "with the rule off no island is planted (%d)" % none.size())


## The island centres, how many lie beyond wedge_reach of every diagonal x avenue crossing, how
## far the nearest island footprint keeps from a car driving any lane (negative: they touch) and
## how many islands overlap a parked car.
func _city(tier: int, map_seed: int, rule: String) -> Dictionary:
	var base: Dictionary = Content.tuning().duplicate(true)
	base["city"]["map_seed"] = map_seed
	base["city"]["traffic_island"]["at"] = rule
	var sim := RampageSim.new(
		UpgradeTree.run_stats(
			Content.section("kaiju"),
			Content.species_def("reptilian"),
			UpgradeTree.new(Content.upgrades())
		),
		CityGrowth.tuning_for(base, tier),
		CityGrowth.layout(base, tier, Seeds.make("city", 0)),
		Seeds.make("army", 0)
	)
	var holder := Node3D.new()
	_root.add_child(holder)
	var decor := CityDecor.new(sim, Seeds.make("decor", 0))
	holder.add_child(decor)
	var fx := Fx.new()
	holder.add_child(fx)
	var street := StreetLife.new(sim, fx, Seeds.make("civilians", 0))
	holder.add_child(street)
	var islands := decor.islands
	var cfg: Dictionary = sim.city["traffic_island"]
	var cells := Num.i(cfg["half_cells"]) * 2 + 1
	var foot := cells * CityDecor.PROP_VOXEL * 0.5 * sqrt(2.0)  # the slab's corner, any facing
	var traffic := street.traffic
	var lane_gap := INF
	var on_cars := 0
	var off_crossing := 0
	for at: Vector2 in islands:
		if not _by_crossing(decor.plan, at, Num.f(cfg["wedge_reach"])):
			off_crossing += 1
		for a: int in traffic._lanes.size():
			for lane: Dictionary in traffic._lanes[a]:
				var from := traffic._nodes[a]
				var to := traffic._nodes[Num.i(lane["to"])]
				var side := (to - from).normalized().orthogonal() * Num.f(lane["lane"])
				for s: float in [-1.0, 1.0]:
					var q := Geometry2D.get_closest_point_to_segment(
						at, from + side * s, to + side * s
					)
					lane_gap = minf(lane_gap, q.distance_to(at) - foot - CityDecor.CAR_HALF.x)
		var box := Rect2(at - Vector2.ONE * foot, Vector2.ONE * foot * 2.0)
		for car: Traffic.Car in traffic.cars:
			if car.parked and box.has_point(car.pos):
				on_cars += 1
	holder.free()
	return {
		"islands": islands, "lane_gap": lane_gap, "on_cars": on_cars, "off_crossing": off_crossing
	}


## Whether `at` lies within `reach` of a crossing where the diagonal and an avenue meet.
static func _by_crossing(plan: Dictionary, at: Vector2, reach: float) -> bool:
	var nodes: Array[Vector2] = plan["nodes"]
	var kinds := {}  # node -> {kind: true}
	for s: Dictionary in plan["streets"]:
		for end: String in ["from", "to"]:
			var n := Num.i(s[end])
			if not kinds.has(n):
				kinds[n] = {}
			var seen: Dictionary = kinds[n]
			seen[str(s["kind"])] = true
	for n: int in kinds:
		var seen: Dictionary = kinds[n]
		if seen.has(CityGen.DIAGONAL) and seen.has(CityGen.AVENUE):
			if nodes[n].distance_to(at) <= reach:
				return true
	return false
