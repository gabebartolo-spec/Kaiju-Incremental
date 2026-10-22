extends RefCounted
## An all-junction cell gets a traffic island (TrafficIsland; lead 10, 2026-10-21): in three
## Behemoth cities whose plan leaves a no-empty-ground cell that is all road junction (a street,
## an avenue and the diagonal meet; no parked car fits), the island fills it, so the
## no-empty-ground measure finds no bare cell; with the islands off the same cities have one.
## Every island keeps clear of every lane Traffic drives (its footprint plus a car's half width
## off each lane line, both sides) and of every parked car.

const Coverage := preload("res://tests/lib/city_coverage.gd")
const SEEDS: Array[int] = [40, 55, 60]
const TIER := 2
const Rings := preload("res://tests/lib/fixture_rings.gd")

var _check: Callable
var _root: Node


func _init(check_fn: Callable, root: Node) -> void:
	_check = check_fn
	_root = root


func run() -> void:
	RiverQuay.enabled = false  # the riverside crates would fill some of these cells too
	for map_seed: int in SEEDS:
		TrafficIsland.enabled = false
		var without: Dictionary = _city(map_seed)
		TrafficIsland.enabled = true
		var with_island: Dictionary = _city(map_seed)
		var bare_without: Array = without["empty"]
		var bare_with: Array = with_island["empty"]
		var islands: Array = with_island["islands"]
		_check.call(
			bare_without.size() > 0 and bare_with.is_empty() and islands.size() > 0,
			(
				(
					"stage %d, map_seed %d: a traffic island fills the all-junction cell (%d bare"
					+ " without at %s; %d with, islands at %s)"
				)
				% [TIER, map_seed, bare_without.size(), bare_without, bare_with.size(), islands]
			)
		)
		_check.call(
			Num.f(with_island["lane_gap"]) >= 0.0 and Num.i(with_island["on_cars"]) == 0,
			(
				(
					"stage %d, map_seed %d: no island blocks a lane (closest %.2f clear of a car"
					+ " in its lane) or stands on a parked car (%d do)"
				)
				% [TIER, map_seed, Num.f(with_island["lane_gap"]), Num.i(with_island["on_cars"])]
			)
		)
	TrafficIsland.enabled = true
	RiverQuay.enabled = true


## The bare cells, the island centres, how far the nearest island footprint keeps from a car
## driving any lane (negative: they touch) and how many islands overlap a car.
func _city(map_seed: int) -> Dictionary:
	var base: Dictionary = Content.tuning().duplicate(true)
	base["city"]["map_seed"] = map_seed
	Rings.apply(base)
	var sim := RampageSim.new(
		UpgradeTree.run_stats(
			Content.section("kaiju"),
			Content.species_def("reptilian"),
			UpgradeTree.new(Content.upgrades())
		),
		CityGrowth.tuning_for(base, TIER),
		CityGrowth.layout(base, TIER, Seeds.make("city", 0)),
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
	var ground := CityGround.new(sim.city)
	holder.add_child(ground)
	var skyline := CitySkyline.new(ground, Seeds.make("skyline", 0))
	holder.add_child(skyline)
	var got: Dictionary = Coverage.measure(sim, decor, street, skyline)
	var islands := decor.islands
	var cells := Num.i(sim.city["traffic_island"]["half_cells"]) * 2 + 1
	var foot := cells * CityDecor.PROP_VOXEL * 0.5 * sqrt(2.0)  # the slab's corner, any facing
	var traffic := street.traffic
	var lane_gap := INF
	var on_cars := 0
	for at: Vector2 in islands:
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
	return {"empty": got["empty"], "islands": islands, "lane_gap": lane_gap, "on_cars": on_cars}
