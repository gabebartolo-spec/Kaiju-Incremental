extends "res://tests/lib/runner.gd"
## Roads suite (director 2026-10-26: "we need a system to ensure that roads are intersecting with
## other roads and pavements in a natural, realistic way"; "I also saw some weird spots where two
## roads met, like a seam between them rather than a seamless join"). Over every road the stage
## draws as the real city (CityBand) at each city stage (young, Behemoth, Colossus) in 20 cities
## (city.map_seed), one test function per rule, each check naming every violation's kind and
## world coordinates (x, z in metres): tests/lib/road_net.gd (R1-R3 on the road graph) and
## tests/lib/road_edges.gd (R3-R6 along every road edge and centre line, read off the ground as
## CityGround draws it, tests/lib/road_ground.gd).
##   R1 every road end meets a road, a junction, a bridge deck or the plan's edge
##   R2 a bridge deck lands on a road of its width and axis at both ends (#12)
##   R3 clean T or X junctions with matching widths, no jagged step in the asphalt edge
##   R4 a kerbed pavement lines both sides of every road (bridges and quays excepted)
##   R5 lane paint stops at junction edges; zebras only at the central junction (D-054)
##   R6 two road pieces that meet make one surface (no height step); its look across a seam is
##      measured at the game camera by tools/capture/capture_road_seams.gd
## Seeded by design: the street plan is fixed by city.map_seed; the 20 seeds are listed here.
##   godot --headless --path . --script tests/run_roads_tests.gd

const RoadGround := preload("res://tests/lib/road_ground.gd")
const Net := preload("res://tests/lib/road_net.gd")
const Edges := preload("res://tests/lib/road_edges.gd")
const STAGES: Array[int] = [1, 2, 3]
## 20 cities: the three the city suite pins, then 17 more.
const SEEDS: Array[int] = [
	7301, 1234, 98765, 11, 42, 77, 123, 256, 404, 512, 777, 1001, 2024, 3141, 4242, 5150, 6502,
	8086, 9999, 31337
]
const SHOWN := 4  # violations quoted in a failure message (the count is always given)

var _cities: Array[Dictionary] = []  # {tier, seed, ground, paint}


func suite_name() -> String:
	return "Roads"


func run_checks() -> void:
	_build()
	await _t("_check_r1_road_ends")
	await _t("_check_r2_bridges_land_on_roads")
	await _t("_check_r3_clean_junctions")
	await _t("_check_r4_kerbed_pavement")
	await _t("_check_r5_paint_stops_at_junctions")
	await _t("_check_r6_one_surface")


func _build() -> void:
	for tier: int in STAGES:
		for map_seed: int in SEEDS:
			var base: Dictionary = Content.tuning().duplicate(true)
			var city: Dictionary = base["city"]
			city["map_seed"] = map_seed
			var cfg: Dictionary = CityGrowth.tuning_for(base, tier)["city"]
			var drawn := CityGround.new(cfg)
			drawn._markings()
			var paint: Array[Transform3D] = drawn._paint.duplicate()
			_cities.append(
				{
					"tier": tier,
					"seed": map_seed,
					"ground": RoadGround.new(drawn.plan, cfg),
					"paint": paint,
				}
			)
			drawn.free()


## One check per stage and city: `found` takes its ground and paint and returns its violations.
func _each(rule: String, found: Callable) -> void:
	for city: Dictionary in _cities:
		var ground: RoadGround = city["ground"]
		var paint: Array[Transform3D] = city["paint"]
		var bad: Array[String] = found.call(ground, paint)
		check(
			bad.is_empty(),
			(
				"stage %d, map_seed %d: %s (%d violations: %s)"
				% [city["tier"], city["seed"], rule, bad.size(), "; ".join(bad.slice(0, SHOWN))]
			)
		)


func _check_r1_road_ends() -> void:
	_each(
		"R1 every road end meets a road, a junction, a deck or the edge",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]: return Net.r1_dead_ends(g)
	)


func _check_r2_bridges_land_on_roads() -> void:
	_each(
		"R2 every deck lands on a road of its width and axis; no road crosses water off a deck",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]: return Net.r2_bridges(g)
	)


func _check_r3_clean_junctions() -> void:
	_each(
		"R3 clean T or X junctions, matching widths, no jagged asphalt edge",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]:
			var out := Net.r3_junctions(g)
			out.append_array(Edges.r3_edges(g))
			return out
	)


func _check_r4_kerbed_pavement() -> void:
	_each(
		"R4 a kerbed pavement lines both sides of every road",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]: return Edges.r4_kerbs(g)
	)


func _check_r5_paint_stops_at_junctions() -> void:
	_each(
		"R5 lane paint stops at junction edges, zebras only at the central junction",
		func(g: RoadGround, paint: Array[Transform3D]) -> Array[String]: return Edges.r5_paint(g, paint)
	)


func _check_r6_one_surface() -> void:
	_each(
		"R6 road pieces that meet make one surface",
		func(g: RoadGround, _paint: Array[Transform3D]) -> Array[String]: return Edges.r6_seams(g)
	)
